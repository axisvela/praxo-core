program hitl_example;
{$mode objfpc}{$H+}

uses SysUtils, fpjson, praxo, praxo_agent;

type
  TExampleHost = class(TPraxoAgentHost)
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
  DenyEdited: Boolean = False;

constructor TExampleHost.Create;
begin
  inherited Create;
  Events := TJSONArray.Create;
end;

destructor TExampleHost.Destroy;
begin
  Events.Free;
  inherited Destroy;
end;

function TExampleHost.Generate(Messages: TJSONArray): TJSONObject;
begin
  Result := TJSONObject(Script.Items[NextCall].Clone);
  Inc(NextCall);
end;

function TExampleHost.Invoke(const Name: UTF8String; Arguments: TJSONObject): TJSONData;
var V: TJSONData;
begin
  Inc(Invocations);
  V := Arguments.Find('value');
  if (V <> nil) and (V.JSONType = jtString) then LastValue := V.AsString else LastValue := '';
  Result := Arguments.Clone;
end;

procedure TExampleHost.Emit(const EventType: UTF8String);
begin
  Events.Add(EventType);
end;

procedure TExampleHost.EmitEvent(const EventType: UTF8String; Data: TJSONObject);
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

function Authorize(const Kind, ToolName: UTF8String; Arguments: TJSONObject): Boolean;
var V: TJSONData; Value: UTF8String;
begin
  Result := True;
  if Kind <> 'tool.invoke' then Exit;
  Value := '';
  V := Arguments.Find('value');
  if (V <> nil) and (V.JSONType = jtString) then Value := V.AsString;
  if DenyEdited and (Value = 'edited') then Result := False;
end;

procedure Check(Condition: Boolean; const Detail: UTF8String);
begin
  if not Condition then raise Exception.Create(Detail);
end;

procedure ResetDecision;
begin
  DecisionAction := '';
  DecisionHasArgs := False;
  DecisionArgs := nil;
  DecisionResponse := '';
  DecisionReason := '';
end;

const
  ScriptText = '[{"content":"","toolCalls":[{"id":"call-1","name":"echo","arguments":{"value":"original"}}]},{"content":"final"}]';

function NewOptions(Host: TExampleHost): TPraxoAgentOptions;
begin
  Result := PraxoAgentOptionsNew;
  Result.MaxSteps := 2;
  SetLength(Result.InterruptOn, 1);
  Result.InterruptOn[0] := 'echo';
  Result.OnInterruptDecision := @Decide;
  Host.Script := TJSONArray(PraxoParseJSON(ScriptText));
end;

function Run(Host: TExampleHost; const Options: TPraxoAgentOptions; out R: TPraxoAgentResult): UTF8String;
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

procedure TestApprove;
var
  Host: TExampleHost;
  Options: TPraxoAgentOptions;
  R: TPraxoAgentResult;
  Code: UTF8String;
begin
  Host := TExampleHost.Create;
  try
    Options := NewOptions(Host);
    ResetDecision;
    DecisionAction := PraxoInterruptApprove;
    Code := Run(Host, Options, R);
    try
      Check(Code = '', 'approve failed: ' + Code);
      Check(R.Output = 'final', 'approve output');
      Check((Host.Invocations = 1) and (Host.LastValue = 'original'), 'approve invocation');
    finally
      if R.Messages <> nil then R.Messages.Free;
      Host.Script.Free;
    end;
  finally
    Host.Free;
  end;
end;

procedure TestEditReauthorized;
var
  Host: TExampleHost;
  Options: TPraxoAgentOptions;
  R: TPraxoAgentResult;
  Code: UTF8String;
  EditArgs: TJSONData;
begin
  Host := TExampleHost.Create;
  try
    Options := NewOptions(Host);
    ResetDecision;
    EditArgs := PraxoParseJSON('{"value":"edited"}');
    try
      DecisionAction := PraxoInterruptEdit;
      DecisionHasArgs := True;
      DecisionArgs := TJSONObject(EditArgs);
      Code := Run(Host, Options, R);
      try
        Check(Code = '', 'edit failed: ' + Code);
        Check((Host.Invocations = 1) and (Host.LastValue = 'edited'), 'edit invocation');
      finally
        if R.Messages <> nil then R.Messages.Free;
      end;
    finally
      EditArgs.Free;
      Host.Script.Free;
    end;
  finally
    Host.Free;
  end;
end;

procedure TestEditDenied;
var
  Host: TExampleHost;
  Options: TPraxoAgentOptions;
  R: TPraxoAgentResult;
  Code: UTF8String;
  EditArgs: TJSONData;
begin
  Host := TExampleHost.Create;
  try
    Options := NewOptions(Host);
    Options.Authorize := @Authorize;
    ResetDecision;
    DenyEdited := True;
    EditArgs := PraxoParseJSON('{"value":"edited"}');
    try
      DecisionAction := PraxoInterruptEdit;
      DecisionHasArgs := True;
      DecisionArgs := TJSONObject(EditArgs);
      Code := Run(Host, Options, R);
      try
        Check(Code = 'AGENT_POLICY_DENIED', 'edit denial code: ' + Code);
        Check(Host.Invocations = 0, 'edit denial invocation');
      finally
        if R.Messages <> nil then R.Messages.Free;
      end;
    finally
      DenyEdited := False;
      EditArgs.Free;
      Host.Script.Free;
    end;
  finally
    Host.Free;
  end;
end;

procedure TestRespond;
var
  Host: TExampleHost;
  Options: TPraxoAgentOptions;
  R: TPraxoAgentResult;
  Code: UTF8String;
begin
  Host := TExampleHost.Create;
  try
    Options := NewOptions(Host);
    Host.Script.Free;
    Host.Script := TJSONArray(PraxoParseJSON('[{"content":"","toolCalls":[{"id":"call-1","name":"echo","arguments":{"value":"original"}}]},{"content":"\"human answer\""}]'));
    ResetDecision;
    DecisionAction := PraxoInterruptRespond;
    DecisionResponse := 'human answer';
    Code := Run(Host, Options, R);
    try
      Check(Code = '', 'respond failed: ' + Code);
      Check(R.Output = '"human answer"', 'respond output');
      Check(Host.Invocations = 0, 'respond invocation');
    finally
      if R.Messages <> nil then R.Messages.Free;
      Host.Script.Free;
    end;
  finally
    Host.Free;
  end;
end;

begin
  TestApprove;
  TestEditReauthorized;
  TestEditDenied;
  TestRespond;
  WriteLn('Delphi HITL example passed');
end.
