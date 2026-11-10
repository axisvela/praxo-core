unit praxo_openai;
{$mode objfpc}{$H+}

interface

uses SysUtils, fpjson;

type
  EPraxoProvider = class(Exception)
  public
    Code: UTF8String;
    Status: Integer;
    constructor CreateCode(const ACode, AMessage: UTF8String; AStatus: Integer = 0);
  end;

  TPraxoOpenAITransport = function(const Path, Body: UTF8String;
    out ResponseBody: UTF8String; out StatusCode: Integer): Boolean of object;

  TPraxoOpenAIAdapter = class
  private
    FBaseURL: UTF8String;
    FAPIKey: UTF8String;
    FModel: UTF8String;
    FToolChoice: UTF8String;
    FTools: TJSONArray;
    FTransport: TPraxoOpenAITransport;
  public
    constructor Create(const ABaseURL, AModel: UTF8String);
    destructor Destroy; override;
    function Generate(Messages: TJSONArray; Tools: TJSONArray;
      const ToolChoice: UTF8String): TJSONObject; overload;
    function Generate(Messages: TJSONArray): TJSONObject; overload;
    property BaseURL: UTF8String read FBaseURL write FBaseURL;
    property APIKey: UTF8String read FAPIKey write FAPIKey;
    property Model: UTF8String read FModel write FModel;
    property ToolChoice: UTF8String read FToolChoice write FToolChoice;
    property Tools: TJSONArray read FTools write FTools;
    property Transport: TPraxoOpenAITransport read FTransport write FTransport;
  end;

implementation

uses Classes, fphttpclient, praxo;

constructor EPraxoProvider.CreateCode(const ACode, AMessage: UTF8String;
  AStatus: Integer);
begin
  inherited Create(AMessage);
  Code := ACode;
  Status := AStatus;
end;

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

function MessagePayload(Message: TJSONObject): TJSONObject;
var
  Role, Content, Joined: UTF8String;
  Blocks, Calls, EncodedCalls: TJSONArray;
  Block, Call, FunctionObject, CallObject: TJSONObject;
  Value: TJSONData;
  I: Integer;
begin
  Result := TJSONObject.Create;
  Role := FieldString(Message, 'role');
  Content := FieldString(Message, 'content');
  Value := LastField(Message, 'contentBlocks');
  if (Content = '') and (Value <> nil) and (Value.JSONType = jtArray) then
  begin
    Blocks := TJSONArray(Value);
    Joined := '';
    for I := 0 to Blocks.Count - 1 do
      if Blocks.Items[I].JSONType = jtObject then
      begin
        Block := TJSONObject(Blocks.Items[I]);
        if FieldString(Block, 'type') = 'text' then
          Joined := Joined + FieldString(Block, 'text');
      end;
    Content := Joined;
  end;
  Result.Add('role', Role);
  Result.Add('content', Content);
  Value := LastField(Message, 'toolCalls');
  if (Role = 'assistant') and (Value <> nil) and (Value.JSONType = jtArray) and
    (TJSONArray(Value).Count > 0) then
  begin
    Calls := TJSONArray(Value);
    EncodedCalls := TJSONArray.Create;
    for I := 0 to Calls.Count - 1 do
      if Calls.Items[I].JSONType = jtObject then
      begin
        Call := TJSONObject(Calls.Items[I]);
        FunctionObject := TJSONObject.Create;
        FunctionObject.Add('name', FieldString(Call, 'name'));
        Value := LastField(Call, 'arguments');
        if (Value <> nil) and (Value.JSONType = jtObject) then
          FunctionObject.Add('arguments', PraxoEncodeJSON(Value))
        else
          FunctionObject.Add('arguments', '{}');
        CallObject := TJSONObject.Create;
        CallObject.Add('id', FieldString(Call, 'id'));
        CallObject.Add('type', 'function');
        CallObject.Add('function', FunctionObject);
        EncodedCalls.Add(CallObject);
      end;
    Result.Add('tool_calls', EncodedCalls);
  end;
  if (Role = 'tool') and (FieldString(Message, 'toolId') <> '') then
    Result.Add('tool_call_id', FieldString(Message, 'toolId'));
end;

function ToolsPayload(Tools: TJSONArray): TJSONArray;
var
  Tool, FunctionObject, Parameters, EncodedTool: TJSONObject;
  Value: TJSONData;
  I: Integer;
begin
  Result := TJSONArray.Create;
  if Tools = nil then Exit;
  for I := 0 to Tools.Count - 1 do
  begin
    if Tools.Items[I].JSONType <> jtObject then Continue;
    Tool := TJSONObject(Tools.Items[I]);
    FunctionObject := TJSONObject.Create;
    FunctionObject.Add('name', FieldString(Tool, 'name'));
    FunctionObject.Add('description', FieldString(Tool, 'description'));
    Value := LastField(Tool, 'parameters');
    if (Value <> nil) and (Value.JSONType = jtObject) then
      FunctionObject.Add('parameters', Value.Clone)
    else
    begin
      Parameters := TJSONObject.Create;
      Parameters.Add('type', 'object');
      FunctionObject.Add('parameters', Parameters);
    end;
    EncodedTool := TJSONObject.Create;
    EncodedTool.Add('type', 'function');
    EncodedTool.Add('function', FunctionObject);
    Result.Add(EncodedTool);
  end;
end;

function ParseResponseBody(const Body: UTF8String): TJSONObject;
var
  Data: TJSONData;
  Root, Choice, Message, Call, FunctionObject, CallObject, Usage,
    Arguments: TJSONObject;
  Choices, Calls, EncodedCalls: TJSONArray;
  ArgumentsData: TJSONData;
  ArgumentsText: UTF8String;
  Value: TJSONData;
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
      raise EPraxoProvider.CreateCode('PROVIDER_HTTP',
        FieldString(TJSONObject(Value), 'message'));
    Value := LastField(Root, 'choices');
    if (Value = nil) or (Value.JSONType <> jtArray) or (TJSONArray(Value).Count = 0) then
      raise EPraxoProvider.CreateCode('PROVIDER_JSON', 'provider returned no choices');
    Choices := TJSONArray(Value);
    if Choices.Items[0].JSONType <> jtObject then
      raise EPraxoProvider.CreateCode('PROVIDER_JSON', 'provider returned invalid choice');
    Choice := TJSONObject(Choices.Items[0]);
    Value := LastField(Choice, 'message');
    if (Value = nil) or (Value.JSONType <> jtObject) then
      raise EPraxoProvider.CreateCode('PROVIDER_JSON', 'provider returned invalid message');
    Message := TJSONObject(Value);
    Result := TJSONObject.Create;
    try
      Result.Add('content', FieldString(Message, 'content'));
      EncodedCalls := TJSONArray.Create;
      Value := LastField(Message, 'tool_calls');
      if (Value <> nil) and (Value.JSONType = jtArray) then
      begin
        Calls := TJSONArray(Value);
        for I := 0 to Calls.Count - 1 do
        begin
          if Calls.Items[I].JSONType <> jtObject then Continue;
          Call := TJSONObject(Calls.Items[I]);
          Value := LastField(Call, 'function');
          if (Value = nil) or (Value.JSONType <> jtObject) then Continue;
          FunctionObject := TJSONObject(Value);
          ArgumentsText := FieldString(FunctionObject, 'arguments');
          if ArgumentsText = '' then
            Arguments := TJSONObject.Create
          else
          begin
            ArgumentsData := nil;
            try
              ArgumentsData := PraxoParseJSON(ArgumentsText);
            except
              on E: Exception do
                raise EPraxoProvider.CreateCode('PROVIDER_JSON', E.Message);
            end;
            try
              if ArgumentsData.JSONType <> jtObject then
                raise EPraxoProvider.CreateCode('PROVIDER_JSON',
                  'tool arguments must be an object');
              Arguments := TJSONObject(ArgumentsData.Clone);
            finally
              ArgumentsData.Free;
            end;
          end;
          CallObject := TJSONObject.Create;
          CallObject.Add('id', FieldString(Call, 'id'));
          CallObject.Add('name', FieldString(FunctionObject, 'name'));
          CallObject.Add('arguments', Arguments);
          EncodedCalls.Add(CallObject);
        end;
      end;
      Result.Add('toolCalls', EncodedCalls);
      Value := LastField(Root, 'usage');
      if (Value <> nil) and (Value.JSONType = jtObject) then
      begin
        Usage := TJSONObject(Value);
        Result.Add('inputTokens', FieldInteger(Usage, 'prompt_tokens'));
        Result.Add('outputTokens', FieldInteger(Usage, 'completion_tokens'));
      end
      else
      begin
        Result.Add('inputTokens', Int64(0));
        Result.Add('outputTokens', Int64(0));
      end;
      Value := LastField(Choice, 'finish_reason');
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

constructor TPraxoOpenAIAdapter.Create(const ABaseURL, AModel: UTF8String);
begin
  inherited Create;
  FBaseURL := ABaseURL;
  while (Length(FBaseURL) > 0) and (FBaseURL[Length(FBaseURL)] = '/') do
    Delete(FBaseURL, Length(FBaseURL), 1);
  FModel := AModel;
end;

destructor TPraxoOpenAIAdapter.Destroy;
begin
  inherited Destroy;
end;

function BuildPayload(const Model: UTF8String; Messages, Tools: TJSONArray;
  const ToolChoice: UTF8String): UTF8String;
var
  Root: TJSONObject;
  EncodedMessages, EncodedTools: TJSONArray;
  I: Integer;
begin
  Root := TJSONObject.Create;
  try
    Root.Add('model', Model);
    EncodedMessages := TJSONArray.Create;
    if Messages <> nil then
      for I := 0 to Messages.Count - 1 do
        if Messages.Items[I].JSONType = jtObject then
          EncodedMessages.Add(MessagePayload(TJSONObject(Messages.Items[I])));
    Root.Add('messages', EncodedMessages);
    if (Tools <> nil) and (Tools.Count > 0) then
    begin
      EncodedTools := ToolsPayload(Tools);
      Root.Add('tools', EncodedTools);
    end;
    if ToolChoice <> '' then
      Root.Add('tool_choice', ToolChoice);
    Result := PraxoEncodeJSON(Root);
  finally
    Root.Free;
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
    if APIKey <> '' then
      Client.AddHeader('Authorization', 'Bearer ' + APIKey);
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
        if StatusCode >= 400 then
          Result := True
        else
        begin
          ResponseBody := E.Message;
          Result := False;
        end;
      end;
    end;
  finally
    Client.Free;
    Request.Free;
    Response.Free;
  end;
end;

function TPraxoOpenAIAdapter.Generate(Messages, Tools: TJSONArray;
  const ToolChoice: UTF8String): TJSONObject;
var
  Body, ResponseBody: UTF8String;
  StatusCode: Integer;
  Sender: TPraxoOpenAITransport;
  Sent: Boolean;
begin
  if FBaseURL = '' then
    raise EPraxoProvider.CreateCode('PROVIDER_HTTP',
      'provider base URL is required');
  Body := BuildPayload(FModel, Messages, Tools, ToolChoice);
  Sender := FTransport;
  if Assigned(Sender) then
    Sent := Sender('/chat/completions', Body, ResponseBody, StatusCode)
  else
    Sent := HTTPPost(FBaseURL, FAPIKey, '/chat/completions', Body,
      ResponseBody, StatusCode);
  if not Sent then
    raise EPraxoProvider.CreateCode('PROVIDER_HTTP',
      'provider request failed: ' + ResponseBody);
  if (StatusCode < 200) or (StatusCode >= 300) then
    raise EPraxoProvider.CreateCode('PROVIDER_HTTP',
      'provider returned HTTP ' + IntToStr(StatusCode) + ': ' +
      Copy(ResponseBody, 1, 4096), StatusCode);
  Result := ParseResponseBody(ResponseBody);
end;

function TPraxoOpenAIAdapter.Generate(Messages: TJSONArray): TJSONObject;
begin
  Result := Generate(Messages, FTools, FToolChoice);
end;

end.
