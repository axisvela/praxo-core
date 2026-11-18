program representative_chain;

{$mode objfpc}{$H+}

uses SysUtils, Classes, fpjson, praxo, praxo_core, praxo_agent, praxo_mcp,
  praxo_otel, praxo_harmovela, praxo_delegation;

type
  TChainState = class
  public
    Effects: TStringList;
    ChildCalls: Integer;
    OtelCount: Integer;
    HarmCount: Integer;
    constructor Create;
    destructor Destroy; override;
    procedure IncEffect(const Target: string);
    function EffectCount(const Target: string): Integer;
  end;

  TFakeMcpTransport = class(TPraxoMcpTransport)
  private
    FState: TChainState;
  public
    constructor Create(State: TChainState);
    function Request(const Method: UTF8String; Params: TJSONObject;
      TimeoutMs: Integer): TJSONObject; override;
    procedure Notify(const Method: UTF8String; Params: TJSONObject); override;
    procedure Close; override;
  end;

  TCapture = class
  private
    FState: TChainState;
  public
    constructor Create(State: TChainState);
    function OtelSend(const Request: TPraxoOtelRequest): TPraxoOtelResponse;
    function HarmSend(const Request: TPraxoHarmovelaRequest): TPraxoHarmovelaResponse;
  end;

  TChainHost = class(TPraxoAgentHost)
  private
    FMode: string;
    FCalls: Integer;
    FState: TChainState;
    FClient: TPraxoMcpClient;
    FOtel: TPraxoOtelSink;
    FHarm: TPraxoHarmovelaSink;
  public
    constructor Create(const Mode: string; State: TChainState;
      Client: TPraxoMcpClient; Otel: TPraxoOtelSink; Harm: TPraxoHarmovelaSink);
    function Generate(Messages: TJSONArray): TJSONObject; override;
    function Invoke(const Name: UTF8String; Arguments: TJSONObject): TJSONData; override;
    procedure Emit(const EventType: UTF8String); override;
  end;

function ParentAuthorize(const Kind, ToolName: UTF8String;
  Arguments: TJSONObject): Boolean; forward;
function ChildAuthorize(const Kind, ToolName: UTF8String;
  Arguments: TJSONObject): Boolean; forward;
function EditDecision(const Interrupt: TPraxoAgentInterrupt): TPraxoAgentDecision; forward;

constructor TChainState.Create;
begin
  inherited Create;
  Effects := TStringList.Create;
  Effects.NameValueSeparator := '=';
end;

destructor TChainState.Destroy;
begin
  Effects.Free;
  inherited Destroy;
end;

procedure TChainState.IncEffect(const Target: string);
var
  Current: Integer;
begin
  Current := StrToIntDef(Effects.Values[Target], 0);
  Effects.Values[Target] := IntToStr(Current + 1);
end;

function TChainState.EffectCount(const Target: string): Integer;
begin
  Result := StrToIntDef(Effects.Values[Target], 0);
end;

constructor TFakeMcpTransport.Create(State: TChainState);
begin
  inherited Create;
  FState := State;
end;

function TFakeMcpTransport.Request(const Method: UTF8String;
  Params: TJSONObject; TimeoutMs: Integer): TJSONObject;
var
  ResultData, Args, Item: TJSONObject;
  Target: string;
  Content: TJSONArray;
begin
  if Method = 'initialize' then
  begin
    ResultData := TJSONObject.Create;
    ResultData.Add('protocolVersion', '2024-11-05');
    ResultData.Add('serverInfo', TJSONObject.Create(['name', 'fake-mcp']));
    Exit(ResultData);
  end;
  if Method = 'tools/list' then
  begin
    ResultData := TJSONObject.Create;
    Args := TJSONObject.Create;
    Args.Add('type', 'object');
    Args.Add('properties', TJSONObject.Create(['target', TJSONObject.Create(['type', 'string'])]));
    Args.Add('required', TJSONArray.Create(['target']));
    Item := TJSONObject.Create;
    Item.Add('name', 'record');
    Item.Add('description', 'Record a target');
    Item.Add('inputSchema', Args);
    ResultData.Add('tools', TJSONArray.Create([Item]));
    Exit(ResultData);
  end;
  if Method = 'tools/call' then
  begin
    Args := TJSONObject(Params.Find('arguments'));
    Target := '';
    if (Args <> nil) and (Args.Find('target') <> nil) then
      Target := Args.Find('target').AsString;
    FState.IncEffect(Target);
    Content := TJSONArray.Create;
    Content.Add(TJSONObject.Create(['type', 'text', 'text', 'recorded:' + Target]));
    ResultData := TJSONObject.Create;
    ResultData.Add('content', Content);
    Exit(ResultData);
  end;
  Result := TJSONObject.Create;
end;

procedure TFakeMcpTransport.Notify(const Method: UTF8String; Params: TJSONObject);
begin
end;

procedure TFakeMcpTransport.Close;
begin
end;

constructor TCapture.Create(State: TChainState);
begin
  inherited Create;
  FState := State;
end;

function TCapture.OtelSend(const Request: TPraxoOtelRequest): TPraxoOtelResponse;
begin
  Inc(FState.OtelCount);
  Result.StatusCode := 200;
  Result.Body := '';
end;

function TCapture.HarmSend(const Request: TPraxoHarmovelaRequest): TPraxoHarmovelaResponse;
begin
  Inc(FState.HarmCount);
  Result.StatusCode := 202;
  Result.Body := '';
end;

constructor TChainHost.Create(const Mode: string; State: TChainState;
  Client: TPraxoMcpClient; Otel: TPraxoOtelSink; Harm: TPraxoHarmovelaSink);
begin
  inherited Create;
  FMode := Mode;
  FState := State;
  FClient := Client;
  FOtel := Otel;
  FHarm := Harm;
end;

function ToolCallObject(const Name, Target: string): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('id', Name + '-call');
  Result.Add('name', Name);
  Result.Add('arguments', TJSONObject.Create(['target', Target]));
end;

function TChainHost.Generate(Messages: TJSONArray): TJSONObject;
var
  Last: TJSONObject;
  Calls: TJSONArray;
begin
  Last := TJSONObject(Messages.Items[Messages.Count - 1]);
  Result := TJSONObject.Create;
  Result.Add('inputTokens', Int64(0));
  Result.Add('outputTokens', Int64(0));
  if FMode = 'child' then
  begin
    Inc(FCalls);
    Inc(FState.ChildCalls);
    if FCalls = 1 then
    begin
      Result.Add('content', '');
      Result.Add('toolCalls', TJSONArray.Create([ToolCallObject('record', 'child')]));
    end
    else
      Result.Add('content', 'DONE');
    Exit;
  end;
  if FMode = 'denied' then
  begin
    Result.Add('content', '');
    Result.Add('toolCalls', TJSONArray.Create([ToolCallObject('record', 'edit-me')]));
    Exit;
  end;
  Inc(FCalls);
  if FCalls = 1 then
  begin
    Result.Add('content', '');
    Result.Add('toolCalls', TJSONArray.Create([ToolCallObject('record', 'parent')]));
  end
  else if FCalls = 2 then
  begin
    Calls := TJSONArray.Create;
    Calls.Add(TJSONObject.Create(['id', 'parent-delegate', 'name', 'delegate',
      'arguments', TJSONObject.Create(['task', 'record child'])]));
    Result.Add('content', '');
    Result.Add('toolCalls', Calls);
  end
  else
    Result.Add('content', 'DONE');
end;

function TChainHost.Invoke(const Name: UTF8String; Arguments: TJSONObject): TJSONData;
var
  ChildHost: TChainHost;
  Options: TPraxoAgentOptions;
  ResultValue: TPraxoAgentResult;
  Allowed: TPraxoAgentStringArray;
begin
  if Name = 'record' then
    Exit(FClient.CallTool('record', Arguments));
  if Name = 'delegate' then
  begin
    ChildHost := TChainHost.Create('child', FState, FClient, FOtel, FHarm);
    try
      Options := PraxoAgentOptionsNew;
      Options.MaxSteps := 3;
      Options.RequirePolicy := True;
      Options.Authorize := @ChildAuthorize;
      Options.RequireToolScope := True;
      SetLength(Allowed, 1);
      Allowed[0] := 'record';
      Options.AllowedTools := Allowed;
      Options.SessionId := 'chain-child';
      ResultValue := PraxoRunAgentSession(ChildHost, nil, 'record child', Options);
      Result := TJSONString.Create(ResultValue.Output);
    finally
    end;
    Exit;
  end;
  raise EPraxoAgent.CreateCode('TOOL_NOT_FOUND', 'unknown tool: ' + Name);
end;

procedure TChainHost.Emit(const EventType: UTF8String);
var
  Event: TPraxoEvent;
begin
  Event.Kind := EventType;
  Event.SessionId := 'chain-session';
  Event.RunId := 'run-chain';
  Event.Data := nil;
  FOtel.Emit(Event);
  FHarm.Emit(Event);
end;

function ParentAuthorize(const Kind, ToolName: UTF8String;
  Arguments: TJSONObject): Boolean;
var
  Target: string;
begin
  if Kind = 'model.generate' then Exit(True);
  if Kind <> 'tool.invoke' then Exit(False);
  if ToolName = 'delegate' then Exit(True);
  if ToolName <> 'record' then Exit(False);
  Target := '';
  if (Arguments <> nil) and (Arguments.Find('target') <> nil) then
    Target := Arguments.Find('target').AsString;
  Result := Target <> 'blocked';
end;

function ChildAuthorize(const Kind, ToolName: UTF8String;
  Arguments: TJSONObject): Boolean;
begin
  if Kind = 'model.generate' then Exit(True);
  Result := (Kind = 'tool.invoke') and (ToolName = 'record');
end;

function EditDecision(const Interrupt: TPraxoAgentInterrupt): TPraxoAgentDecision;
begin
  Result.Action := PraxoInterruptEdit;
  Result.HasArguments := True;
  Result.Arguments := TJSONObject.Create(['target', 'blocked']);
  Result.Response := '';
  Result.Reason := '';
end;

procedure FreeResult(var Value: TPraxoAgentResult);
begin
  if Value.Messages <> nil then Value.Messages.Free;
  Value.Messages := nil;
end;

var
  State: TChainState;
  Capture: TCapture;
  Transport: TFakeMcpTransport;
  Client: TPraxoMcpClient;
  Otel: TPraxoOtelSink;
  Harm: TPraxoHarmovelaSink;
  Host: TChainHost;
  Options: TPraxoAgentOptions;
  ResultValue, DeniedValue: TPraxoAgentResult;
  Allowed: TPraxoAgentStringArray;
  Interrupts: TPraxoAgentStringArray;
  Tools: TJSONArray;
  Denied: Boolean;

begin
  State := TChainState.Create;
  Capture := TCapture.Create(State);
  Transport := TFakeMcpTransport.Create(State);
  Client := TPraxoMcpClient.Create(Transport, '2024-11-05', 1000, '0.0.0');
  Otel := TPraxoOtelSink.Create('http://otel.local/v1/traces');
  Harm := TPraxoHarmovelaSink.Create('http://harmovela.local');
  Otel.Transport := @Capture.OtelSend;
  Harm.Transport := @Capture.HarmSend;
  try
    Client.Start;
    Tools := Client.ListTools;
    try
      if Tools.Count <> 1 then Halt(1);
    finally
      Tools.Free;
    end;
    Host := TChainHost.Create('parent', State, Client, Otel, Harm);
    try
      Options := PraxoAgentOptionsNew;
      Options.MaxSteps := 4;
      Options.RequirePolicy := True;
      Options.Authorize := @ParentAuthorize;
      Options.RequireToolScope := True;
      SetLength(Allowed, 2);
      Allowed[0] := 'record';
      Allowed[1] := 'delegate';
      Options.AllowedTools := Allowed;
      Options.SessionId := 'chain-parent';
      ResultValue := PraxoRunAgentSession(Host, nil, 'record parent, then delegate', Options);
      try
        DeniedValue := Default(TPraxoAgentResult);
        Denied := False;
        Host := TChainHost.Create('denied', State, Client, Otel, Harm);
        try
          Options := PraxoAgentOptionsNew;
          Options.MaxSteps := 2;
          Options.RequirePolicy := True;
          Options.Authorize := @ParentAuthorize;
          Options.RequireToolScope := True;
          SetLength(Allowed, 1);
          Allowed[0] := 'record';
          Options.AllowedTools := Allowed;
          Options.SessionId := 'chain-denied';
          SetLength(Interrupts, 1);
          Interrupts[0] := 'record';
          Options.InterruptOn := Interrupts;
          Options.OnInterruptDecision := @EditDecision;
          try
            DeniedValue := PraxoRunAgentSession(Host, nil, 'attempt a denied edit', Options);
          except
            on E: EPraxoAgent do
              Denied := E.Code = 'AGENT_POLICY_DENIED';
          end;
        finally
        end;
        WriteLn('output: ', ResultValue.Output);
        WriteLn('effects: parent=', State.EffectCount('parent'),
          ' child=', State.EffectCount('child'));
        WriteLn('child calls: ', State.ChildCalls);
        WriteLn('otel spans: ', State.OtelCount);
        WriteLn('harmovela events: ', State.HarmCount);
        WriteLn('denied effects: ', State.EffectCount('blocked'));
        if ResultValue.Output <> 'DONE' then Halt(1);
        if State.EffectCount('parent') <> 1 then Halt(1);
        if State.EffectCount('child') <> 1 then Halt(1);
        if State.OtelCount < 3 then Halt(1);
        if State.HarmCount < 3 then Halt(1);
        if State.EffectCount('blocked') <> 0 then Halt(1);
        if not Denied then Halt(1);
      finally
      end;
    finally
    end;
  finally
  end;
end.
