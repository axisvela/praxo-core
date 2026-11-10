program openai_tests;
{$mode objfpc}{$H+}

uses SysUtils, fpjson, praxo, praxo_openai;

type
  TFakeTransport = class
    Path, Body, Response: UTF8String;
    Status: Integer;
    Calls: Integer;
    function Send(const APath, ABody: UTF8String;
      out AResponseBody: UTF8String; out AStatusCode: Integer): Boolean;
  end;

function TFakeTransport.Send(const APath, ABody: UTF8String;
  out AResponseBody: UTF8String; out AStatusCode: Integer): Boolean;
begin
  Inc(Calls);
  Path := APath;
  Body := ABody;
  AResponseBody := Response;
  AStatusCode := Status;
  Result := True;
end;

procedure Check(Condition: Boolean; const Detail: UTF8String);
begin
  if not Condition then
    raise Exception.Create(Detail);
end;

function Field(ObjectValue: TJSONObject; const Name: UTF8String): TJSONData;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to ObjectValue.Count - 1 do
    if ObjectValue.Names[I] = Name then Result := ObjectValue.Items[I];
end;

function Str(ObjectValue: TJSONObject; const Name: UTF8String): UTF8String;
var
  Value: TJSONData;
begin
  Value := Field(ObjectValue, Name);
  if (Value = nil) or (Value.JSONType <> jtString) then
    Result := ''
  else
    Result := Value.AsString;
end;

function IntValue(ObjectValue: TJSONObject; const Name: UTF8String): Int64;
var
  Value: TJSONData;
begin
  Value := Field(ObjectValue, Name);
  if (Value = nil) or (Value.JSONType <> jtNumber) then
    Result := -1
  else
    Result := Value.AsInt64;
end;

procedure TestGenerateAndMapping;
var
  Adapter: TPraxoOpenAIAdapter;
  Fake: TFakeTransport;
  Messages, Tools, EncodedMessages, EncodedTools, EncodedCalls: TJSONArray;
  User, Tool, Response, Payload, CallObject: TJSONObject;
  Value: TJSONData;
begin
  Fake := TFakeTransport.Create;
  Fake.Status := 200;
  Fake.Response :=
    '{"choices":[{"message":{"content":"hello","tool_calls":[' +
    '{"id":"c1","type":"function","function":' +
    '{"name":"echo","arguments":"{\"text\":\"hi\"}"}}]},' +
    '"finish_reason":"tool_calls"}],' +
    '"usage":{"prompt_tokens":3,"completion_tokens":2}}';
  Adapter := TPraxoOpenAIAdapter.Create('http://example.test/v1', 'test-model');
  Adapter.Transport := @Fake.Send;
  Messages := TJSONArray.Create;
  User := TJSONObject.Create;
  User.Add('role', 'user');
  User.Add('content', 'hi');
  Messages.Add(User);
  Tools := TJSONArray.Create;
  Tool := TJSONObject.Create;
  Tool.Add('name', 'echo');
  Tool.Add('description', 'Echo');
  Tools.Add(Tool);
  Response := Adapter.Generate(Messages, Tools, 'auto');
  try
    Check(Fake.Path = '/chat/completions', 'path');
    Payload := TJSONObject(PraxoParseJSON(Fake.Body));
    try
      Check(Str(Payload, 'model') = 'test-model', 'model');
      Check(Str(Payload, 'tool_choice') = 'auto', 'tool_choice');
      EncodedMessages := TJSONArray(Field(Payload, 'messages'));
      Check(EncodedMessages.Count = 1, 'messages');
      Check(Str(TJSONObject(EncodedMessages.Items[0]), 'content') = 'hi', 'message content');
      EncodedTools := TJSONArray(Field(Payload, 'tools'));
      Check(EncodedTools.Count = 1, 'tools');
      Check(Str(TJSONObject(Field(TJSONObject(EncodedTools.Items[0]), 'function')),
        'name') = 'echo', 'tool name');
    finally
      Payload.Free;
    end;
    Check(Str(Response, 'content') = 'hello', 'content');
    Value := Field(Response, 'toolCalls');
    Check((Value <> nil) and (Value.JSONType = jtArray), 'toolCalls');
    EncodedCalls := TJSONArray(Value);
    Check(EncodedCalls.Count = 1, 'call count');
    CallObject := TJSONObject(EncodedCalls.Items[0]);
    Check(Str(CallObject, 'id') = 'c1', 'call id');
    Check(Str(CallObject, 'name') = 'echo', 'call name');
    Check(Str(TJSONObject(Field(CallObject, 'arguments')), 'text') = 'hi', 'call arguments');
    Check(IntValue(Response, 'inputTokens') = 3, 'input tokens');
    Check(IntValue(Response, 'outputTokens') = 2, 'output tokens');
    Check(Str(Response, 'finishReason') = 'tool_calls', 'finish reason');
  finally
    Response.Free;
    Adapter.Free;
    Fake.Free;
  end;
end;

procedure TestAssistantAndToolMapping;
var
  Adapter: TPraxoOpenAIAdapter;
  Fake: TFakeTransport;
  Messages, Calls, EncodedMessages: TJSONArray;
  Assistant, Tool, Call, Arguments, Response, Payload: TJSONObject;
  Value: TJSONData;
begin
  Fake := TFakeTransport.Create;
  Fake.Status := 200;
  Fake.Response := '{"choices":[{"message":{"content":"ok"}}]}';
  Adapter := TPraxoOpenAIAdapter.Create('http://example.test/v1', 'test-model');
  Adapter.Transport := @Fake.Send;
  Messages := TJSONArray.Create;
  Assistant := TJSONObject.Create;
  Assistant.Add('role', 'assistant');
  Assistant.Add('content', '');
  Calls := TJSONArray.Create;
  Call := TJSONObject.Create;
  Call.Add('id', 'c1');
  Call.Add('name', 'echo');
  Arguments := TJSONObject.Create;
  Arguments.Add('text', 'bye');
  Call.Add('arguments', Arguments);
  Calls.Add(Call);
  Assistant.Add('toolCalls', Calls);
  Messages.Add(Assistant);
  Tool := TJSONObject.Create;
  Tool.Add('role', 'tool');
  Tool.Add('content', '{"ok":true}');
  Tool.Add('toolId', 'c1');
  Messages.Add(Tool);
  Response := Adapter.Generate(Messages);
  try
    Payload := TJSONObject(PraxoParseJSON(Fake.Body));
    try
      EncodedMessages := TJSONArray(Field(Payload, 'messages'));
      Call := TJSONObject(TJSONArray(Field(TJSONObject(EncodedMessages.Items[0]),
        'tool_calls')).Items[0]);
      Check(Str(Call, 'id') = 'c1', 'assistant call id');
      Check(Str(Call, 'type') = 'function', 'assistant call type');
      Value := PraxoParseJSON(Str(TJSONObject(Field(Call, 'function')), 'arguments'));
      try
        Check(Str(TJSONObject(Value), 'text') = 'bye', 'assistant arguments');
      finally
        Value.Free;
      end;
      Check(Str(TJSONObject(EncodedMessages.Items[1]), 'tool_call_id') = 'c1', 'tool id');
    finally
      Payload.Free;
    end;
  finally
    Response.Free;
    Adapter.Free;
    Fake.Free;
  end;
end;

procedure TestErrors;
var
  Adapter: TPraxoOpenAIAdapter;
  Fake: TFakeTransport;
  Messages: TJSONArray;
begin
  Fake := TFakeTransport.Create;
  Adapter := TPraxoOpenAIAdapter.Create('http://example.test/v1', 'test-model');
  Adapter.Transport := @Fake.Send;
  Messages := TJSONArray.Create;
  try
    Fake.Status := 500;
    Fake.Response := 'server error';
    try
      Adapter.Generate(Messages);
      Check(False, 'expected http error');
    except
      on E: EPraxoProvider do
      begin
        Check(E.Code = 'PROVIDER_HTTP', 'http code');
        Check(E.Status = 500, 'http status');
        Check(Pos('server error', E.Message) > 0, 'http body');
      end;
    end;

    Fake.Calls := 0;
    Adapter.BaseURL := '';
    try
      Adapter.Generate(Messages);
      Check(False, 'expected base url error');
    except
      on E: EPraxoProvider do
        Check(E.Code = 'PROVIDER_HTTP', 'base url code');
    end;
    Check(Fake.Calls = 0, 'base url skips transport');

    Adapter.BaseURL := 'http://example.test/v1';
    Fake.Status := 200;
    Fake.Response := '{"choices":[{"message":{"content":"","tool_calls":[' +
      '{"id":"c1","function":{"name":"echo","arguments":"not json"}}]}}]}';
    try
      Adapter.Generate(Messages);
      Check(False, 'expected arguments error');
    except
      on E: EPraxoProvider do
        Check(E.Code = 'PROVIDER_JSON', 'arguments code');
    end;
  finally
    Messages.Free;
    Adapter.Free;
    Fake.Free;
  end;
end;

begin
  TestGenerateAndMapping;
  TestAssistantAndToolMapping;
  TestErrors;
  writeln('openai adapter tests passed');
end.
