program tax_review;

{$mode objfpc}{$H+}

uses SysUtils, fpjson, praxo_agent;

type
  TTaxHost = class(TPraxoAgentHost)
  private
    FReturn: UTF8String;
    FSimulateFailure: Boolean;
    FReads: Integer;
    FDrafts: Integer;
  public
    constructor Create(const ReturnId: UTF8String; SimulateFailure: Boolean);
    function Generate(Messages: TJSONArray): TJSONObject; override;
    function Invoke(const Name: UTF8String; Arguments: TJSONObject): TJSONData; override;
    procedure Emit(const EventType: UTF8String); override;
    property Reads: Integer read FReads;
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
  Ledger, Filing: TJSONData;
  Report: TJSONObject;
begin
  Ledger := GetJSON(FirstContent);
  Filing := GetJSON(LastContent);
  Report := TJSONObject.Create;
  Report.Add('stage', 'tax_filing_drafted');
  Report.Add('ledger', Ledger);
  Report.Add('filing', Filing);
  Report.Add('submissions', Int64(0));
  Result := Report.AsJSON;
  Report.Free;
end;

constructor TTaxHost.Create(const ReturnId: UTF8String; SimulateFailure: Boolean);
begin
  inherited Create;
  FReturn := ReturnId;
  FSimulateFailure := SimulateFailure;
  FReads := 0;
  FDrafts := 0;
end;

function TTaxHost.Generate(Messages: TJSONArray): TJSONObject;
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
    Args.Add('return_id', FReturn);
    Call := TJSONObject.Create;
    Call.Add('id', 'ledger-1');
    Call.Add('name', 'read_ledger');
    Call.Add('arguments', Args);
    Calls := TJSONArray.Create;
    Calls.Add(Call);
    Response.Add('content', '');
    Response.Add('toolCalls', Calls);
  end
  else if ToolCount = 1 then
  begin
    Args := TJSONObject.Create;
    Args.Add('return_id', FReturn);
    Args.Add('action', 'draft_filing');
    Call := TJSONObject.Create;
    Call.Add('id', 'filing-1');
    Call.Add('name', 'draft_filing');
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

function TTaxHost.Invoke(const Name: UTF8String; Arguments: TJSONObject): TJSONData;
var
  ReturnId, Action: UTF8String;
  Item: TJSONObject;
  Taxable: Int64;
begin
  ReturnId := Arguments.Get('return_id', '');
  if ReturnId <> 'return-100' then
    raise EPraxoAgent.CreateCode('AGENT_POLICY_DENIED', 'only return-100 is in scope');
  if Name = 'read_ledger' then
  begin
    Inc(FReads);
    if FSimulateFailure then
      raise EPraxoAgent.CreateCode('LEDGER_UNAVAILABLE', 'synthetic ledger unavailable');
    Taxable := 100000 - 15000;
    Item := TJSONObject.Create;
    Item.Add('return_id', 'return-100');
    Item.Add('revenue', Int64(100000));
    Item.Add('deductions', Int64(15000));
    Item.Add('taxable', Taxable);
    Item.Add('rate_percent', Int64(20));
    Item.Add('tax_due', Int64(17000));
    Item.Add('source', 'tax_fixture');
    Result := Item;
  end
  else if Name = 'draft_filing' then
  begin
    Action := Arguments.Get('action', '');
    if Action <> 'draft_filing' then
      raise EPraxoAgent.CreateCode('AGENT_POLICY_DENIED', 'only draft_filing is allowed');
    Inc(FDrafts);
    Item := TJSONObject.Create;
    Item.Add('filing_id', 'filing-100');
    Item.Add('return_id', ReturnId);
    Item.Add('action', Action);
    Item.Add('status', 'draft_only');
    Item.Add('review_required', True);
    Item.Add('submissions', Int64(0));
    Result := Item;
  end
  else
    raise EPraxoAgent.CreateCode('TOOL_NOT_FOUND', 'unknown tool: ' + Name);
end;

procedure TTaxHost.Emit(const EventType: UTF8String);
begin
end;

procedure RunCase(const ReturnId: UTF8String; SimulateFailure: Boolean;
  out Output, Code: UTF8String; out Reads, Drafts: Integer);
var
  Host: TTaxHost;
  Allowed: TPraxoAgentStringArray;
  RunResult: TPraxoAgentResult;
begin
  Host := TTaxHost.Create(ReturnId, SimulateFailure);
  try
    SetLength(Allowed, 2);
    Allowed[0] := 'read_ledger';
    Allowed[1] := 'draft_filing';
    Code := '';
    Output := '';
    try
      RunResult := PraxoRunAgent(Host,
        'Read the fixed ledger and draft a review-only tax filing.',
        4, 0, True, @Authorize, True, Allowed);
      Output := RunResult.Output;
    except
      on E: EPraxoAgent do Code := E.Code;
    end;
    Reads := Host.Reads;
    Drafts := Host.Drafts;
  finally
    Host.Free;
  end;
end;

procedure RunTests;
var
  Output, Code: UTF8String;
  Reads, Drafts: Integer;
  Report, Ledger, Filing: TJSONData;
  ObjectValue: TJSONObject;
begin
  RunCase('return-100', False, Output, Code, Reads, Drafts);
  if (Code <> '') or (Reads <> 1) or (Drafts <> 1) then
  begin
    WriteLn(StdErr, 'success failed: reads=', Reads, ' drafts=', Drafts, ' code=', Code);
    Halt(1);
  end;
  Report := GetJSON(Output);
  ObjectValue := TJSONObject(Report);
  Ledger := ObjectValue.Find('ledger');
  Filing := ObjectValue.Find('filing');
  if (ObjectValue.Get('stage', '') <> 'tax_filing_drafted') or
     (TJSONObject(Ledger).Get('taxable', -1) <> 85000) or
     (TJSONObject(Ledger).Get('tax_due', -1) <> 17000) or
     (TJSONObject(Filing).Get('status', '') <> 'draft_only') or
     (ObjectValue.Get('submissions', -1) <> 0) then
  begin
    WriteLn(StdErr, 'unexpected report: ', Output);
    Halt(1);
  end;
  Report.Free;
  WriteLn('success: return-100 taxable=85000 tax_due=17000 status=draft_only submissions=0 reads=1');

  RunCase('return-200', False, Output, Code, Reads, Drafts);
  if (Code <> 'AGENT_POLICY_DENIED') or (Reads <> 0) or (Drafts <> 0) then
  begin
    WriteLn(StdErr, 'deny failed: reads=', Reads, ' drafts=', Drafts, ' code=', Code);
    Halt(1);
  end;
  WriteLn('deny: AGENT_POLICY_DENIED reads=0');

  RunCase('return-100', True, Output, Code, Reads, Drafts);
  if (Code <> 'LEDGER_UNAVAILABLE') or (Reads <> 1) or (Drafts <> 0) then
  begin
    WriteLn(StdErr, 'failure failed: reads=', Reads, ' drafts=', Drafts, ' code=', Code);
    Halt(1);
  end;
  WriteLn('failure: LEDGER_UNAVAILABLE reads=1');
end;

var
  Arguments: array of UTF8String;
  ReturnId, Output, Code, Current: UTF8String;
  Reads, Drafts, Index: Integer;
  SimulateFailure, TestMode: Boolean;

begin
  ReturnId := 'return-100';
  SimulateFailure := False;
  TestMode := False;
  SetLength(Arguments, ParamCount);
  for Index := 1 to ParamCount do
  begin
    Current := ParamStr(Index);
    Arguments[Index - 1] := Current;
    if Current = '--test' then TestMode := True
    else if Current = '--simulate-failure' then SimulateFailure := True
    else if Current = '--return' then
    begin
      if Index < ParamCount then ReturnId := ParamStr(Index + 1);
    end;
  end;

  if TestMode then
  begin
    RunTests;
    Halt(0);
  end;

  RunCase(ReturnId, SimulateFailure, Output, Code, Reads, Drafts);
  if Code <> '' then
  begin
    WriteLn(StdErr, 'tax review failed: reads=', Reads, ' drafts=', Drafts, '; ', Code);
    Halt(1);
  end;
  WriteLn(Output);
end.
