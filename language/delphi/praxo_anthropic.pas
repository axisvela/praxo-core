unit praxo_anthropic;
{$mode objfpc}{$H+}

interface

uses SysUtils, fpjson, praxo_openai;

type
  TPraxoAnthropicAdapter = class
  private
    FBaseURL: UTF8String;
    FAPIKey: UTF8String;
    FModel: UTF8String;
    FVersion: UTF8String;
    FMaxTokens: Integer;
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
    property Version: UTF8String read FVersion write FVersion;
    property MaxTokens: Integer read FMaxTokens write FMaxTokens;
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

function MessageContent(Message: TJSONObject): TJSONArray;
var
  Content: TJSONArray;
  Item, CallObject: TJSONObject;
  Value, ArgumentValue: TJSONData;
  CallsArray: TJSONArray;
  I: Integer;
begin
  Result := TJSONArray.Create;
  Value := LastField(Message, 'content');
  if (Value <> nil) and (Value.JSONType = jtString) and (Value.AsString <> '') then
  begin
    Item := TJSONObject.Create;
    Item.Add('type', 'text');
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
      Item := TJSONObject.Create;
      Item.Add('type', 'tool_use');
      Item.Add('id', FieldString(CallObject, 'id'));
      Item.Add('name', FieldString(CallObject, 'name'));
      ArgumentValue := LastField(CallObject, 'arguments');
      if (ArgumentValue <> nil) and (ArgumentValue.JSONType = jtObject) then
        Item.Add('input', ArgumentValue.Clone)
      else
        Item.Add('input', TJSONObject.Create);
      Result.Add(Item);
    end;
  end;
end;

function BuildPayload(const Model: UTF8String; MaxTokens: Integer;
  Messages, Tools: TJSONArray; const ToolChoice: UTF8String): UTF8String;
var
  Root, Group, Item, Tool: TJSONObject;
  WireMessages, WireTools, Content, Pending: TJSONArray;
  SystemText, Role: UTF8String;
  I: Integer;
begin
  Root := TJSONObject.Create;
  WireMessages := TJSONArray.Create;
  Pending := TJSONArray.Create;
  SystemText := '';
  try
    if Messages <> nil then
      for I := 0 to Messages.Count - 1 do
      begin
        if Messages.Items[I].JSONType <> jtObject then Continue;
        Role := FieldString(TJSONObject(Messages.Items[I]), 'role');
        if Role = 'system' then
        begin
          if SystemText <> '' then SystemText := SystemText + #10#10;
          SystemText := SystemText + FieldString(TJSONObject(Messages.Items[I]), 'content');
        end
        else if Role = 'tool' then
        begin
          Item := TJSONObject.Create;
          Item.Add('type', 'tool_result');
          Item.Add('tool_use_id', FieldString(TJSONObject(Messages.Items[I]), 'toolId'));
          Item.Add('content', FieldString(TJSONObject(Messages.Items[I]), 'content'));
          Pending.Add(Item);
        end
        else
        begin
          if Pending.Count > 0 then
          begin
            Group := TJSONObject.Create;
            Group.Add('role', 'user');
            Group.Add('content', Pending);
            WireMessages.Add(Group);
            Pending := TJSONArray.Create;
          end;
          Content := MessageContent(TJSONObject(Messages.Items[I]));
          if Content.Count > 0 then
          begin
            Group := TJSONObject.Create;
            Group.Add('role', Role);
            Group.Add('content', Content);
            WireMessages.Add(Group);
          end
          else
            Content.Free;
        end;
      end;
    if Pending.Count > 0 then
    begin
      Group := TJSONObject.Create;
      Group.Add('role', 'user');
      Group.Add('content', Pending);
      WireMessages.Add(Group);
    end
    else
      Pending.Free;
    Root.Add('model', Model);
    Root.Add('max_tokens', MaxTokens);
    Root.Add('messages', WireMessages);
    if SystemText <> '' then Root.Add('system', SystemText);
    if (Tools <> nil) and (Tools.Count > 0) then
    begin
      WireTools := TJSONArray.Create;
      for I := 0 to Tools.Count - 1 do
      begin
        if Tools.Items[I].JSONType <> jtObject then Continue;
        Tool := TJSONObject.Create;
        Tool.Add('name', FieldString(TJSONObject(Tools.Items[I]), 'name'));
        Tool.Add('description', FieldString(TJSONObject(Tools.Items[I]), 'description'));
        Item := TJSONObject.Create;
        Item.Add('type', 'object');
        Tool.Add('input_schema', Item);
        WireTools.Add(Tool);
      end;
      Root.Add('tools', WireTools);
      if ToolChoice = 'auto' then
        Root.Add('tool_choice', TJSONObject.Create(['type', 'auto']))
      else if ToolChoice = 'required' then
        Root.Add('tool_choice', TJSONObject.Create(['type', 'any']))
      else if ToolChoice = 'none' then
        Root.Add('tool_choice', TJSONObject.Create(['type', 'none']));
    end;
    Result := PraxoEncodeJSON(Root);
  finally
    Root.Free;
  end;
end;

function ParseResponseBody(const Body: UTF8String): TJSONObject;
var
  Data: TJSONData;
  Root, Block, Call, Usage, InputValue: TJSONObject;
  Blocks, Calls: TJSONArray;
  Text: UTF8String;
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
      raise EPraxoProvider.CreateCode('PROVIDER_HTTP', 'anthropic: provider error');
    Value := LastField(Root, 'content');
    if (Value = nil) or (Value.JSONType <> jtArray) then
      raise EPraxoProvider.CreateCode('PROVIDER_JSON', 'provider returned invalid content');
    Result := TJSONObject.Create;
    try
      Text := '';
      Calls := TJSONArray.Create;
      Blocks := TJSONArray(Value);
      for I := 0 to Blocks.Count - 1 do
      begin
        if Blocks.Items[I].JSONType <> jtObject then Continue;
        Block := TJSONObject(Blocks.Items[I]);
        if FieldString(Block, 'type') = 'text' then
          Text := Text + FieldString(Block, 'text')
        else if FieldString(Block, 'type') = 'tool_use' then
        begin
          Call := TJSONObject.Create;
          Call.Add('id', FieldString(Block, 'id'));
          Call.Add('name', FieldString(Block, 'name'));
          Value := LastField(Block, 'input');
          if (Value <> nil) and (Value.JSONType = jtObject) then
            Call.Add('arguments', Value.Clone)
          else
            Call.Add('arguments', TJSONObject.Create);
          Calls.Add(Call);
        end;
      end;
      Result.Add('content', Text);
      Result.Add('toolCalls', Calls);
      Value := LastField(Root, 'usage');
      if (Value <> nil) and (Value.JSONType = jtObject) then
      begin
        Usage := TJSONObject(Value);
        Result.Add('inputTokens', FieldInteger(Usage, 'input_tokens'));
        Result.Add('outputTokens', FieldInteger(Usage, 'output_tokens'));
      end
      else
      begin
        Result.Add('inputTokens', Int64(0));
        Result.Add('outputTokens', Int64(0));
      end;
      Value := LastField(Root, 'stop_reason');
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

function HTTPPost(const BaseURL, APIKey, Version, Path, Body: UTF8String;
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
    Client.AddHeader('x-api-key', APIKey);
    Client.AddHeader('anthropic-version', Version);
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

constructor TPraxoAnthropicAdapter.Create(const ABaseURL, AModel: UTF8String);
begin
  inherited Create;
  FBaseURL := ABaseURL;
  while (Length(FBaseURL) > 0) and (FBaseURL[Length(FBaseURL)] = '/') do
    Delete(FBaseURL, Length(FBaseURL), 1);
  FModel := AModel;
  FVersion := '2023-06-01';
  FMaxTokens := 1024;
end;

function TPraxoAnthropicAdapter.Generate(Messages, Tools: TJSONArray;
  const ToolChoice: UTF8String): TJSONObject;
var
  Body, ResponseBody: UTF8String;
  StatusCode: Integer;
  Sender: TPraxoOpenAITransport;
  Sent: Boolean;
begin
  if FAPIKey = '' then
    raise EPraxoProvider.CreateCode('MODEL_CONFIG', 'anthropic: API key is required');
  Body := BuildPayload(FModel, FMaxTokens, Messages, Tools, ToolChoice);
  Sender := FTransport;
  if Assigned(Sender) then
    Sent := Sender('/v1/messages', Body, ResponseBody, StatusCode)
  else
    Sent := HTTPPost(FBaseURL, FAPIKey, FVersion, '/v1/messages', Body,
      ResponseBody, StatusCode);
  if not Sent then
    raise EPraxoProvider.CreateCode('PROVIDER_HTTP', 'provider request failed: ' + ResponseBody);
  if (StatusCode < 200) or (StatusCode >= 300) then
    raise EPraxoProvider.CreateCode('PROVIDER_HTTP',
      'provider returned HTTP ' + IntToStr(StatusCode), StatusCode);
  Result := ParseResponseBody(ResponseBody);
end;

function TPraxoAnthropicAdapter.Generate(Messages: TJSONArray): TJSONObject;
begin
  Result := Generate(Messages, FTools, FToolChoice);
end;

end.
