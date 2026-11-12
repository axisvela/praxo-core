program mcp_tests;
{$mode objfpc}{$H+}

uses SysUtils, fpjson, praxo, praxo_mcp;

type
  TFakeTransport = class(TPraxoMcpTransport)
  public
    Closed: Boolean;
    Notified: UTF8String;
    function Request(const Method: UTF8String; Params: TJSONObject;
      TimeoutMs: Integer): TJSONObject; override;
    procedure Notify(const Method: UTF8String; Params: TJSONObject); override;
    procedure Close; override;
  end;

function TFakeTransport.Request(const Method: UTF8String;
  Params: TJSONObject; TimeoutMs: Integer): TJSONObject;
begin
  if Method = 'initialize' then
    Result := PraxoParseJSON(
      '{"protocolVersion":"2025-03-26","serverInfo":{"name":"fake-http"}}'
    ) as TJSONObject
  else if Method = 'tools/list' then
    Result := PraxoParseJSON(
      '{"tools":[{"name":"echo","description":"Echo input",' +
      '"inputSchema":{"type":"object"}}]}'
    ) as TJSONObject
  else if Method = 'tools/call' then
    Result := PraxoParseJSON(
      '{"content":[{"type":"text","text":"http-ok"}]}'
    ) as TJSONObject
  else
    Result := TJSONObject.Create;
end;

procedure TFakeTransport.Notify(const Method: UTF8String;
  Params: TJSONObject);
begin
  Notified := Method;
end;

procedure TFakeTransport.Close;
begin
  Closed := True;
end;

procedure Check(Condition: Boolean; const Detail: UTF8String);
begin
  if not Condition then
    raise Exception.Create(Detail);
end;

var
  Fake: TFakeTransport;
  Client: TPraxoMcpClient;
  Tools: TJSONArray;
  Arguments, ResultData: TJSONData;
  Code: UTF8String;
begin
  Fake := TFakeTransport.Create;
  Client := TPraxoMcpClient.Create(Fake, '2025-03-26');
  try
    Client.Start;
    Check(Client.ProtocolVersion = '2025-03-26', 'mcp protocol version');
    Check(Fake.Notified = 'notifications/initialized', 'mcp notify');
    Tools := Client.ListTools;
    try
      Check(Tools.Count = 1, 'mcp tools');
      Check((Tools.Items[0] as TJSONObject).Get('name', '') = 'echo',
        'mcp tool name');
    finally
      Tools.Free;
    end;
    Arguments := PraxoParseJSON('{"text":"hi"}');
    try
      ResultData := Client.CallTool('echo', Arguments as TJSONObject);
    finally
      Arguments.Free;
    end;
    try
      Check(ResultData.AsString = 'http-ok', 'mcp call');
    finally
      ResultData.Free;
    end;
    Client.Close;
    Check(Fake.Closed, 'mcp close');
  finally
    Client.Free;
    Fake.Free;
  end;

  Code := '';
  try
    TPraxoHttpMcpTransport.Create('http://example.com/mcp');
  except
    on Error: EPraxoMcp do
      Code := Error.Code;
  end;
  Check(Code = 'MCP_TRANSPORT', 'mcp https required');

  WriteLn('MCP tests passed');
end.
