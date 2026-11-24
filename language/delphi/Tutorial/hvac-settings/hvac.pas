program hvac_settings;

{$mode objfpc}{$H+}

uses SysUtils, fpjson, praxo_agent;

type
  THvacHost = class(TPraxoAgentHost)
  private
    FBuilding: UTF8String;
    FSimulateFailure: Boolean;
    FInvocations: Integer;
    FDrafts: Integer;
  public
    constructor Create(const Building: UTF8String; SimulateFailure: Boolean);
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
  Environment, Settings: TJSONData;
  Report: TJSONObject;
begin
  Environment := GetJSON(FirstContent);
  Settings := GetJSON(LastContent);
  Report := TJSONObject.Create;
  Report.Add('stage', 'hvac_settings_drafted');
  Report.Add('environment', Environment);
  Report.Add('settings', Settings);
  Report.Add('bms_commands', Int64(0));
  Report.Add('energy_claims', Int64(0));
  Result := Report.AsJSON;
  Report.Free;
end;

constructor THvacHost.Create(const Building: UTF8String;
  SimulateFailure: Boolean);
begin
  inherited Create;
  FBuilding := Building;
  FSimulateFailure := SimulateFailure;
  FInvocations := 0;
  FDrafts := 0;
end;

function THvacHost.Generate(Messages: TJSONArray): TJSONObject;
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
    Args.Add('building', FBuilding);
    Call := TJSONObject.Create;
    Call.Add('id', 'environment-1');
    Call.Add('name', 'read_environment');
    Call.Add('arguments', Args);
    Calls := TJSONArray.Create;
    Calls.Add(Call);
    Response.Add('content', '');
    Response.Add('toolCalls', Calls);
  end
  else if ToolCount = 1 then
  begin
    Args := TJSONObject.Create;
    Args.Add('building', FBuilding);
    Args.Add('action', 'draft_settings');
    Call := TJSONObject.Create;
    Call.Add('id', 'settings-1');
    Call.Add('name', 'draft_settings');
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

function THvacHost.Invoke(const Name: UTF8String;
  Arguments: TJSONObject): TJSONData;
var
  Building, Action: UTF8String;
  Item: TJSONObject;
begin
  Building := Arguments.Get('building', '');
  if Name = 'read_environment' then
  begin
    if Building <> 'building-100' then
      raise EPraxoAgent.CreateCode('AGENT_POLICY_DENIED',
        'only building-100 is in scope');
    Inc(FInvocations);
    if FSimulateFailure then
      raise EPraxoAgent.CreateCode('ENVIRONMENT_UNAVAILABLE',
        'synthetic building environment unavailable');
    Item := TJSONObject.Create;
    Item.Add('building', 'building-100');
    Item.Add('occupancy', Int64(40));
    Item.Add('temp_c', 24.5);
    Item.Add('setpoint_c', 22.0);
    Item.Add('lighting', 'on');
    Item.Add('zones', Int64(3));
    Item.Add('source', 'environment_fixture');
    Result := Item;
  end
  else if Name = 'draft_settings' then
  begin
    if Building <> 'building-100' then
      raise EPraxoAgent.CreateCode('AGENT_POLICY_DENIED',
        'only building-100 is in scope');
    Action := Arguments.Get('action', '');
    if Action <> 'draft_settings' then
      raise EPraxoAgent.CreateCode('AGENT_POLICY_DENIED',
        'only a draft_settings action is allowed');
    Inc(FDrafts);
    Item := TJSONObject.Create;
    Item.Add('settings_id', 'hvac-100');
    Item.Add('building', Building);
    Item.Add('action', Action);
    Item.Add('status', 'draft_only');
    Item.Add('review_required', True);
    Item.Add('bms_commands', Int64(0));
    Item.Add('energy_claims', Int64(0));
    Result := Item;
  end
  else
    raise EPraxoAgent.CreateCode('TOOL_NOT_FOUND', 'unknown tool: ' + Name);
end;

procedure THvacHost.Emit(const EventType: UTF8String);
begin
end;

procedure RunCase(const Building: UTF8String; SimulateFailure: Boolean;
  out Output, Code: UTF8String; out Reads, Drafts: Integer);
var
  Host: THvacHost;
  Allowed: TPraxoAgentStringArray;
  Result: TPraxoAgentResult;
begin
  Host := THvacHost.Create(Building, SimulateFailure);
  try
    SetLength(Allowed, 2);
    Allowed[0] := 'read_environment';
    Allowed[1] := 'draft_settings';
    Code := '';
    Output := '';
    try
      Result := PraxoRunAgent(Host,
        'Read the fixed building environment and draft a review-only settings plan.',
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
  Report, Environment, Settings: TJSONData;
  ObjectValue: TJSONObject;
begin
  RunCase('building-100', False, Output, Code, Reads, Drafts);
  if (Code <> '') or (Reads <> 1) or (Drafts <> 1) then
  begin
    WriteLn(StdErr, 'success failed: reads=', Reads, ' drafts=', Drafts,
      ' code=', Code);
    Halt(1);
  end;
  Report := GetJSON(Output);
  ObjectValue := TJSONObject(Report);
  Environment := ObjectValue.Find('environment');
  Settings := ObjectValue.Find('settings');
  if (ObjectValue.Get('stage', '') <> 'hvac_settings_drafted') or
     (TJSONObject(Environment).Get('occupancy', -1) <> 40) or
     (TJSONObject(Settings).Get('status', '') <> 'draft_only') or
     (ObjectValue.Get('bms_commands', -1) <> 0) or
     (ObjectValue.Get('energy_claims', -1) <> 0) then
  begin
    WriteLn(StdErr, 'unexpected report: ', Output);
    Halt(1);
  end;
  Report.Free;
  WriteLn('success: building-100 occupancy=40 status=draft_only bms_commands=0 reads=1');

  RunCase('building-200', False, Output, Code, Reads, Drafts);
  if (Code <> 'AGENT_POLICY_DENIED') or (Reads <> 0) or (Drafts <> 0) then
  begin
    WriteLn(StdErr, 'deny failed: reads=', Reads, ' drafts=', Drafts,
      ' code=', Code);
    Halt(1);
  end;
  WriteLn('deny: AGENT_POLICY_DENIED reads=0');

  RunCase('building-100', True, Output, Code, Reads, Drafts);
  if (Code <> 'ENVIRONMENT_UNAVAILABLE') or (Reads <> 1) or (Drafts <> 0) then
  begin
    WriteLn(StdErr, 'failure failed: reads=', Reads, ' drafts=', Drafts,
      ' code=', Code);
    Halt(1);
  end;
  WriteLn('failure: ENVIRONMENT_UNAVAILABLE reads=1');
end;

var
  Arguments: array of UTF8String;
  Building, Output, Code, Current: UTF8String;
  Reads, Drafts, Index: Integer;
  SimulateFailure, TestMode: Boolean;

begin
  Building := 'building-100';
  SimulateFailure := False;
  TestMode := False;
  SetLength(Arguments, ParamCount);
  for Index := 1 to ParamCount do
  begin
    Current := ParamStr(Index);
    Arguments[Index - 1] := Current;
    if Current = '--test' then TestMode := True
    else if Current = '--simulate-failure' then SimulateFailure := True
    else if Current = '--building' then
    begin
      if Index < ParamCount then Building := ParamStr(Index + 1);
    end;
  end;

  if TestMode then
  begin
    RunTests;
    Halt(0);
  end;

  RunCase(Building, SimulateFailure, Output, Code, Reads, Drafts);
  if Code <> '' then
  begin
    WriteLn(StdErr, 'hvac settings failed: reads=', Reads, ' drafts=',
      Drafts, '; ', Code);
    Halt(1);
  end;
  WriteLn(Output);
end.
