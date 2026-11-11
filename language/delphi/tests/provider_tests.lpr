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
    function Send(const Path, Body: UTF8String;
      out ResponseBody: UTF8String; out StatusCode: Integer): Boolean;
  end;

function TFakeTransport.Send(const Path, Body: UTF8String;
  out ResponseBody: UTF8String; out StatusCode: Integer): Boolean;
begin
  Check(Pos(PathPart, Path) > 0, 'provider path');
  ResponseBody := Response;
  StatusCode := 200;
  Result := True;
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
  GeminiFake: TFakeTransport;
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
  finally
    Messages.Free;
    Tools.Free;
  end;
  WriteLn('delphi provider tests passed');
end.
