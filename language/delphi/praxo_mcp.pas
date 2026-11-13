unit praxo_mcp;
{$mode objfpc}{$H+}

interface

uses SysUtils, Classes, Process, StrUtils, fpjson;

type
  EPraxoMcp = class(Exception)
  public
    Code: UTF8String;
    constructor CreateCode(const ACode, AMessage: UTF8String);
  end;

  TPraxoMcpTransport = class
  public
    function Request(const Method: UTF8String; Params: TJSONObject;
      TimeoutMs: Integer): TJSONObject; virtual; abstract;
    procedure Notify(const Method: UTF8String; Params: TJSONObject); virtual; abstract;
    procedure Close; virtual; abstract;
  end;

  TPraxoMcpClient = class
  private
    FTransport: TPraxoMcpTransport;
    FRequestedVersion: UTF8String;
    FClientVersion: UTF8String;
    FTimeoutMs: Integer;
    FProtocolVersion: UTF8String;
    FServerInfo: TJSONObject;
  public
    constructor Create(Transport: TPraxoMcpTransport;
      const RequestedVersion: UTF8String = '2024-11-05';
      TimeoutMs: Integer = 30000;
      const ClientVersion: UTF8String = '0.5.0');
    destructor Destroy; override;
    function Start: TPraxoMcpClient;
    function ListTools: TJSONArray;
    function CallTool(const Name: UTF8String; Arguments: TJSONObject): TJSONData;
    procedure Close;
    property ProtocolVersion: UTF8String read FProtocolVersion;
    property ServerInfo: TJSONObject read FServerInfo;
  end;

  TPraxoStdioMcpTransport = class(TPraxoMcpTransport)
  private
    FCommand: UTF8String;
    FArgs: TStringList;
    FProcess: TProcess;
    FNextId: Integer;
    FClosed: Boolean;
  public
    constructor Create(const Command: UTF8String; Args: array of UTF8String);
    destructor Destroy; override;
    procedure Start;
    function Request(const Method: UTF8String; Params: TJSONObject;
      TimeoutMs: Integer): TJSONObject; override;
    procedure Notify(const Method: UTF8String; Params: TJSONObject); override;
    procedure Close; override;
  end;

  TPraxoHttpMcpTransport = class(TPraxoMcpTransport)
  private
    FEndpoint: UTF8String;
    FProtocolVersion: UTF8String;
    FSessionId: UTF8String;
    FHeaders: TStringList;
    FNextId: Integer;
    FClosed: Boolean;
    function Post(Message: TJSONObject; TimeoutMs: Integer): TJSONObject;
    procedure ApplyHeaders(Client: TObject);
  public
    constructor Create(const Endpoint: UTF8String; Headers: TStrings = nil;
      const ProtocolVersion: UTF8String = '2025-03-26');
    destructor Destroy; override;
    function Request(const Method: UTF8String; Params: TJSONObject;
      TimeoutMs: Integer): TJSONObject; override;
    procedure Notify(const Method: UTF8String; Params: TJSONObject); override;
    procedure Close; override;
  end;

implementation

uses fphttpclient, praxo;

constructor EPraxoMcp.CreateCode(const ACode, AMessage: UTF8String);
begin
  inherited Create(AMessage);
  Code := ACode;
end;

function JsonField(Obj: TJSONObject; const Name: UTF8String): TJSONData;
var
  I: Integer;
begin
  Result := nil;
  if Obj = nil then Exit;
  for I := 0 to Obj.Count - 1 do
    if Obj.Names[I] = Name then Exit(Obj.Items[I]);
end;

function CloneJson(Data: TJSONData): TJSONData;
begin
  if Data = nil then Exit(nil);
  Result := PraxoParseJSON(Data.AsJSON);
end;

function ErrorCode(const Method: UTF8String): EPraxoMcp;
begin
  Result := EPraxoMcp.CreateCode('MCP_RPC', 'mcp: ' + Method + ' failed');
end;

constructor TPraxoMcpClient.Create(Transport: TPraxoMcpTransport;
  const RequestedVersion: UTF8String; TimeoutMs: Integer;
  const ClientVersion: UTF8String);
begin
  inherited Create;
  FTransport := Transport;
  FRequestedVersion := RequestedVersion;
  FTimeoutMs := TimeoutMs;
  FClientVersion := ClientVersion;
  FServerInfo := TJSONObject.Create;
end;

destructor TPraxoMcpClient.Destroy;
begin
  FServerInfo.Free;
  inherited Destroy;
end;

function TPraxoMcpClient.Start: TPraxoMcpClient;
var
  Params, ResultData, ClientInfo: TJSONObject;
  Version: UTF8String;
  Info: TJSONData;
begin
  if FProtocolVersion <> '' then Exit(Self);
  Params := TJSONObject.Create;
  try
    Params.Add('protocolVersion', FRequestedVersion);
    Params.Add('capabilities', TJSONObject.Create);
    ClientInfo := TJSONObject.Create;
    ClientInfo.Add('name', 'praxo-core');
    ClientInfo.Add('version', FClientVersion);
    Params.Add('clientInfo', ClientInfo);
    ResultData := FTransport.Request('initialize', Params, FTimeoutMs);
  finally
    Params.Free;
  end;
  try
    Version := ResultData.Get('protocolVersion', '');
    if Version = '' then
      raise EPraxoMcp.CreateCode('MCP_HANDSHAKE',
        'mcp: initialize returned no protocol version');
    FProtocolVersion := Version;
    Info := JsonField(ResultData, 'serverInfo');
    if Info is TJSONObject then
    begin
      FServerInfo.Free;
      FServerInfo := CloneJson(Info) as TJSONObject;
    end;
  finally
    ResultData.Free;
  end;
  Params := TJSONObject.Create;
  try
    FTransport.Notify('notifications/initialized', Params);
  finally
    Params.Free;
  end;
  Result := Self;
end;

function TPraxoMcpClient.ListTools: TJSONArray;
var
  Params, ResultData: TJSONObject;
  Tools, Next: TJSONData;
  Tool: TJSONObject;
  Cursor: UTF8String;
  Seen: TStringList;
  I, J: Integer;
  Name: UTF8String;
  Duplicate: Boolean;
begin
  Start;
  Result := TJSONArray.Create;
  Seen := TStringList.Create;
  Seen.CaseSensitive := True;
  try
    Cursor := '';
    repeat
      Params := TJSONObject.Create;
      if Cursor <> '' then Params.Add('cursor', Cursor);
      try
        ResultData := FTransport.Request('tools/list', Params, FTimeoutMs);
      finally
        Params.Free;
      end;
      try
        Tools := JsonField(ResultData, 'tools');
        if Tools is TJSONArray then
          for I := 0 to TJSONArray(Tools).Count - 1 do
          begin
            Tool := TJSONArray(Tools).Items[I] as TJSONObject;
            Name := Tool.Get('name', '');
            Duplicate := False;
            for J := 0 to Seen.Count - 1 do
              if Seen[J] = Name then Duplicate := True;
            if Duplicate then
              raise EPraxoMcp.CreateCode('MCP_DUPLICATE_TOOL',
                'mcp: duplicate tool ' + Name);
            Seen.Add(Name);
            Result.Add(CloneJson(Tool));
          end;
        Next := JsonField(ResultData, 'nextCursor');
        if (Next = nil) or (Next.JSONType <> jtString) or
          (Next.AsString = '') then
          Cursor := ''
        else
        begin
          Cursor := Next.AsString;
          if Seen.IndexOf('cursor:' + Cursor) >= 0 then
            raise EPraxoMcp.CreateCode('MCP_PAGINATION',
              'mcp: repeated tool pagination cursor');
          Seen.Add('cursor:' + Cursor);
        end;
      finally
        ResultData.Free;
      end;
    until Cursor = '';
  finally
    Seen.Free;
  end;
end;

function TPraxoMcpClient.CallTool(const Name: UTF8String;
  Arguments: TJSONObject): TJSONData;
var
  Params, ResultData: TJSONObject;
  Structured, Content: TJSONData;
  Texts: TJSONArray;
  I: Integer;
  Text: UTF8String;
begin
  Start;
  Params := TJSONObject.Create;
  try
    Params.Add('name', Name);
    if Arguments = nil then
      Params.Add('arguments', TJSONObject.Create)
    else
      Params.Add('arguments', CloneJson(Arguments));
    ResultData := FTransport.Request('tools/call', Params, FTimeoutMs);
  finally
    Params.Free;
  end;
  try
    if ResultData.Get('isError', False) then
      raise EPraxoMcp.CreateCode('MCP_TOOL_ERROR',
        'mcp: tool ' + Name + ' failed');
    Structured := JsonField(ResultData, 'structuredContent');
    if Structured <> nil then Exit(CloneJson(Structured));
    Texts := TJSONArray.Create;
    try
      Content := JsonField(ResultData, 'content');
      if Content is TJSONArray then
        for I := 0 to TJSONArray(Content).Count - 1 do
        begin
          if (TJSONArray(Content).Items[I] is TJSONObject) and
            (TJSONObject(TJSONArray(Content).Items[I]).Get('type', '') = 'text') then
          begin
            Text := TJSONObject(TJSONArray(Content).Items[I]).Get('text', '');
            Texts.Add(Text);
          end;
        end;
      if Texts.Count = 0 then Exit(TJSONNull.Create);
      if Texts.Count = 1 then Exit(TJSONString.Create(Texts[0].AsString));
      Result := CloneJson(Texts);
    finally
      Texts.Free;
    end;
  finally
    ResultData.Free;
  end;
end;

procedure TPraxoMcpClient.Close;
begin
  FTransport.Close;
  FProtocolVersion := '';
end;

constructor TPraxoStdioMcpTransport.Create(const Command: UTF8String;
  Args: array of UTF8String);
var
  I: Integer;
begin
  inherited Create;
  FCommand := Command;
  FArgs := TStringList.Create;
  for I := Low(Args) to High(Args) do FArgs.Add(Args[I]);
  FNextId := 0;
end;

destructor TPraxoStdioMcpTransport.Destroy;
begin
  Close;
  FArgs.Free;
  inherited Destroy;
end;

procedure TPraxoStdioMcpTransport.Start;
begin
  if FProcess <> nil then Exit;
  FProcess := TProcess.Create(nil);
  FProcess.Executable := FCommand;
  FProcess.Parameters.Assign(FArgs);
  FProcess.Options := [poUsePipes];
  FProcess.Execute;
end;

function ReadLine(Stream: TStream): UTF8String;
var
  B: Byte;
  Data: TBytes;
begin
  SetLength(Data, 0);
  while Stream.Read(B, 1) = 1 do
  begin
    if B = 10 then Break;
    if B <> 13 then
    begin
      SetLength(Data, Length(Data) + 1);
      Data[High(Data)] := B;
    end;
  end;
  SetLength(Result, Length(Data));
  if Length(Data) > 0 then
    Move(Data[0], Result[1], Length(Data));
end;

function TPraxoStdioMcpTransport.Request(const Method: UTF8String;
  Params: TJSONObject; TimeoutMs: Integer): TJSONObject;
var
  Message, Response: TJSONObject;
  Line: UTF8String;
  Id: Int64;
begin
  Start;
  Inc(FNextId);
  Id := FNextId;
  Message := TJSONObject.Create;
  try
    Message.Add('jsonrpc', '2.0');
    Message.Add('id', Id);
    Message.Add('method', Method);
    Message.Add('params', CloneJson(Params));
    Line := PraxoEncodeJSON(Message) + LineEnding;
    FProcess.Input.Write(Line[1], Length(Line));
  finally
    Message.Free;
  end;
  while True do
  begin
    Line := ReadLine(FProcess.Output);
    if Line = '' then
      raise EPraxoMcp.CreateCode('MCP_CLOSED', 'mcp: connection closed');
    Response := PraxoParseJSON(Line) as TJSONObject;
    if Response.Get('id', Int64(-1)) <> Id then
    begin
      Response.Free;
      Continue;
    end;
    if JsonField(Response, 'error') <> nil then
    begin
      Response.Free;
      raise ErrorCode(Method);
    end;
    Result := CloneJson(JsonField(Response, 'result')) as TJSONObject;
    Response.Free;
    Exit;
  end;
end;

procedure TPraxoStdioMcpTransport.Notify(const Method: UTF8String;
  Params: TJSONObject);
var
  Message: TJSONObject;
  Line: UTF8String;
begin
  Start;
  Message := TJSONObject.Create;
  try
    Message.Add('jsonrpc', '2.0');
    Message.Add('method', Method);
    Message.Add('params', CloneJson(Params));
    Line := PraxoEncodeJSON(Message) + LineEnding;
    FProcess.Input.Write(Line[1], Length(Line));
  finally
    Message.Free;
  end;
end;

procedure TPraxoStdioMcpTransport.Close;
begin
  if FClosed then Exit;
  FClosed := True;
  if FProcess <> nil then
  begin
    FProcess.Terminate(0);
    FreeAndNil(FProcess);
  end;
end;

constructor TPraxoHttpMcpTransport.Create(const Endpoint: UTF8String;
  Headers: TStrings; const ProtocolVersion: UTF8String);
var
  Lower: UTF8String;
  Host: UTF8String;
  StartPos, SlashPos, ColonPos: Integer;
begin
  inherited Create;
  Lower := LowerCase(Endpoint);
  if (Pos('https://', Lower) <> 1) and (Pos('http://', Lower) <> 1) then
    raise EPraxoMcp.CreateCode('MCP_TRANSPORT', 'mcp: invalid HTTP endpoint');
  if Pos('http://', Lower) = 1 then
  begin
    StartPos := 8;
    SlashPos := PosEx('/', Endpoint, StartPos);
    if SlashPos = 0 then SlashPos := Length(Endpoint) + 1;
    Host := Copy(Endpoint, StartPos, SlashPos - StartPos);
    ColonPos := Pos(':', Host);
    if ColonPos > 0 then Host := Copy(Host, 1, ColonPos - 1);
    Host := LowerCase(Host);
    if (Host <> 'localhost') and (Host <> '127.0.0.1') and
      (Host <> '::1') and (Copy(Host, 1, 4) <> '127.') then
      raise EPraxoMcp.CreateCode('MCP_TRANSPORT',
        'mcp: HTTP endpoint must use HTTPS');
  end;
  FEndpoint := Endpoint;
  FProtocolVersion := ProtocolVersion;
  FHeaders := TStringList.Create;
  if Headers <> nil then FHeaders.Assign(Headers);
end;

destructor TPraxoHttpMcpTransport.Destroy;
begin
  Close;
  FHeaders.Free;
  inherited Destroy;
end;

procedure TPraxoHttpMcpTransport.ApplyHeaders(Client: TObject);
var
  I: Integer;
begin
  with TFPHTTPClient(Client) do
  begin
    AddHeader('Content-Type', 'application/json');
    AddHeader('Accept', 'application/json, text/event-stream');
    AddHeader('MCP-Protocol-Version', FProtocolVersion);
    if FSessionId <> '' then AddHeader('MCP-Session-Id', FSessionId);
    for I := 0 to FHeaders.Count - 1 do
      AddHeader(FHeaders.Names[I], FHeaders.ValueFromIndex[I]);
  end;
end;

function HeaderValue(Client: TFPHTTPClient; const Name: UTF8String): UTF8String;
var
  I: Integer;
  Line, Key: UTF8String;
  Colon: Integer;
begin
  Result := '';
  for I := 0 to Client.ResponseHeaders.Count - 1 do
  begin
    Line := Client.ResponseHeaders[I];
    Colon := Pos(':', Line);
    if Colon = 0 then Continue;
    Key := LowerCase(Trim(Copy(Line, 1, Colon - 1)));
    if Key = LowerCase(Name) then
      Exit(Trim(Copy(Line, Colon + 1, Length(Line))));
  end;
end;

function ParseSseResponse(const Body: UTF8String; Id: Int64): TJSONObject;
var
  Lines, Data: TStringList;
  I: Integer;
  Line, Payload: UTF8String;
  Decoded: TJSONData;
begin
  Result := nil;
  Lines := TStringList.Create;
  Data := TStringList.Create;
  try
    Lines.Text := StringReplace(Body, #13#10, #10, [rfReplaceAll]);
    for I := 0 to Lines.Count - 1 do
    begin
      Line := Lines[I];
      if Line = '' then
      begin
        if Data.Count > 0 then
        begin
          Payload := Data.Text;
          if (Length(Payload) > 0) and (Payload[Length(Payload)] = #10) then
            Delete(Payload, Length(Payload), 1);
          Decoded := PraxoParseJSON(Payload);
          if Decoded is TJSONObject then
          begin
            if TJSONObject(Decoded).Get('id', Int64(-1)) = Id then
            begin
              Result := TJSONObject(Decoded);
              Exit;
            end;
            if Result = nil then Result := TJSONObject(Decoded)
            else Decoded.Free;
          end
          else
            Decoded.Free;
          Data.Clear;
        end;
        Continue;
      end;
      if Copy(Line, 1, 1) = ':' then Continue;
      if Copy(Line, 1, 5) = 'data:' then
        Data.Add(Trim(Copy(Line, 6, Length(Line))));
    end;
    if (Result = nil) and (Data.Count > 0) then
    begin
      Decoded := PraxoParseJSON(Data.Text);
      if Decoded is TJSONObject then Result := TJSONObject(Decoded)
      else Decoded.Free;
    end;
    if Result = nil then
      raise EPraxoMcp.CreateCode('MCP_PROTOCOL',
        'mcp: response contained no message');
  finally
    Lines.Free;
    Data.Free;
  end;
end;

function TPraxoHttpMcpTransport.Post(Message: TJSONObject;
  TimeoutMs: Integer): TJSONObject;
var
  Client: TFPHTTPClient;
  Body, Session, ContentType: UTF8String;
  Status: Integer;
  Decoded: TJSONData;
  ResultData: TJSONData;
  Id: Int64;
begin
  Client := TFPHTTPClient.Create(nil);
  try
    Client.ConnectTimeout := TimeoutMs;
    Client.IOTimeout := TimeoutMs;
    ApplyHeaders(Client);
    Client.RequestBody := TStringStream.Create(PraxoEncodeJSON(Message));
    try
      Body := Client.Post(FEndpoint);
    finally
      Client.RequestBody.Free;
    end;
    Status := Client.ResponseStatusCode;
    Session := HeaderValue(Client, 'mcp-session-id');
    if Session <> '' then FSessionId := Session;
    ContentType := HeaderValue(Client, 'content-type');
    if (Status = 202) or (Status = 204) or (Trim(Body) = '') then
      Exit(TJSONObject.Create);
    if (Status < 200) or (Status >= 300) then
      raise EPraxoMcp.CreateCode('MCP_TRANSPORT',
        'mcp: HTTP ' + IntToStr(Status));
    Id := Message.Get('id', Int64(-1));
    if Pos('text/event-stream', LowerCase(ContentType)) > 0 then
      Result := ParseSseResponse(Body, Id)
    else
    begin
      Decoded := PraxoParseJSON(Body);
      if not (Decoded is TJSONObject) then
      begin
        Decoded.Free;
        raise EPraxoMcp.CreateCode('MCP_PROTOCOL', 'mcp: invalid response');
      end;
      Result := TJSONObject(Decoded);
    end;
    ResultData := JsonField(Result, 'result');
    if (ResultData is TJSONObject) and
      (TJSONObject(ResultData).Get('protocolVersion', '') <> '') then
      FProtocolVersion := TJSONObject(ResultData).Get('protocolVersion', '');
  finally
    Client.Free;
  end;
end;

function TPraxoHttpMcpTransport.Request(const Method: UTF8String;
  Params: TJSONObject; TimeoutMs: Integer): TJSONObject;
var
  Message, Response: TJSONObject;
  ErrorData, ResultData: TJSONData;
begin
  if FClosed then
    raise EPraxoMcp.CreateCode('MCP_CLOSED', 'mcp: client is closed');
  Inc(FNextId);
  Message := TJSONObject.Create;
  try
    Message.Add('jsonrpc', '2.0');
    Message.Add('id', FNextId);
    Message.Add('method', Method);
    Message.Add('params', CloneJson(Params));
    Response := Post(Message, TimeoutMs);
  finally
    Message.Free;
  end;
  try
    ErrorData := JsonField(Response, 'error');
    if ErrorData <> nil then
      raise ErrorCode(Method);
    ResultData := JsonField(Response, 'result');
    Result := CloneJson(ResultData) as TJSONObject;
  finally
    Response.Free;
  end;
end;

procedure TPraxoHttpMcpTransport.Notify(const Method: UTF8String;
  Params: TJSONObject);
var
  Message, Response: TJSONObject;
begin
  if FClosed then Exit;
  Message := TJSONObject.Create;
  try
    Message.Add('jsonrpc', '2.0');
    Message.Add('method', Method);
    Message.Add('params', CloneJson(Params));
    try
      Response := Post(Message, 30000);
      Response.Free;
    except
    end;
  finally
    Message.Free;
  end;
end;

procedure TPraxoHttpMcpTransport.Close;
var
  Client: TFPHTTPClient;
begin
  if FClosed then Exit;
  FClosed := True;
  if FSessionId = '' then Exit;
  Client := TFPHTTPClient.Create(nil);
  try
    try
      ApplyHeaders(Client);
      Client.Delete(FEndpoint);
    except
    end;
  finally
    Client.Free;
  end;
end;

end.
