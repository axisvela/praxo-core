program legacy_migration_inventory;

{$mode objfpc}{$H+}

uses SysUtils, fpjson, praxo_agent;

type
  TInventoryHost = class(TPraxoAgentHost)
  private
    FRepo: UTF8String;
    FSimulateFailure: Boolean;
    FInvocations: Integer;
    FDrafts: Integer;
  public
    constructor Create(const Repo: UTF8String; SimulateFailure: Boolean);
    function Generate(Messages: TJSONArray): TJSONObject; override;
    function Invoke(const Name: UTF8String; Arguments: TJSONObject): TJSONData; override;
    procedure Emit(const EventType: UTF8String); override;
    property Invocations: Integer read FInvocations;
    property Drafts: Integer read FDrafts;
  end;

function Authorize(const Kind: UTF8String): Boolean;
begin
  if Kind = 'model.generate' then Exit(True);
  if Kind = 'tool.invoke' then Exit(True);
  Result := False;
end;

function BuildReport(const FirstContent, LastContent: UTF8String): UTF8String;
var
  Change, Plan: TJSONData;
  Report: TJSONObject;
begin
  Change := GetJSON(FirstContent);
  Plan := GetJSON(LastContent);
  Report := TJSONObject.Create;
  Report.Add('stage', 'migration_drafted');
  Report.Add('change', Change);
  Report.Add('plan', Plan);
  Report.Add('changes_applied', Int64(0));
  Result := Report.AsJSON;
  Report.Free;
end;

constructor TInventoryHost.Create(const Repo: UTF8String;
  SimulateFailure: Boolean);
begin
  inherited Create;
  FRepo := Repo;
  FSimulateFailure := SimulateFailure;
  FInvocations := 0;
  FDrafts := 0;
end;

function TInventoryHost.Generate(Messages: TJSONArray): TJSONObject;
var
  Index, ToolCount: Integer;
  Message, Response, Call, Args: TJSONObject;
  Calls: TJSONArray;
  FirstContent, LastContent: UTF8String;
begin
  ToolCount := 0;
  FirstContent := '';
  LastContent := '';
  for Index := 0 to Messages.Count - 1 do
  begin
    Message := TJSONObject(Messages.Items[Index]);
    if Message.Get('role', '') <> 'tool' then Continue;
    if ToolCount = 0 then FirstContent := Message.Get('content', '');
    LastContent := Message.Get('content', '');
    Inc(ToolCount);
  end;

  Response := TJSONObject.Create;
  Response.Add('inputTokens', Int64(0));
  Response.Add('outputTokens', Int64(0));

  if ToolCount = 0 then
  begin
    Args := TJSONObject.Create;
    Args.Add('repo', FRepo);
    Call := TJSONObject.Create;
    Call.Add('id', 'legacy-1');
    Call.Add('name', 'read_legacy');
    Call.Add('arguments', Args);
    Calls := TJSONArray.Create;
    Calls.Add(Call);
    Response.Add('content', '');
    Response.Add('toolCalls', Calls);
  end
  else if ToolCount = 1 then
  begin
    Args := TJSONObject.Create;
    Args.Add('repo', FRepo);
    Args.Add('action', 'draft_plan');
    Call := TJSONObject.Create;
    Call.Add('id', 'plan-1');
    Call.Add('name', 'draft_migration');
    Call.Add('arguments', Args);
    Calls := TJSONArray.Create;
    Calls.Add(Call);
    Response.Add('content', '');
    Response.Add('toolCalls', Calls);
  end
  else
    Response.Add('content', BuildReport(FirstContent, LastContent));

  Result := Response;
end;

function TInventoryHost.Invoke(const Name: UTF8String;
  Arguments: TJSONObject): TJSONData;
var
  Repo, Action: UTF8String;
  Item: TJSONObject;
  Values: TJSONArray;
begin
  Repo := Arguments.Get('repo', '');
  if Name = 'read_legacy' then
  begin
    if Repo <> 'repo-100' then
      raise EPraxoAgent.CreateCode('AGENT_POLICY_DENIED',
        'only repo-100 is in migration scope');
    Inc(FInvocations);
    if FSimulateFailure then
      raise EPraxoAgent.CreateCode('LEGACY_SOURCE_UNAVAILABLE',
        'synthetic legacy inventory unavailable');
    Item := TJSONObject.Create;
    Item.Add('repo', 'repo-100');
    Values := TJSONArray.Create;
    Values.Add('billing');
    Values.Add('ledger');
    Values.Add('batch');
    Item.Add('modules', Values);
    Values := TJSONArray.Create;
    Values.Add('billing->ledger');
    Item.Add('dependencies', Values);
    Values := TJSONArray.Create;
    Values.Add('inventory');
    Values.Add('interface draft');
    Item.Add('migration_steps', Values);
    Item.Add('source', 'legacy_fixture');
    Result := Item;
  end
  else if Name = 'draft_migration' then
  begin
    if Repo <> 'repo-100' then
      raise EPraxoAgent.CreateCode('AGENT_POLICY_DENIED',
        'only repo-100 is in migration scope');
    Action := Arguments.Get('action', '');
    if Action <> 'draft_plan' then
      raise EPraxoAgent.CreateCode('AGENT_POLICY_DENIED',
        'only a draft_plan action is allowed');
    Inc(FDrafts);
    Item := TJSONObject.Create;
    Item.Add('plan_id', 'migration-100');
    Item.Add('repo', Repo);
    Item.Add('action', Action);
    Item.Add('status', 'draft_only');
    Item.Add('review_required', True);
    Item.Add('changes_applied', Int64(0));
    Result := Item;
  end
  else
    raise EPraxoAgent.CreateCode('TOOL_NOT_FOUND', 'unknown tool: ' + Name);
end;

procedure TInventoryHost.Emit(const EventType: UTF8String);
begin
end;

procedure RunCase(const Repo: UTF8String; SimulateFailure: Boolean;
  out Output, Code: UTF8String; out Reads, Drafts: Integer);
var
  Host: TInventoryHost;
  Allowed: TPraxoAgentStringArray;
  Result: TPraxoAgentResult;
begin
  Host := TInventoryHost.Create(Repo, SimulateFailure);
  try
    SetLength(Allowed, 2);
    Allowed[0] := 'read_legacy';
    Allowed[1] := 'draft_migration';
    Code := '';
    Output := '';
    try
      Result := PraxoRunAgent(Host,
        'Inventory the fixed legacy modules and draft a review-only migration plan.',
        4, 0, True, @Authorize, True, Allowed);
      Output := Result.Output;
    except
      on E: EPraxoAgent do Code := E.Code;
    end;
    Reads := Host.Invocations;
    Drafts := Host.Drafts;
  finally
    Host.Free;
  end;
end;

procedure RunTests;
var
  Output, Code: UTF8String;
  Reads, Drafts: Integer;
  Report, Change, Plan: TJSONData;
  ObjectValue: TJSONObject;
begin
  RunCase('repo-100', False, Output, Code, Reads, Drafts);
  if (Code <> '') or (Reads <> 1) or (Drafts <> 1) then
  begin
    WriteLn(StdErr, 'success failed: reads=', Reads, ' drafts=', Drafts,
      ' code=', Code);
    Halt(1);
  end;
  Report := GetJSON(Output);
  ObjectValue := TJSONObject(Report);
  Change := ObjectValue.Find('change');
  Plan := ObjectValue.Find('plan');
  if (ObjectValue.Get('stage', '') <> 'migration_drafted') or
     (TJSONObject(Change).Get('repo', '') <> 'repo-100') or
     (TJSONArray(TJSONObject(Change).Find('modules')).Count <> 3) or
     (TJSONObject(Plan).Get('status', '') <> 'draft_only') or
     (ObjectValue.Get('changes_applied', -1) <> 0) then
  begin
    WriteLn(StdErr, 'unexpected report: ', Output);
    Halt(1);
  end;
  Report.Free;
  WriteLn('success: repo-100 modules=3 status=draft_only changes_applied=0 reads=1');

  RunCase('repo-200', False, Output, Code, Reads, Drafts);
  if (Code <> 'AGENT_POLICY_DENIED') or (Reads <> 0) or (Drafts <> 0) then
  begin
    WriteLn(StdErr, 'deny failed: reads=', Reads, ' drafts=', Drafts,
      ' code=', Code);
    Halt(1);
  end;
  WriteLn('deny: AGENT_POLICY_DENIED reads=0');

  RunCase('repo-100', True, Output, Code, Reads, Drafts);
  if (Code <> 'LEGACY_SOURCE_UNAVAILABLE') or (Reads <> 1) or (Drafts <> 0) then
  begin
    WriteLn(StdErr, 'failure failed: reads=', Reads, ' drafts=', Drafts,
      ' code=', Code);
    Halt(1);
  end;
  WriteLn('failure: LEGACY_SOURCE_UNAVAILABLE reads=1');
end;

var
  Arguments: array of UTF8String;
  Repo, Output, Code, Current: UTF8String;
  Reads, Drafts, Index: Integer;
  SimulateFailure, TestMode: Boolean;

begin
  Repo := 'repo-100';
  SimulateFailure := False;
  TestMode := False;
  SetLength(Arguments, ParamCount);
  for Index := 1 to ParamCount do
  begin
    Current := ParamStr(Index);
    Arguments[Index - 1] := Current;
    if Current = '--test' then TestMode := True
    else if Current = '--simulate-failure' then SimulateFailure := True
    else if Current = '--repo' then
    begin
      if Index < ParamCount then Repo := ParamStr(Index + 1);
    end;
  end;

  if TestMode then
  begin
    RunTests;
    Halt(0);
  end;

  RunCase(Repo, SimulateFailure, Output, Code, Reads, Drafts);
  if Code <> '' then
  begin
    WriteLn(StdErr, 'legacy migration failed: reads=', Reads, ' drafts=',
      Drafts, '; ', Code);
    Halt(1);
  end;
  WriteLn(Output);
end.
