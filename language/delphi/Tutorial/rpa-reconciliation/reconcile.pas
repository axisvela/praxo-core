program rpa_reconciliation;

{$mode objfpc}{$H+}

uses SysUtils, fpjson, praxo_agent;

type
  TReconcileHost = class(TPraxoAgentHost)
  private
    FBatch: UTF8String;
    FSimulateFailure: Boolean;
    FReads: Integer;
    FDrafts: Integer;
  public
    constructor Create(const Batch: UTF8String; SimulateFailure: Boolean);
    function Generate(Messages: TJSONArray): TJSONObject; override;
    function Invoke(const Name: UTF8String; Arguments: TJSONObject): TJSONData; override;
    procedure Emit(const EventType: UTF8String); override;
    property Reads: Integer read FReads;
    property Drafts: Integer read FDrafts;
  end;

function Authorize(const Kind: UTF8String): Boolean;
begin
  Result := (Kind = 'model.generate') or (Kind = 'tool.invoke');
end;

function BuildReport(const FirstContent, LastContent: UTF8String): UTF8String;
var
  Records, ExceptionData: TJSONData;
  Report: TJSONObject;
begin
  Records := GetJSON(FirstContent);
  ExceptionData := GetJSON(LastContent);
  Report := TJSONObject.Create;
  Report.Add('stage', 'exception_drafted');
  Report.Add('records', Records);
  Report.Add('exception', ExceptionData);
  Report.Add('postings', Int64(0));
  Result := Report.AsJSON;
  Report.Free;
end;

constructor TReconcileHost.Create(const Batch: UTF8String;
  SimulateFailure: Boolean);
begin
  inherited Create;
  FBatch := Batch;
  FSimulateFailure := SimulateFailure;
  FReads := 0;
  FDrafts := 0;
end;

function TReconcileHost.Generate(Messages: TJSONArray): TJSONObject;
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
    Args.Add('batch', FBatch);
    Call := TJSONObject.Create;
    Call.Add('id', 'records-1');
    Call.Add('name', 'read_records');
    Call.Add('arguments', Args);
    Calls := TJSONArray.Create;
    Calls.Add(Call);
    Response.Add('content', '');
    Response.Add('toolCalls', Calls);
  end
  else if ToolCount = 1 then
  begin
    Args := TJSONObject.Create;
    Args.Add('batch', FBatch);
    Args.Add('action', 'escalate');
    Call := TJSONObject.Create;
    Call.Add('id', 'exception-1');
    Call.Add('name', 'draft_exception');
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

function TReconcileHost.Invoke(const Name: UTF8String;
  Arguments: TJSONObject): TJSONData;
var
  Batch, Action: UTF8String;
  Item: TJSONObject;
begin
  Batch := Arguments.Get('batch', '');
  if Name = 'read_records' then
  begin
    if Batch <> 'batch-100' then
      raise EPraxoAgent.CreateCode('AGENT_POLICY_DENIED',
        'only batch-100 is in reconciliation scope');
    Inc(FReads);
    if FSimulateFailure then
      raise EPraxoAgent.CreateCode('RECORD_SOURCE_UNAVAILABLE',
        'synthetic record source unavailable');
    Item := TJSONObject.Create;
    Item.Add('batch', 'batch-100');
    Item.Add('purchase_order', 'po-100');
    Item.Add('invoice', 'invoice-100');
    Item.Add('po_amount', Int64(1200));
    Item.Add('invoice_amount', Int64(1250));
    Item.Add('delta', Int64(50));
    Item.Add('threshold', Int64(25));
    Item.Add('source', 'record_fixture');
    Result := Item;
  end
  else if Name = 'draft_exception' then
  begin
    if Batch <> 'batch-100' then
      raise EPraxoAgent.CreateCode('AGENT_POLICY_DENIED',
        'only batch-100 is in reconciliation scope');
    Action := Arguments.Get('action', '');
    if Action <> 'escalate' then
      raise EPraxoAgent.CreateCode('AGENT_POLICY_DENIED',
        'only an escalate action is allowed');
    Inc(FDrafts);
    Item := TJSONObject.Create;
    Item.Add('exception_id', 'exception-100');
    Item.Add('batch', Batch);
    Item.Add('action', Action);
    Item.Add('status', 'draft_only');
    Item.Add('review_required', True);
    Item.Add('postings', Int64(0));
    Result := Item;
  end
  else
    raise EPraxoAgent.CreateCode('TOOL_NOT_FOUND', 'unknown tool: ' + Name);
end;

procedure TReconcileHost.Emit(const EventType: UTF8String);
begin
end;

procedure RunCase(const Batch: UTF8String; SimulateFailure: Boolean;
  out Output, Code: UTF8String; out Reads, Drafts: Integer);
var
  Host: TReconcileHost;
  Allowed: TPraxoAgentStringArray;
  Result: TPraxoAgentResult;
begin
  Host := TReconcileHost.Create(Batch, SimulateFailure);
  try
    SetLength(Allowed, 2);
    Allowed[0] := 'read_records';
    Allowed[1] := 'draft_exception';
    Code := '';
    Output := '';
    try
      Result := PraxoRunAgent(Host,
        'Reconcile the fixed batch and draft a review-only exception.',
        4, 0, True, @Authorize, True, Allowed);
      Output := Result.Output;
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
  Report, Records, ExceptionData: TJSONData;
  ObjectValue: TJSONObject;
begin
  RunCase('batch-100', False, Output, Code, Reads, Drafts);
  if (Code <> '') or (Reads <> 1) or (Drafts <> 1) then
  begin
    WriteLn(StdErr, 'success failed: reads=', Reads, ' drafts=', Drafts,
      ' code=', Code);
    Halt(1);
  end;
  Report := GetJSON(Output);
  ObjectValue := TJSONObject(Report);
  Records := ObjectValue.Find('records');
  ExceptionData := ObjectValue.Find('exception');
  if (ObjectValue.Get('stage', '') <> 'exception_drafted') or
     (TJSONObject(Records).Get('delta', 0) <> 50) or
     (TJSONObject(ExceptionData).Get('status', '') <> 'draft_only') or
     (ObjectValue.Get('postings', -1) <> 0) then
  begin
    WriteLn(StdErr, 'unexpected report: ', Output);
    Halt(1);
  end;
  Report.Free;
  WriteLn('success: batch-100 delta=50 status=draft_only postings=0 reads=1');

  RunCase('batch-200', False, Output, Code, Reads, Drafts);
  if (Code <> 'AGENT_POLICY_DENIED') or (Reads <> 0) or (Drafts <> 0) then
  begin
    WriteLn(StdErr, 'deny failed: reads=', Reads, ' drafts=', Drafts,
      ' code=', Code);
    Halt(1);
  end;
  WriteLn('deny: AGENT_POLICY_DENIED reads=0');

  RunCase('batch-100', True, Output, Code, Reads, Drafts);
  if (Code <> 'RECORD_SOURCE_UNAVAILABLE') or (Reads <> 1) or (Drafts <> 0) then
  begin
    WriteLn(StdErr, 'failure failed: reads=', Reads, ' drafts=', Drafts,
      ' code=', Code);
    Halt(1);
  end;
  WriteLn('failure: RECORD_SOURCE_UNAVAILABLE reads=1');
end;

var
  Repo: UTF8String;
  Output, Code: UTF8String;
  Reads, Drafts, Index: Integer;
  SimulateFailure, TestMode: Boolean;
  Current: UTF8String;

begin
  Repo := 'batch-100';
  SimulateFailure := False;
  TestMode := False;
  for Index := 1 to ParamCount do
  begin
    Current := ParamStr(Index);
    if Current = '--test' then TestMode := True
    else if Current = '--simulate-failure' then SimulateFailure := True
    else if Current = '--batch' then
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
    WriteLn(StdErr, 'reconciliation failed: reads=', Reads, ' drafts=',
      Drafts, '; ', Code);
    Halt(1);
  end;
  WriteLn(Output);
end.
