program provider_tests;
{$mode objfpc}{$H+}

uses SysUtils, fpjson, praxo, praxo_openai, praxo_anthropic, praxo_gemini;

procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
  begin
    WriteLn('FAIL: ', MessageText);
    Halt(1);
  end;
end;

type
  TFakeTransport = class
    PathPart: string;
    Response: UTF8String;
    CapturedBody: UTF8String;
    function Send(const Path, Body: UTF8String;
      out ResponseBody: UTF8String; out StatusCode: Integer): Boolean;
  end;

  TDeltaCollector = class
    Text: UTF8String;
    procedure Add(const Delta: UTF8String);
  end;

function TFakeTransport.Send(const Path, Body: UTF8String;
  out ResponseBody: UTF8String; out StatusCode: Integer): Boolean;
begin
  Check(Pos(PathPart, Path) > 0, 'provider path');
  CapturedBody := Body;
  ResponseBody := Response;
  StatusCode := 200;
  Result := True;
end;

procedure TDeltaCollector.Add(const Delta: UTF8String);
begin
  Text := Text + Delta;
end;

var
  Messages: TJSONArray;
  Tools: TJSONArray;
  Adapter: TPraxoAnthropicAdapter;
  GeminiAdapter: TPraxoGeminiAdapter;
  Response: TJSONObject;
  Calls: TJSONArray;
  Value: TJSONData;
  AnthropicFake: TFakeTransport;
  AnthropicStreamFake: TFakeTransport;
  Collector: TDeltaCollector;
  GeminiFake: TFakeTransport;
  GeminiStreamFake: TFakeTransport;
begin
  Messages := TJSONArray(PraxoParseJSON(
    '[{"role":"system","content":"be brief"},{"role":"user","content":"hi"}]'));
  Tools := TJSONArray(PraxoParseJSON(
    '[{"name":"echo","description":"Echo"}]'));
  try
    AnthropicFake := TFakeTransport.Create;
    AnthropicFake.PathPart := '/v1/messages';
    AnthropicFake.Response := '{"content":[{"type":"text","text":"hello"},' +
      '{"type":"tool_use","id":"tool-1","name":"echo","input":{"text":"hi"}}],' +
      '"stop_reason":"end_turn","usage":{"input_tokens":3,"output_tokens":4}}';
    Adapter := TPraxoAnthropicAdapter.Create('https://example.test', 'claude-test');
    try
      Adapter.APIKey := 'ak';
      Adapter.Transport := @AnthropicFake.Send;
      Response := Adapter.Generate(Messages, Tools, 'auto');
      try
        Value := Response.Find('content');
        Check((Value <> nil) and (Value.AsString = 'hello'), 'anthropic content');
        Calls := TJSONArray(Response.Find('toolCalls'));
        Check((Calls <> nil) and (Calls.Count = 1), 'anthropic calls');
        Check(TJSONObject(Calls.Items[0]).Find('id').AsString = 'tool-1',
          'anthropic call id');
        Check(Response.Find('inputTokens').AsInt64 = 3, 'anthropic usage');
      finally
        Response.Free;
      end;
    finally
      Adapter.Free;
    end;

    AnthropicStreamFake := TFakeTransport.Create;
    AnthropicStreamFake.PathPart := '/v1/messages';
    AnthropicStreamFake.Response :=
      'data: {"type":"message_start","message":{"usage":{"input_tokens":4,"cache_read_input_tokens":1}}}' + #10#10 +
      'data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}' + #10#10 +
      'data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"he"}}' + #10#10 +
      'data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"llo"}}' + #10#10 +
      'data: {"type":"content_block_start","index":1,"content_block":{"type":"tool_use","id":"call-1","name":"echo","input":{}}}' + #10#10 +
      'data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"{\"text\":"}}' + #10#10 +
      'data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"\"hi\"}"}}' + #10#10 +
      'data: {"type":"message_delta","delta":{"stop_reason":"tool_use"},"usage":{"output_tokens":2}}' + #10#10 +
      'data: {"type":"message_stop"}';
    Adapter := TPraxoAnthropicAdapter.Create('https://example.test', 'claude-test');
    Collector := TDeltaCollector.Create;
    try
      Adapter.APIKey := 'ak';
      Adapter.Transport := @AnthropicStreamFake.Send;
      Response := Adapter.GenerateStream(Messages, Tools, 'auto', @Collector.Add);
      try
        Check(Collector.Text = 'hello', 'anthropic stream deltas');
        Value := Response.Find('content');
        Check((Value <> nil) and (Value.AsString = 'hello'), 'anthropic stream content');
        Check(Response.Find('inputTokens').AsInt64 = 4, 'anthropic stream usage');
        Check(Response.Find('outputTokens').AsInt64 = 2, 'anthropic stream output');
        Check(Response.Find('finishReason').AsString = 'tool_use', 'anthropic stream finish');
        Calls := TJSONArray(Response.Find('toolCalls'));
        Check((Calls <> nil) and (Calls.Count = 1), 'anthropic stream calls');
        Check(TJSONObject(Calls.Items[0]).Find('id').AsString = 'call-1',
          'anthropic stream call id');
        Check(Pos('"stream":true', StringReplace(AnthropicStreamFake.CapturedBody,
          ' ', '', [rfReplaceAll])) > 0, 'anthropic stream flag');
      finally
        Response.Free;
        Collector.Free;
      end;
    finally
      Adapter.Free;
      AnthropicStreamFake.Free;
    end;

    GeminiFake := TFakeTransport.Create;
    GeminiFake.PathPart := ':generateContent';
    GeminiFake.Response := '{"candidates":[{"content":{"parts":[{"text":"hello"},' +
      '{"functionCall":{"name":"echo","args":{"text":"hi"}}}]},' +
      '"finishReason":"STOP"}],"usageMetadata":{"promptTokenCount":3,' +
      '"candidatesTokenCount":4}}';
    GeminiAdapter := TPraxoGeminiAdapter.Create('https://example.test', 'gemini-test');
    try
      GeminiAdapter.APIKey := 'gk';
      GeminiAdapter.Transport := @GeminiFake.Send;
      Response := GeminiAdapter.Generate(Messages, Tools, 'auto');
      try
        Value := Response.Find('content');
        Check((Value <> nil) and (Value.AsString = 'hello'), 'gemini content');
        Calls := TJSONArray(Response.Find('toolCalls'));
        Check((Calls <> nil) and (Calls.Count = 1), 'gemini calls');
        Check(TJSONObject(Calls.Items[0]).Find('name').AsString = 'echo',
          'gemini call name');
        Check(Response.Find('inputTokens').AsInt64 = 3, 'gemini usage');
      finally
        Response.Free;
      end;
    finally
      GeminiAdapter.Free;
    end;

    GeminiStreamFake := TFakeTransport.Create;
    GeminiStreamFake.PathPart := ':streamGenerateContent?alt=sse';
    GeminiStreamFake.Response :=
      'data: {"candidates":[{"content":{"parts":[{"text":"he"}]}}]}' + #10#10 +
      'data: {"candidates":[{"content":{"parts":[{"text":"llo"},' +
      '{"functionCall":{"name":"echo","args":{"text":"hi"}}}]},' +
      '"finishReason":"STOP"}],"usageMetadata":{"promptTokenCount":4,' +
      '"candidatesTokenCount":2,"cachedContentTokenCount":1}}';
    GeminiAdapter := TPraxoGeminiAdapter.Create('https://example.test', 'gemini-test');
    Collector := TDeltaCollector.Create;
    try
      GeminiAdapter.APIKey := 'gk';
      GeminiAdapter.Transport := @GeminiStreamFake.Send;
      Response := GeminiAdapter.GenerateStream(Messages, Tools, 'auto', @Collector.Add);
      try
        Check(Collector.Text = 'hello', 'gemini stream deltas');
        Value := Response.Find('content');
        Check((Value <> nil) and (Value.AsString = 'hello'), 'gemini stream content');
        Check(Response.Find('inputTokens').AsInt64 = 4, 'gemini stream usage');
        Check(Response.Find('outputTokens').AsInt64 = 2, 'gemini stream output');
        Check(Response.Find('finishReason').AsString = 'STOP', 'gemini stream finish');
        Calls := TJSONArray(Response.Find('toolCalls'));
        Check((Calls <> nil) and (Calls.Count = 1), 'gemini stream calls');
        Check(TJSONObject(Calls.Items[0]).Find('name').AsString = 'echo',
          'gemini stream call name');
      finally
        Response.Free;
        Collector.Free;
      end;
    finally
      GeminiAdapter.Free;
      GeminiStreamFake.Free;
    end;
  finally
    Messages.Free;
    Tools.Free;
  end;
  WriteLn('delphi provider tests passed');
end.
