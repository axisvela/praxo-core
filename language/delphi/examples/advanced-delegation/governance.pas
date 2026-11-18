program delegation_governance;

{$mode objfpc}{$H+}

uses SysUtils, Classes, fpjson, praxo, praxo_agent, praxo_delegation;

type
  TGovState = class
  public
    Effects: TStringList;
    Budget: Integer;
    Children: Integer;
    constructor Create;
    destructor Destroy; override;
    procedure IncEffect(const Target: string);
    function EffectCount(const Target: string): Integer;
  end;

  TGovHost = class(TPraxoAgentHost)
  private
    FTool: string;
    FTarget: string;
    FCalls: Integer;
    FState: TGovState;
  public
    constructor Create(const Tool, Target: string; State: TGovState);
    function Generate(Messages: TJSONArray): TJSONObject; override;
    function Invoke(const Name: UTF8String; Arguments: TJSONObject): TJSONData; override;
    procedure Emit(const EventType: UTF8String); override;
  end;

  TChildConfig = record
    Allowed: TPraxoAgentStringArray;
    PolicyKind: Integer;
    Depth: Integer;
    MaxDepth: Integer;
    MaxChildren: Integer;
    UseBudget: Boolean;
    UseChildren: Boolean;
    Cancelled: Boolean;
    EditToBlocked: Boolean;
  end;

var
  GPolicyKind: Integer = 0;
  GCurrentHost: TGovHost = nil;
  GCurrentOptions: TPraxoAgentOptions;

constructor TGovState.Create;
begin
  inherited Create;
  Effects := TStringList.Create;
  Effects.NameValueSeparator := '=';
  Budget := 0;
  Children := 0;
end;

destructor TGovState.Destroy;
begin
  Effects.Free;
  inherited Destroy;
end;

procedure TGovState.IncEffect(const Target: string);
begin
  Effects.Values[Target] := IntToStr(StrToIntDef(Effects.Values[Target], 0) + 1);
end;

function TGovState.EffectCount(const Target: string): Integer;
begin
  Result := StrToIntDef(Effects.Values[Target], 0);
end;

constructor TGovHost.Create(const Tool, Target: string; State: TGovState);
begin
  inherited Create;
  FTool := Tool;
  FTarget := Target;
  FCalls := 0;
  FState := State;
end;

function ToolCallObject(const Name, Target: string): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('id', 'call-1');
  Result.Add('name', Name);
  Result.Add('arguments', TJSONObject.Create(['target', Target]));
end;

function TGovHost.Generate(Messages: TJSONArray): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('inputTokens', Int64(0));
  Result.Add('outputTokens', Int64(0));
  Inc(FCalls);
  if FCalls = 1 then
  begin
    Result.Add('content', '');
    Result.Add('toolCalls', TJSONArray.Create([ToolCallObject(FTool, FTarget)]));
  end
  else
    Result.Add('content', 'done');
end;

function TGovHost.Invoke(const Name: UTF8String; Arguments: TJSONObject): TJSONData;
var
  Target: string;
begin
  Target := '';
  if (Arguments <> nil) and (Arguments.Find('target') <> nil) then
    Target := Arguments.Find('target').AsString;
  if (Name = 'record') or (Name = 'write') then
  begin
    FState.IncEffect(Target);
    Exit(TJSONString.Create('ok'));
  end;
  raise EPraxoAgent.CreateCode('TOOL_NOT_FOUND', 'unknown tool: ' + Name);
end;

procedure TGovHost.Emit(const EventType: UTF8String);
begin
end;

function Authorize(const Kind, ToolName: UTF8String;
  Arguments: TJSONObject): Boolean;
var
  Target: string;
begin
  if Kind = 'model.generate' then Exit(True);
  if Kind <> 'tool.invoke' then Exit(False);
  Target := '';
  if (Arguments <> nil) and (Arguments.Find('target') <> nil) then
    Target := Arguments.Find('target').AsString;
  if GPolicyKind = 0 then
    Exit(ToolName = 'record');
  if GPolicyKind = 1 then
  begin
    if ToolName <> 'record' then Exit(False);
    Exit(Target <> 'blocked');
  end;
  if GPolicyKind = 2 then
  begin
    if ToolName = 'delegate' then Exit(True);
    if ToolName = 'record' then Exit(Target <> 'blocked');
  end;
  Result := False;
end;

function EditDecision(const Interrupt: TPraxoAgentInterrupt): TPraxoAgentDecision;
begin
  Result.Action := PraxoInterruptEdit;
  Result.HasArguments := True;
  Result.Arguments := TJSONObject.Create(['target', 'blocked']);
  Result.Response := '';
  Result.Reason := '';
end;

function SubagentRunnerFn(const Request: TPraxoSubagentRequest):
  TPraxoSubagentResult;
var
  Run: TPraxoAgentResult;
begin
  Run := PraxoRunAgentSession(GCurrentHost, nil, 'run child', GCurrentOptions);
  Result.TaskId := 'child';
  Result.AgentId := 'child';
  Result.Output := Run.Output;
end;

function DeniedTask(const Status, Code: string): TPraxoSubagentTask;
begin
  Result.Id := 'subagent';
  Result.ParentSessionId := 'governance-parent';
  Result.AgentId := 'governance-child';
  Result.Mode := 'isolated';
  Result.Status := Status;
  Result.Output := '';
  Result.Error := Code;
  Result.CreatedAt := '';
  Result.UpdatedAt := '';
end;

function RunChild(State: TGovState; const Tool, Target: string;
  const Config: TChildConfig): TPraxoSubagentTask;
var
  Host: TGovHost;
  Options: TPraxoAgentOptions;
  Manager: TPraxoSubagentManager;
  Request: TPraxoSubagentRequest;
begin
  if Config.Cancelled then Exit(DeniedTask('cancelled', 'CANCELLED'));
  if (Config.MaxDepth >= 0) and (Config.Depth > Config.MaxDepth) then
    Exit(DeniedTask('denied', 'DEPTH_LIMIT'));
  if (Config.MaxChildren >= 0) and (State.Children >= Config.MaxChildren) then
    Exit(DeniedTask('denied', 'CHILD_LIMIT'));
  if Config.UseBudget and (State.Budget <= 0) then
    Exit(DeniedTask('denied', 'BUDGET_EXHAUSTED'));
  if Config.UseChildren then Inc(State.Children);

  Host := TGovHost.Create(Tool, Target, State);
  Options := PraxoAgentOptionsNew;
  Options.MaxSteps := 3;
  Options.RequirePolicy := True;
  Options.Authorize := @Authorize;
  Options.RequireToolScope := True;
  Options.AllowedTools := Config.Allowed;
  Options.SessionId := 'governance-child';
  if Config.EditToBlocked then
  begin
    SetLength(Options.InterruptOn, 1);
    Options.InterruptOn[0] := 'record';
    Options.OnInterruptDecision := @EditDecision;
  end;
  GPolicyKind := Config.PolicyKind;
  GCurrentHost := Host;
  GCurrentOptions := Options;
  Manager := TPraxoSubagentManager.Create;
  try
    Manager.Runner := @SubagentRunnerFn;
    Request.ParentSessionId := 'governance-parent';
    Request.AgentId := 'governance-child';
    Request.Prompt := 'run child';
    Request.Mode := 'isolated';
    Result := Manager.Run(Request);
  finally
    Manager.Free;
  end;
  if Config.UseBudget and (Result.Status = 'completed') then
    Dec(State.Budget);
end;

procedure RunCase(State: TGovState; const Tool, Target: string;
  const Config: TChildConfig; const ExpectedStatus, ExpectedError: string);
var
  Task: TPraxoSubagentTask;
begin
  Task := RunChild(State, Tool, Target, Config);
  if Task.Status <> ExpectedStatus then
    raise Exception.CreateFmt('status %s expected %s', [Task.Status, ExpectedStatus]);
  if (ExpectedError <> '') and (Task.Error <> ExpectedError) then
    raise Exception.CreateFmt('error %s expected %s', [Task.Error, ExpectedError]);
end;

var
  State: TGovState;
  Config: TChildConfig;

begin
  State := TGovState.Create;
  try
    Config.Allowed := nil;
    SetLength(Config.Allowed, 1);
    Config.Allowed[0] := 'record';
    Config.PolicyKind := 0;
    Config.Depth := 0;
    Config.MaxDepth := -1;
    Config.MaxChildren := -1;
    Config.UseBudget := False;
    Config.UseChildren := False;
    Config.Cancelled := False;
    Config.EditToBlocked := False;

    RunCase(State, 'write', 'escape', Config, 'failed', '');
    if State.EffectCount('escape') <> 0 then Halt(1);

    Config.PolicyKind := 2;
    RunCase(State, 'record', 'blocked', Config, 'failed', '');
    if State.EffectCount('blocked') <> 0 then Halt(1);

    Config.PolicyKind := 0;
    Config.UseBudget := True;
    State.Budget := 1;
    RunCase(State, 'record', 'sibling', Config, 'completed', '');
    RunCase(State, 'record', 'sibling', Config, 'denied', 'BUDGET_EXHAUSTED');
    if State.EffectCount('sibling') <> 1 then Halt(1);

    Config.UseBudget := False;
    Config.UseChildren := True;
    Config.MaxChildren := 1;
    State.Children := 0;
    RunCase(State, 'record', 'limit', Config, 'completed', '');
    RunCase(State, 'record', 'limit', Config, 'denied', 'CHILD_LIMIT');

    Config.UseChildren := False;
    Config.MaxChildren := -1;
    Config.Depth := 2;
    Config.MaxDepth := 1;
    RunCase(State, 'record', 'limit', Config, 'denied', 'DEPTH_LIMIT');
    if State.EffectCount('limit') <> 1 then Halt(1);

    Config.Depth := 0;
    Config.MaxDepth := -1;
    Config.Cancelled := True;
    RunCase(State, 'record', 'cancel', Config, 'cancelled', 'CANCELLED');
    if State.EffectCount('cancel') <> 0 then Halt(1);

    Config.Cancelled := False;
    Config.PolicyKind := 1;
    Config.EditToBlocked := True;
    RunCase(State, 'record', 'edit-me', Config, 'failed', '');
    if State.EffectCount('edit-me') <> 0 then Halt(1);
    if State.EffectCount('blocked') <> 0 then Halt(1);

    WriteLn('Delphi advanced delegation governance: 6/6 passed');
  finally
    State.Free;
  end;
end.
