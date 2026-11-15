unit praxo_agent;
{$mode objfpc}{$H+}

interface

uses SysUtils, fpjson;

type
  TPraxoAgentStringArray = array of UTF8String;

  TPraxoAgentInterrupt = record
    RunId: UTF8String;
    SessionId: UTF8String;
    CallId: UTF8String;
    Name: UTF8String;
    Arguments: TJSONObject;
  end;

  TPraxoAgentDecision = record
    Action: UTF8String;
    HasArguments: Boolean;
    Arguments: TJSONObject;
    Response: UTF8String;
    Reason: UTF8String;
  end;

  TPraxoAgentPolicyHook = function(const Kind: UTF8String): Boolean;
  TPraxoAgentAuthorizeHook = function(const Kind, ToolName: UTF8String; Arguments: TJSONObject): Boolean;
  TPraxoAgentDecisionHook = function(const Interrupt: TPraxoAgentInterrupt): TPraxoAgentDecision;
  TPraxoAgentApprovalHook = function(const Interrupt: TPraxoAgentInterrupt): Boolean;

const
  PraxoInterruptApprove = 'approve';
  PraxoInterruptEdit = 'edit';
  PraxoInterruptReject = 'reject';
  PraxoInterruptRespond = 'respond';

type
  EPraxoAgent = class(Exception)
  public
    Code: UTF8String;
    constructor CreateCode(const ACode, AMessage: UTF8String);
  end;

  TPraxoAgentHost = class
  public
    function Generate(Messages: TJSONArray): TJSONObject; virtual; abstract;
    function Invoke(const Name: UTF8String; Arguments: TJSONObject): TJSONData; virtual; abstract;
    procedure Emit(const EventType: UTF8String); virtual; abstract;
    procedure EmitEvent(const EventType: UTF8String; Data: TJSONObject); virtual;
  end;

  TPraxoAgentOptions = record
    MaxSteps: Integer;
    MaxTokens: Int64;
    RequirePolicy: Boolean;
    Policy: TPraxoAgentPolicyHook;
    Authorize: TPraxoAgentAuthorizeHook;
    RequireToolScope: Boolean;
    AllowedTools: TPraxoAgentStringArray;
    SessionId: UTF8String;
    InterruptOn: TPraxoAgentStringArray;
    OnInterruptDecision: TPraxoAgentDecisionHook;
    OnInterrupt: TPraxoAgentApprovalHook;
  end;

  TPraxoAgentResult = record
    Output: UTF8String;
    Steps: Integer;
    InputTokens: Int64;
    OutputTokens: Int64;
    Messages: TJSONArray;
  end;

function PraxoAgentOptionsNew: TPraxoAgentOptions;
function PraxoRunAgent(Host: TPraxoAgentHost; const Prompt: UTF8String; MaxSteps: Integer; MaxTokens: Int64; RequirePolicy: Boolean = False; Policy: TPraxoAgentPolicyHook = nil; RequireToolScope: Boolean = False; AllowedTools: TPraxoAgentStringArray = nil): TPraxoAgentResult;
function PraxoRunAgentSession(Host: TPraxoAgentHost; PriorMessages: TJSONArray; const Prompt: UTF8String; const Options: TPraxoAgentOptions): TPraxoAgentResult;

implementation

uses praxo;

type
  TPraxoInterruptOutcome = record
    Skip: Boolean;
    Edited: Boolean;
    Content: UTF8String;
  end;

constructor EPraxoAgent.CreateCode(const ACode, AMessage: UTF8String);
begin
  inherited Create(AMessage);
  Code := ACode;
end;

procedure TPraxoAgentHost.EmitEvent(const EventType: UTF8String; Data: TJSONObject);
begin
  Emit(EventType);
end;

function PraxoAgentOptionsNew: TPraxoAgentOptions;
begin
  Result.MaxSteps := 8;
  Result.MaxTokens := 0;
  Result.RequirePolicy := False;
  Result.Policy := nil;
  Result.Authorize := nil;
  Result.RequireToolScope := False;
  SetLength(Result.AllowedTools, 0);
  Result.SessionId := 's1';
  SetLength(Result.InterruptOn, 0);
  Result.OnInterruptDecision := nil;
  Result.OnInterrupt := nil;
end;

function StringValue(Obj: TJSONObject; const Name: UTF8String): UTF8String;
var V: TJSONData;
begin
  V := Obj.Find(Name);
  if (V = nil) or (V.JSONType <> jtString) then
    raise EPraxoAgent.CreateCode('AGENT_INVALID_RESPONSE', 'Expected string: ' + Name);
  Result := V.AsString;
end;

function Tokens(Obj: TJSONObject; const Name: UTF8String): Int64;
var V: TJSONData;
begin
  V := Obj.Find(Name);
  if V = nil then Exit(0);
  if (V.JSONType <> jtNumber) or (V.AsFloat < 0) or
    (V.AsFloat >= 9223372036854775808.0) or (Frac(V.AsFloat) <> 0) then
    raise EPraxoAgent.CreateCode('AGENT_INVALID_RESPONSE', 'Invalid token count: ' + Name);
  Result := V.AsInt64;
end;

function ToolAllowed(const Name: UTF8String; const Tools: TPraxoAgentStringArray): Boolean;
var
  I: Integer;
begin
  if Length(Tools) = 0 then Exit(True);
  for I := Low(Tools) to High(Tools) do
    if Tools[I] = Name then Exit(True);
  Result := False;
end;

function InterruptEnabled(const Name: UTF8String; const Names: TPraxoAgentStringArray): Boolean;
var
  I: Integer;
begin
  for I := Low(Names) to High(Names) do
    if Names[I] = Name then Exit(True);
  Result := False;
end;

procedure AuthorizeAction(const Options: TPraxoAgentOptions; const Kind, ToolName: UTF8String; Arguments: TJSONObject);
begin
  if Assigned(Options.Authorize) then
  begin
    if not Options.Authorize(Kind, ToolName, Arguments) then
      raise EPraxoAgent.CreateCode('AGENT_POLICY_DENIED', 'agent: ' + Kind + ' denied');
  end
  else if Assigned(Options.Policy) then
  begin
    if not Options.Policy(Kind) then
      raise EPraxoAgent.CreateCode('AGENT_POLICY_DENIED', 'agent: ' + Kind + ' denied');
  end;
end;

procedure EmitToolData(Host: TPraxoAgentHost; const EventType, Name: UTF8String; Arguments: TJSONObject);
var
  Data: TJSONObject;
begin
  Data := TJSONObject.Create;
  try
    Data.Add('name', Name);
    Data.Add('arguments', Arguments.Clone);
    Host.EmitEvent(EventType, Data);
  finally
    Data.Free;
  end;
end;

function ApplyInterrupt(Host: TPraxoAgentHost; const Options: TPraxoAgentOptions; const RunId, SessionId, CallId, Name: UTF8String;
  CurrentArgs: TJSONObject; out NewArgs: TJSONObject): TPraxoInterruptOutcome;
var
  Interrupt: TPraxoAgentInterrupt;
  Decision: TPraxoAgentDecision;
  StrData: TJSONString;
begin
  Result.Skip := False;
  Result.Edited := False;
  Result.Content := '';
  NewArgs := nil;
  if not InterruptEnabled(Name, Options.InterruptOn) then Exit;
  if not Assigned(Options.OnInterruptDecision) and not Assigned(Options.OnInterrupt) then
    raise EPraxoAgent.CreateCode('AGENT_INTERRUPT_UNHANDLED', 'agent: approval handler not configured: ' + Name);
  EmitToolData(Host, 'tool.interrupt', Name, CurrentArgs);
  Interrupt.RunId := RunId;
  Interrupt.SessionId := SessionId;
  Interrupt.CallId := CallId;
  Interrupt.Name := Name;
  Interrupt.Arguments := CurrentArgs;
  if Assigned(Options.OnInterruptDecision) then
  begin
    Decision := Options.OnInterruptDecision(Interrupt);
    if Decision.Action = PraxoInterruptApprove then Exit;
    if Decision.Action = PraxoInterruptEdit then
    begin
      if not Decision.HasArguments or (Decision.Arguments = nil) or (Decision.Arguments.JSONType <> jtObject) then
        raise EPraxoAgent.CreateCode('AGENT_INTERRUPT_DECISION_INVALID', 'agent: edit requires arguments');
      NewArgs := TJSONObject(Decision.Arguments.Clone);
      Result.Edited := True;
      Exit;
    end;
    if Decision.Action = PraxoInterruptReject then
      raise EPraxoAgent.CreateCode('AGENT_APPROVAL_DENIED', 'agent: tool call denied by approval: ' + Name + ': ' + Decision.Reason);
    if Decision.Action = PraxoInterruptRespond then
    begin
      StrData := TJSONString.Create(Decision.Response);
      try
        Result.Content := PraxoEncodeJSON(StrData);
      finally
        StrData.Free;
      end;
      Result.Skip := True;
      Exit;
    end;
    raise EPraxoAgent.CreateCode('AGENT_INTERRUPT_DECISION_INVALID', 'agent: invalid interrupt decision: ' + Decision.Action);
  end;
  if not Options.OnInterrupt(Interrupt) then
    raise EPraxoAgent.CreateCode('AGENT_APPROVAL_DENIED', 'agent: tool call denied by approval: ' + Name);
end;

function RunAgentCore(Host: TPraxoAgentHost; PriorMessages: TJSONArray; const Prompt: UTF8String;
  const Options: TPraxoAgentOptions): TPraxoAgentResult;
var
  Messages, Calls: TJSONArray;
  Response, Message, Call, Args, OwnedArgs, NewArgs: TJSONObject;
  V, ToolResult: TJSONData;
  Step, I, P, MaxSteps: Integer;
  InputCount, OutputCount: Int64;
  Name, ID, Content, Encoded, SessionId, RunId: UTF8String;
  Outcome: TPraxoInterruptOutcome;
  Attached: Boolean;
begin
  Result.Output := '';
  Result.Steps := 0;
  Result.InputTokens := 0;
  Result.OutputTokens := 0;
  Result.Messages := nil;
  if Options.RequirePolicy and not Assigned(Options.Policy) and not Assigned(Options.Authorize) then
    raise EPraxoAgent.CreateCode('AGENT_INVALID_OPTIONS', 'agent: require policy: policy is required');
  if Options.RequireToolScope and (Length(Options.AllowedTools) = 0) then
    raise EPraxoAgent.CreateCode('AGENT_INVALID_OPTIONS', 'agent: require tool scope: AllowedTools must not be empty');
  if Host = nil then
    raise EPraxoAgent.CreateCode('AGENT_INVALID_HOST', 'Agent host is required');
  if Options.MaxSteps <= 0 then
    MaxSteps := 8
  else
    MaxSteps := Options.MaxSteps;
  SessionId := Options.SessionId;
  if SessionId = '' then SessionId := 's1';
  RunId := 'run-1';
  Messages := TJSONArray.Create;
  Attached := False;
  try
    try
      if PriorMessages <> nil then
        for P := 0 to PriorMessages.Count - 1 do
          Messages.Add(PriorMessages.Items[P].Clone);
      Message := TJSONObject.Create;
      Message.Add('role', 'user');
      Message.Add('content', Prompt);
      Messages.Add(Message);
      Host.EmitEvent('run.started', nil);
      for Step := 1 to MaxSteps do
      begin
        AuthorizeAction(Options, 'model.generate', '', nil);
        Response := Host.Generate(Messages);
        if Response = nil then
          raise EPraxoAgent.CreateCode('AGENT_INVALID_RESPONSE', 'Model returned nil');
        try
          Content := StringValue(Response, 'content');
          InputCount := Tokens(Response, 'inputTokens');
          OutputCount := Tokens(Response, 'outputTokens');
          if (InputCount > High(Int64) - Result.InputTokens) or
             (OutputCount > High(Int64) - Result.OutputTokens) then
            raise EPraxoAgent.CreateCode('AGENT_INVALID_RESPONSE', 'Token count overflow');
          Inc(Result.InputTokens, InputCount);
          Inc(Result.OutputTokens, OutputCount);
          if (Options.MaxTokens > 0) and ((Result.InputTokens > Options.MaxTokens) or
            (Result.OutputTokens > Options.MaxTokens - Result.InputTokens)) then
            raise EPraxoAgent.CreateCode('AGENT_MAX_TOKENS', 'Token budget exceeded');
          V := Response.Find('toolCalls');
          if (V <> nil) and (V.JSONType <> jtArray) then
            raise EPraxoAgent.CreateCode('AGENT_INVALID_RESPONSE', 'toolCalls must be an array');
          Calls := TJSONArray(V);
          Message := TJSONObject.Create;
          Message.Add('role', 'assistant');
          Message.Add('content', Content);
          if Calls <> nil then Message.Add('toolCalls', Calls.Clone);
          Messages.Add(Message);
          if (Calls = nil) or (Calls.Count = 0) then
          begin
            Result.Output := Content;
            Result.Steps := Step;
            Host.EmitEvent('run.completed', nil);
            Result.Messages := Messages;
            Attached := True;
            Exit;
          end;
          for I := 0 to Calls.Count - 1 do
          begin
            if Calls.Items[I].JSONType <> jtObject then
              raise EPraxoAgent.CreateCode('AGENT_INVALID_RESPONSE', 'Invalid tool call');
            Call := TJSONObject(Calls.Items[I]);
            Name := StringValue(Call, 'name');
            ID := StringValue(Call, 'id');
            V := Call.Find('arguments');
            if (Name = '') or (V = nil) or (V.JSONType <> jtObject) then
              raise EPraxoAgent.CreateCode('AGENT_INVALID_RESPONSE', 'Invalid tool arguments or name');
            Args := TJSONObject(V);
            OwnedArgs := nil;
            try
              if not ToolAllowed(Name, Options.AllowedTools) then
                raise EPraxoAgent.CreateCode('AGENT_TOOL_NOT_ALLOWED', 'agent: tool ' + Name + ' is not allowed');
              AuthorizeAction(Options, 'tool.invoke', Name, Args);
              Outcome.Skip := False;
              Outcome.Edited := False;
              Outcome.Content := '';
              if InterruptEnabled(Name, Options.InterruptOn) then
              begin
                NewArgs := nil;
                Outcome := ApplyInterrupt(Host, Options, RunId, SessionId, ID, Name, Args, NewArgs);
                if Outcome.Edited then
                begin
                  OwnedArgs := NewArgs;
                  Args := OwnedArgs;
                  AuthorizeAction(Options, 'tool.invoke', Name, Args);
                end;
              end;
              if Outcome.Skip then
                Encoded := Outcome.Content
              else
              begin
                EmitToolData(Host, 'tool.call', Name, Args);
                ToolResult := Host.Invoke(Name, Args);
                if ToolResult = nil then
                  raise EPraxoAgent.CreateCode('AGENT_INVALID_RESPONSE', 'Tool returned nil');
                try
                  Encoded := PraxoEncodeJSON(ToolResult);
                finally
                  ToolResult.Free;
                end;
              end;
              Message := TJSONObject.Create;
              Message.Add('role', 'tool');
              Message.Add('toolCallId', ID);
              Message.Add('content', Encoded);
              Messages.Add(Message);
            finally
              OwnedArgs.Free;
            end;
          end;
        finally
          Response.Free;
        end;
      end;
      raise EPraxoAgent.CreateCode('AGENT_MAX_STEPS', 'Step budget exceeded');
    except
      try
        Host.EmitEvent('run.failed', nil);
      except
      end;
      raise;
    end;
  finally
    if not Attached then Messages.Free;
  end;
end;

function PraxoRunAgentSession(Host: TPraxoAgentHost; PriorMessages: TJSONArray; const Prompt: UTF8String;
  const Options: TPraxoAgentOptions): TPraxoAgentResult;
begin
  Result := RunAgentCore(Host, PriorMessages, Prompt, Options);
end;

function PraxoRunAgent(Host: TPraxoAgentHost; const Prompt: UTF8String; MaxSteps: Integer; MaxTokens: Int64;
  RequirePolicy: Boolean; Policy: TPraxoAgentPolicyHook;
  RequireToolScope: Boolean; AllowedTools: TPraxoAgentStringArray): TPraxoAgentResult;
var
  Options: TPraxoAgentOptions;
begin
  Options := PraxoAgentOptionsNew;
  Options.MaxSteps := MaxSteps;
  Options.MaxTokens := MaxTokens;
  Options.RequirePolicy := RequirePolicy;
  Options.Policy := Policy;
  Options.RequireToolScope := RequireToolScope;
  Options.AllowedTools := AllowedTools;
  Result := RunAgentCore(Host, nil, Prompt, Options);
  if Result.Messages <> nil then Result.Messages.Free;
  Result.Messages := nil;
end;

end.
