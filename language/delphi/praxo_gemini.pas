unit praxo_gemini;
{$mode objfpc}{$H+}

interface

uses SysUtils, fpjson, praxo_openai;

type
  TPraxoGeminiAdapter = class
  private
    FBaseURL: UTF8String;
    FAPIKey: UTF8String;
    FModel: UTF8String;
    FMaxOutputTokens: Integer;
    FTools: TJSONArray;
    FToolChoice: UTF8String;
    FTransport: TPraxoOpenAITransport;
  public
    constructor Create(const ABaseURL, AModel: UTF8String);
    function Generate(Messages: TJSONArray; Tools: TJSONArray;
      const ToolChoice: UTF8String): TJSONObject; overload;
    function Generate(Messages: TJSONArray): TJSONObject; overload;
    property BaseURL: UTF8String read FBaseURL write FBaseURL;
    property APIKey: UTF8String read FAPIKey write FAPIKey;
    property Model: UTF8String read FModel write FModel;
    property MaxOutputTokens: Integer read FMaxOutputTokens write FMaxOutputTokens;
    property Tools: TJSONArray read FTools write FTools;
    property ToolChoice: UTF8String read FToolChoice write FToolChoice;
    property Transport: TPraxoOpenAITransport read FTransport write FTransport;
  end;

implementation

uses Classes, fphttpclient, praxo;

function LastField(ObjectValue: TJSONObject; const Name: UTF8String): TJSONData;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to ObjectValue.Count - 1 do
    if ObjectValue.Names[I] = Name then Result := ObjectValue.Items[I];
end;

function FieldString(ObjectValue: TJSONObject; const Name: UTF8String;
  const Fallback: UTF8String = ''): UTF8String;
var
  Value: TJSONData;
begin
  Value := LastField(ObjectValue, Name);
  if (Value = nil) or (Value.JSONType <> jtString) then
    Result := Fallback
  else
    Result := Value.AsString;
end;

function FieldInteger(ObjectValue: TJSONObject; const Name: UTF8String;
  Fallback: Int64 = 0): Int64;
var
  Value: TJSONData;
begin
  Value := LastField(ObjectValue, Name);
  if (Value = nil) or (Value.JSONType <> jtNumber) then
    Result := Fallback
  else
    Result := Value.AsInt64;
end;

function MessageParts(Message: TJSONObject): TJSONArray;
var
  Item, CallObject, FunctionObject: TJSONObject;
  Value, ArgumentValue: TJSONData;
  CallsArray: TJSONArray;
  I: Integer;
begin
  Result := TJSONArray.Create;
  Value := LastField(Message, 'content');
  if (Value <> nil) and (Value.JSONType = jtString) and (Value.AsString <> '') then
  begin
    Item := TJSONObject.Create;
    Item.Add('text', Value.AsString);
    Result.Add(Item);
  end;
  Value := LastField(Message, 'toolCalls');
  if (Value <> nil) and (Value.JSONType = jtArray) then
  begin
    CallsArray := TJSONArray(Value);
    for I := 0 to CallsArray.Count - 1 do
    begin
      if CallsArray.Items[I].JSONType <> jtObject then Continue;
      CallObject := TJSONObject(CallsArray.Items[I]);
      FunctionObject := TJSONObject.Create;
      FunctionObject.Add('name', FieldString(CallObject, 'name'));
      ArgumentValue := LastField(CallObject, 'arguments');
      if (ArgumentValue <> nil) and (ArgumentValue.JSONType = jtObject) then
        FunctionObject.Add('args', ArgumentValue.Clone)
      else
        FunctionObject.Add('args', TJSONObject.Create);
      Item := TJSONObject.Create;
      Item.Add('functionCall', FunctionObject);
      Result.Add(Item);
    end;
  end;
end;

function BuildPayload(MaxOutputTokens: Integer; Messages, Tools: TJSONArray;
  const ToolChoice: UTF8String): UTF8String;
var
  Root, Group, Item, Tool, Config, Calling, ResponseObject: TJSONObject;
  Contents, Parts, Pending, Declarations, ToolGroups, SystemParts: TJSONArray;
  SystemText, Role, Mode: UTF8String;
  I: Integer;
begin
  Root := TJSONObject.Create;
  Contents := TJSONArray.Create;
  Pending := TJSONArray.Create;
  SystemParts := TJSONArray.Create;
  SystemText := '';
  try
    if Messages <> nil then
      for I := 0 to Messages.Count - 1 do
      begin
        if Messages.Items[I].JSONType <> jtObject then Continue;
        Role := FieldString(TJSONObject(Messages.Items[I]), 'role');
        if Role = 'system' then
        begin
          SystemText := FieldString(TJSONObject(Messages.Items[I]), 'content');
          if SystemText <> '' then
          begin
            Item := TJSONObject.Create;
            Item.Add('text', SystemText);
            SystemParts.Add(Item);
          end;
        end
        else if Role = 'tool' then
        begin
          Item := TJSONObject.Create;
          Calling := TJSONObject.Create;
          Calling.Add('name', FieldString(TJSONObject(Messages.Items[I]), 'toolId'));
          ResponseObject := TJSONObject.Create;
          ResponseObject.Add('result', FieldString(TJSONObject(Messages.Items[I]), 'content'));
          Calling.Add('response', ResponseObject);
          Item.Add('functionResponse', Calling);
          Pending.Add(Item);
        end
        else
        begin
          if Pending.Count > 0 then
          begin
            Group := TJSONObject.Create;
            Group.Add('role', 'user');
            Group.Add('parts', Pending);
            Contents.Add(Group);
            Pending := TJSONArray.Create;
          end;
          Parts := MessageParts(TJSONObject(Messages.Items[I]));
          if Parts.Count > 0 then
          begin
            Group := TJSONObject.Create;
            if Role = 'assistant' then
              Group.Add('role', 'model')
            else
              Group.Add('role', 'user');
            Group.Add('parts', Parts);
            Contents.Add(Group);
          end
          else
            Parts.Free;
        end;
      end;
    if Pending.Count > 0 then
    begin
      Group := TJSONObject.Create;
      Group.Add('role', 'user');
      Group.Add('parts', Pending);
      Contents.Add(Group);
    end
    else
      Pending.Free;
    Root.Add('contents', Contents);
    if SystemParts.Count > 0 then
    begin
      Group := TJSONObject.Create;
      Group.Add('parts', SystemParts);
      Root.Add('system_instruction', Group);
    end
    else
      SystemParts.Free;
    if (Tools <> nil) and (Tools.Count > 0) then
    begin
      Declarations := TJSONArray.Create;
      for I := 0 to Tools.Count - 1 do
      begin
        if Tools.Items[I].JSONType <> jtObject then Continue;
        Tool := TJSONObject.Create;
        Tool.Add('name', FieldString(TJSONObject(Tools.Items[I]), 'name'));
        Tool.Add('description', FieldString(TJSONObject(Tools.Items[I]), 'description'));
        Item := TJSONObject.Create;
        Item.Add('type', 'object');
        Tool.Add('parameters', Item);
        Declarations.Add(Tool);
      end;
      Group := TJSONObject.Create;
      Group.Add('functionDeclarations', Declarations);
      ToolGroups := TJSONArray.Create;
      ToolGroups.Add(Group);
      Root.Add('tools', ToolGroups);
      if ToolChoice = 'required' then
        Mode := 'ANY'
      else if ToolChoice = 'none' then
        Mode := 'NONE'
      else
        Mode := 'AUTO';
      Calling := TJSONObject.Create;
      Calling.Add('mode', Mode);
      Config := TJSONObject.Create;
      Config.Add('functionCallingConfig', Calling);
      Root.Add('toolConfig', Config);
    end;
    if MaxOutputTokens > 0 then
    begin
      Config := TJSONObject.Create;
      Config.Add('maxOutputTokens', MaxOutputTokens);
      Root.Add('generationConfig', Config);
    end;
    Result := PraxoEncodeJSON(Root);
  finally
    Root.Free;
  end;
end;

function ParseResponseBody(const Body: UTF8String): TJSONObject;
var
  Data: TJSONData;
  Root, Candidate, Content, CallObject, Usage, ToolCallObject, Arguments: TJSONObject;
  Candidates, Parts, Calls: TJSONArray;
  Text: UTF8String;
  Value, ArgsValue: TJSONData;
  I: Integer;
begin
  try
    Data := PraxoParseJSON(Body);
  except
    on E: Exception do
      raise EPraxoProvider.CreateCode('PROVIDER_JSON', E.Message);
  end;
  try
    if Data.JSONType <> jtObject then
      raise EPraxoProvider.CreateCode('PROVIDER_JSON', 'provider returned invalid JSON');
    Root := TJSONObject(Data);
    Value := LastField(Root, 'error');
    if (Value <> nil) and (Value.JSONType = jtObject) then
      raise EPraxoProvider.CreateCode('PROVIDER_HTTP', 'gemini: provider error');
    Value := LastField(Root, 'candidates');
    if (Value = nil) or (Value.JSONType <> jtArray) or (TJSONArray(Value).Count = 0) then
      raise EPraxoProvider.CreateCode('PROVIDER_HTTP', 'gemini: empty response');
    Candidates := TJSONArray(Value);
    if Candidates.Items[0].JSONType <> jtObject then
      raise EPraxoProvider.CreateCode('PROVIDER_JSON', 'gemini: invalid candidate');
    Candidate := TJSONObject(Candidates.Items[0]);
    Value := LastField(Candidate, 'content');
    if (Value = nil) or (Value.JSONType <> jtObject) then
      raise EPraxoProvider.CreateCode('PROVIDER_JSON', 'gemini: invalid content');
    Content := TJSONObject(Value);
    Value := LastField(Content, 'parts');
    Result := TJSONObject.Create;
    try
      Text := '';
      Calls := TJSONArray.Create;
      if (Value <> nil) and (Value.JSONType = jtArray) then
      begin
        Parts := TJSONArray(Value);
        for I := 0 to Parts.Count - 1 do
        begin
          if Parts.Items[I].JSONType <> jtObject then Continue;
          Text := Text + FieldString(TJSONObject(Parts.Items[I]), 'text');
          Value := LastField(TJSONObject(Parts.Items[I]), 'functionCall');
          if (Value <> nil) and (Value.JSONType = jtObject) then
          begin
            CallObject := TJSONObject(Value);
            ToolCallObject := TJSONObject.Create;
            ToolCallObject.Add('id', 'call-' + IntToStr(Calls.Count + 1));
            ToolCallObject.Add('name', FieldString(CallObject, 'name'));
            ArgsValue := LastField(CallObject, 'args');
            if (ArgsValue <> nil) and (ArgsValue.JSONType = jtObject) then
              Arguments := TJSONObject(ArgsValue.Clone)
            else
              Arguments := TJSONObject.Create;
            ToolCallObject.Add('arguments', Arguments);
            Calls.Add(ToolCallObject);
          end;
        end;
      end;
      Result.Add('content', Text);
      Result.Add('toolCalls', Calls);
      Value := LastField(Root, 'usageMetadata');
      if (Value <> nil) and (Value.JSONType = jtObject) then
      begin
        Usage := TJSONObject(Value);
        Result.Add('inputTokens', FieldInteger(Usage, 'promptTokenCount'));
        Result.Add('outputTokens', FieldInteger(Usage, 'candidatesTokenCount'));
      end
      else
      begin
        Result.Add('inputTokens', Int64(0));
        Result.Add('outputTokens', Int64(0));
      end;
      Value := LastField(Candidate, 'finishReason');
      if (Value <> nil) and (Value.JSONType = jtString) then
        Result.Add('finishReason', Value.AsString);
    except
      Result.Free;
      raise;
    end;
  finally
    Data.Free;
  end;
end;

function HTTPPost(const BaseURL, APIKey, Path, Body: UTF8String;
  out ResponseBody: UTF8String; out StatusCode: Integer): Boolean;
var
  Client: TFPHTTPClient;
  Request, Response: TStringStream;
begin
  Result := False;
  StatusCode := 0;
  ResponseBody := '';
  Client := TFPHTTPClient.Create(nil);
  Request := TStringStream.Create(Body);
  Response := TStringStream.Create('');
  try
    Client.RequestBody := Request;
    Client.AddHeader('Content-Type', 'application/json');
    Client.AddHeader('x-goog-api-key', APIKey);
    try
      Client.HTTPMethod('POST', BaseURL + Path, Response, []);
      StatusCode := Client.ResponseStatusCode;
      ResponseBody := Response.DataString;
      Result := True;
    except
      on E: Exception do
      begin
        StatusCode := Client.ResponseStatusCode;
        ResponseBody := Response.DataString;
        Result := StatusCode >= 400;
        if not Result then ResponseBody := E.Message;
      end;
    end;
  finally
    Client.Free;
    Request.Free;
    Response.Free;
  end;
end;

constructor TPraxoGeminiAdapter.Create(const ABaseURL, AModel: UTF8String);
begin
  inherited Create;
  FBaseURL := ABaseURL;
  while (Length(FBaseURL) > 0) and (FBaseURL[Length(FBaseURL)] = '/') do
    Delete(FBaseURL, Length(FBaseURL), 1);
  FModel := AModel;
end;

function TPraxoGeminiAdapter.Generate(Messages, Tools: TJSONArray;
  const ToolChoice: UTF8String): TJSONObject;
var
  Body, ResponseBody: UTF8String;
  StatusCode: Integer;
  Sender: TPraxoOpenAITransport;
  Sent: Boolean;
begin
  if FAPIKey = '' then
    raise EPraxoProvider.CreateCode('MODEL_CONFIG', 'gemini: API key is required');
  Body := BuildPayload(FMaxOutputTokens, Messages, Tools, ToolChoice);
  Sender := FTransport;
  if Assigned(Sender) then
    Sent := Sender('/v1beta/models/' + FModel + ':generateContent', Body,
      ResponseBody, StatusCode)
  else
    Sent := HTTPPost(FBaseURL, FAPIKey,
      '/v1beta/models/' + FModel + ':generateContent', Body, ResponseBody, StatusCode);
  if not Sent then
    raise EPraxoProvider.CreateCode('PROVIDER_HTTP', 'provider request failed: ' + ResponseBody);
  if (StatusCode < 200) or (StatusCode >= 300) then
    raise EPraxoProvider.CreateCode('PROVIDER_HTTP',
      'provider returned HTTP ' + IntToStr(StatusCode), StatusCode);
  Result := ParseResponseBody(ResponseBody);
end;

function TPraxoGeminiAdapter.Generate(Messages: TJSONArray): TJSONObject;
begin
  Result := Generate(Messages, FTools, FToolChoice);
end;

end.
