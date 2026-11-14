program mcp_example;

{$mode objfpc}{$H+}

uses fpjson, praxo_mcp;

type
  TFakeTransport = class(TPraxoMcpTransport)
  public
    function Request(const Method: UTF8String; Params: TJSONObject;
      TimeoutMs: Integer): TJSONObject; override;
    procedure Notify(const Method: UTF8String; Params: TJSONObject); override;
    procedure Close; override;
  end;

function TFakeTransport.Request(const Method: UTF8String; Params: TJSONObject;
  TimeoutMs: Integer): TJSONObject;
begin
  if Method = 'initialize' then
    Exit(TJSONObject(GetJSON('{"protocolVersion":"2024-11-05","serverInfo":{"name":"example-mcp"}}')));
  if Method = 'tools/list' then
    Exit(TJSONObject(GetJSON('{"tools":[{"name":"echo"},{"name":"add"}]}')));
  if Method = 'tools/call' then
    Exit(TJSONObject(GetJSON('{"structuredContent":{"sum":5}}')));
  Result := TJSONObject.Create;
end;

procedure TFakeTransport.Notify(const Method: UTF8String; Params: TJSONObject);
begin
end;

procedure TFakeTransport.Close;
begin
end;

var
  Client: TPraxoMcpClient;
  Tools: TJSONArray;
  Result: TJSONData;
begin
  Client := TPraxoMcpClient.Create(TFakeTransport.Create);
  try
    Client.Start;
    Tools := Client.ListTools;
    Result := Client.CallTool('add', TJSONObject.Create);
    try
      if Tools.Count <> 2 then Halt(1);
      if TJSONObject(Tools.Items[1]).Get('name') <> 'add' then Halt(1);
      if TJSONObject(Result).Get('sum') <> 5 then Halt(1);
    finally
      Result.Free;
    end;
    Client.Close;
  finally
    Client.Free;
  end;
  WriteLn('Delphi MCP example passed');
end.
