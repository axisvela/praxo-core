program hitl_tests;
{$mode objfpc}{$H+}

uses SysUtils, fpjson, praxo, praxo_agent;

type
  THitlHost = class(TPraxoAgentHost)
  public
    Script: TJSONArray;
    Events: TJSONArray;
    NextCall: Integer;
    Invocations: Integer;
    LastValue: UTF8String;
    constructor Create;
    destructor Destroy; override;
    function Generate(Messages: TJSONArray): TJSONObject; override;
    function Invoke(const Name: UTF8String; Arguments: TJSONObject): TJSONData; override;
    procedure Emit(const EventType: UTF8String); override;
    procedure EmitEvent(const EventType: UTF8String; Data: TJSONObject); override;
  end;

var
  DecisionAction: UTF8String = '';
  DecisionHasArgs: Boolean = False;
  DecisionArgs: TJSONObject = nil;
  DecisionResponse: UTF8String = '';
  DecisionReason: UTF8String = '';
  AuthValues: array of UTF8String;
  DenyEdited: Boolean = False;
  ApprovalResult: Boolean = True;

constructor THitlHost.Create;
begin
  inherited Create;
  Events := TJSONArray.Create;
end;

destructor THitlHost.Destroy;
begin
  Events.Free;
  inherited Destroy;
end;

function THitlHost.Generate(Messages: TJSONArray): TJSONObject;
begin
  if NextCall >= Script.Count then raise Exception.Create('script exhausted');
  Result := TJSONObject(Script.Items[NextCall].Clone);
  Inc(NextCall);
end;

function THitlHost.Invoke(const Name: UTF8String; Arguments: TJSONObject): TJSONData;
var V: TJSONData;
begin
  Inc(Invocations);
  V := Arguments.Find('value');
  if (V <> nil) and (V.JSONType = jtString) then LastValue := V.AsString else LastValue := '';
  Result := Arguments.Clone;
end;

procedure THitlHost.Emit(const EventType: UTF8String);
begin
  Events.Add(EventType);
end;

procedure THitlHost.EmitEvent(const EventType: UTF8String; Data: TJSONObject);
begin
  Events.Add(EventType);
end;

function Decide(const Interrupt: TPraxoAgentInterrupt): TPraxoAgentDecision;
begin
  Result.Action := DecisionAction;
  Result.HasArguments := DecisionHasArgs;
  Result.Arguments := DecisionArgs;
  Result.Response := DecisionResponse;
  Result.Reason := DecisionReason;
end;

function Approve(const Interrupt: TPraxoAgentInterrupt): Boolean;
begin
  Result := ApprovalResult;
end;

procedure RecordAuth(const Value: UTF8String);
begin
  SetLength(AuthValues, Length(AuthValues) + 1);
  AuthValues[High(AuthValues)] := Value;
end;

function Authorize(const Kind, ToolName: UTF8String; Arguments: TJSONObject): Boolean;
var V: TJSONData; Value: UTF8String;
begin
  Result := True;
  if Kind <> 'tool.invoke' then Exit;
  Value := '';
  V := Arguments.Find('value');
  if (V <> nil) and (V.JSONType = jtString) then Value := V.AsString;
  RecordAuth(Value);
  if DenyEdited and (Value = 'edited') then Result := False;
end;

procedure Check(Condition: Boolean; const Detail: UTF8String);
begin
  if not Condition then raise Exception.Create(Detail);
end;

procedure ExpectEvents(Host: THitlHost; const JSONText: UTF8String);
var Expected: TJSONData;
begin
  Expected := PraxoParseJSON(JSONText);
  try
    Check(PraxoJSONEqual(Host.Events, Expected), 'events: ' + Host.Events.FormatJSON);
  finally
    Expected.Free;
  end;
end;

function ScriptText: UTF8String;
begin
  Result := '[{"content":"","toolCalls":[{"id":"call-1","name":"echo","arguments":{"value":"original"}}]},{"content":"final"}]';
end;

function NewOptions(Host: THitlHost; const JSONText: UTF8String): TPraxoAgentOptions;
begin
  Result := PraxoAgentOptionsNew;
  Result.MaxSteps := 2;
  SetLength(Result.InterruptOn, 1);
  Result.InterruptOn[0] := 'echo';
  Host.Script := TJSONArray(PraxoParseJSON(JSONText));
end;

procedure FreeOptions(Host: THitlHost);
begin
  Host.Script.Free;
  Host.Script := nil;
end;

function Run(Host: THitlHost; const Options: TPraxoAgentOptions; out R: TPraxoAgentResult): UTF8String;
begin
  Result := '';
  R.Output := '';
  R.Steps := 0;
  R.InputTokens := 0;
  R.OutputTokens := 0;
  R.Messages := nil;
  try
    R := PraxoRunAgentSession(Host, nil, 'go', Options);
  except
    on E: EPraxoAgent do Result := E.Code;
  end;
end;

procedure ResetDecision;
begin
  DecisionAction := '';
  DecisionHasArgs := False;
  DecisionArgs := nil;
  DecisionResponse := '';
  DecisionReason := '';
end;

procedure TestApprove;
var Host: THitlHost; Options: TPraxoAgentOptions; R: TPraxoAgentResult; Code: UTF8String;
begin
  Host := THitlHost.Create;
  try
    Options := NewOptions(Host, ScriptText);
    ResetDecision;
    DecisionAction := PraxoInterruptApprove;
    Options.OnInterruptDecision := @Decide;
    Code := Run(Host, Options, R);
    try
      Check(Code = '', 'approve code: ' + Code);
      Check(R.Output = 'final', 'approve output');
      Check(Host.Invocations = 1, 'approve invocations');
      Check(Host.LastValue = 'original', 'approve arguments');
      ExpectEvents(Host, '["run.started","tool.interrupt","tool.call","run.completed"]');
    finally
      if R.Messages <> nil then R.Messages.Free;
      FreeOptions(Host);
    end;
  finally
    Host.Free;
  end;
  Writeln('hitl approve passed');
end;

procedure TestEditReauthorizeDenied;
var Host: THitlHost; Options: TPraxoAgentOptions; R: TPraxoAgentResult; Code: UTF8String; EditArgs: TJSONData;
begin
  Host := THitlHost.Create;
  try
    Options := NewOptions(Host, ScriptText);
    ResetDecision;
    SetLength(AuthValues, 0);
    DenyEdited := True;
    EditArgs := PraxoParseJSON('{"value":"edited"}');
    try
      DecisionAction := PraxoInterruptEdit;
      DecisionHasArgs := True;
      DecisionArgs := TJSONObject(EditArgs);
      Options.Authorize := @Authorize;
      Options.OnInterruptDecision := @Decide;
      Code := Run(Host, Options, R);
      try
        Check(Code = 'AGENT_POLICY_DENIED', 'edit code: ' + Code);
        Check(Host.Invocations = 0, 'edit invocations');
        Check(Length(AuthValues) = 2, 'edit authorization count');
        Check(AuthValues[0] = 'original', 'edit original auth');
        Check(AuthValues[1] = 'edited', 'edit reauthorization');
        ExpectEvents(Host, '["run.started","tool.interrupt","run.failed"]');
      finally
        if R.Messages <> nil then R.Messages.Free;
      end;
    finally
      DenyEdited := False;
      EditArgs.Free;
      FreeOptions(Host);
    end;
  finally
    Host.Free;
  end;
  Writeln('hitl edit reauthorization passed');
end;

procedure TestReject;
var Host: THitlHost; Options: TPraxoAgentOptions; R: TPraxoAgentResult; Code: UTF8String;
begin
  Host := THitlHost.Create;
  try
    Options := NewOptions(Host, ScriptText);
    ResetDecision;
    DecisionAction := PraxoInterruptReject;
    DecisionReason := 'not allowed';
    Options.OnInterruptDecision := @Decide;
    Code := Run(Host, Options, R);
    try
      Check(Code = 'AGENT_APPROVAL_DENIED', 'reject code: ' + Code);
      Check(Host.Invocations = 0, 'reject invocations');
      ExpectEvents(Host, '["run.started","tool.interrupt","run.failed"]');
    finally
      if R.Messages <> nil then R.Messages.Free;
      FreeOptions(Host);
    end;
  finally
    Host.Free;
  end;
  Writeln('hitl reject passed');
end;

procedure TestRespond;
var Host: THitlHost; Options: TPraxoAgentOptions; R: TPraxoAgentResult; Code: UTF8String;
begin
  Host := THitlHost.Create;
  try
    Options := NewOptions(Host, '[{"content":"","toolCalls":[{"id":"call-1","name":"echo","arguments":{"value":"original"}}]},{"content":"\"human answer\""}]');
    ResetDecision;
    DecisionAction := PraxoInterruptRespond;
    DecisionResponse := 'human answer';
    Options.OnInterruptDecision := @Decide;
    Code := Run(Host, Options, R);
    try
      Check(Code = '', 'respond code: ' + Code);
      Check(R.Output = '"human answer"', 'respond output: ' + R.Output);
      Check(Host.Invocations = 0, 'respond invocations');
      ExpectEvents(Host, '["run.started","tool.interrupt","run.completed"]');
    finally
      if R.Messages <> nil then R.Messages.Free;
      FreeOptions(Host);
    end;
  finally
    Host.Free;
  end;
  Writeln('hitl respond passed');
end;

procedure TestUnhandled;
var Host: THitlHost; Options: TPraxoAgentOptions; R: TPraxoAgentResult; Code: UTF8String;
begin
  Host := THitlHost.Create;
  try
    Options := NewOptions(Host, ScriptText);
    ResetDecision;
    Code := Run(Host, Options, R);
    try
      Check(Code = 'AGENT_INTERRUPT_UNHANDLED', 'unhandled code: ' + Code);
      Check(Host.Invocations = 0, 'unhandled invocations');
      ExpectEvents(Host, '["run.started","run.failed"]');
    finally
      if R.Messages <> nil then R.Messages.Free;
      FreeOptions(Host);
    end;
  finally
    Host.Free;
  end;
  Writeln('hitl unhandled passed');
end;

procedure TestInvalid;
var Host: THitlHost; Options: TPraxoAgentOptions; R: TPraxoAgentResult; Code: UTF8String;
begin
  Host := THitlHost.Create;
  try
    Options := NewOptions(Host, ScriptText);
    ResetDecision;
    DecisionAction := 'invalid';
    Options.OnInterruptDecision := @Decide;
    Code := Run(Host, Options, R);
    try
      Check(Code = 'AGENT_INTERRUPT_DECISION_INVALID', 'invalid code: ' + Code);
      Check(Host.Invocations = 0, 'invalid invocations');
      ExpectEvents(Host, '["run.started","tool.interrupt","run.failed"]');
    finally
      if R.Messages <> nil then R.Messages.Free;
      FreeOptions(Host);
    end;
  finally
    Host.Free;
  end;
  Writeln('hitl invalid passed');
end;

procedure TestEditWithoutArguments;
var Host: THitlHost; Options: TPraxoAgentOptions; R: TPraxoAgentResult; Code: UTF8String;
begin
  Host := THitlHost.Create;
  try
    Options := NewOptions(Host, ScriptText);
    ResetDecision;
    DecisionAction := PraxoInterruptEdit;
    Options.OnInterruptDecision := @Decide;
    Code := Run(Host, Options, R);
    try
      Check(Code = 'AGENT_INTERRUPT_DECISION_INVALID', 'edit missing arguments code: ' + Code);
      Check(Host.Invocations = 0, 'edit missing arguments invocations');
    finally
      if R.Messages <> nil then R.Messages.Free;
      FreeOptions(Host);
    end;
  finally
    Host.Free;
  end;
  Writeln('hitl edit without arguments passed');
end;

procedure TestApprovalDenied;
var Host: THitlHost; Options: TPraxoAgentOptions; R: TPraxoAgentResult; Code: UTF8String;
begin
  Host := THitlHost.Create;
  try
    Options := NewOptions(Host, ScriptText);
    ResetDecision;
    ApprovalResult := False;
    Options.OnInterrupt := @Approve;
    Code := Run(Host, Options, R);
    try
      Check(Code = 'AGENT_APPROVAL_DENIED', 'approval code: ' + Code);
      Check(Host.Invocations = 0, 'approval invocations');
    finally
      if R.Messages <> nil then R.Messages.Free;
      FreeOptions(Host);
    end;
  finally
    Host.Free;
  end;
  Writeln('hitl approval denial passed');
end;

begin
  TestApprove;
  TestEditReauthorizeDenied;
  TestReject;
  TestRespond;
  TestUnhandled;
  TestInvalid;
  TestEditWithoutArguments;
  TestApprovalDenied;
  Writeln('Delphi HITL tests passed');
end.
