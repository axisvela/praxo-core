program agent_tests;
{$mode objfpc}{$H+}

uses SysUtils, Classes, fpjson, praxo, praxo_agent;

type
  TTestHost = class(TPraxoAgentHost)
    Script, Tools, Events: TJSONArray;
    Next, Invocations: Integer;
    FailModel, FailTool, FailEvent: Boolean;
    constructor Create;
    destructor Destroy; override;
    function Generate(Messages: TJSONArray): TJSONObject; override;
    function Invoke(const Name: UTF8String; Arguments: TJSONObject): TJSONData; override;
    procedure Emit(const EventType: UTF8String); override;
  end;

constructor TTestHost.Create;
begin
  inherited Create;
  Events := TJSONArray.Create;
end;

destructor TTestHost.Destroy;
begin
  Events.Free;
  inherited Destroy;
end;

function TTestHost.Generate(Messages: TJSONArray): TJSONObject;
begin
  if FailModel then raise Exception.Create('model failure');
  if Next >= Script.Count then raise Exception.Create('script exhausted');
  if (Next > 0) and (Messages.Count < 3) then raise Exception.Create('missing history');
  if (Next > 0) and ((TJSONObject(Messages.Items[1]).Get('role', '') <> 'assistant') or
    (TJSONObject(Messages.Items[2]).Get('role', '') <> 'tool') or
    (TJSONObject(Messages.Items[2]).Get('toolCallId', '') <> 'c1') or
    (TJSONObject(Messages.Items[2]).Get('content', '') = '')) then
    raise Exception.Create('invalid tool history');
  Result := TJSONObject(Script.Items[Next].Clone);
  Inc(Next);
end;

function TTestHost.Invoke(const Name: UTF8String; Arguments: TJSONObject): TJSONData;
var I: Integer;
begin
  if FailTool then raise Exception.Create('tool failure');
  if Tools <> nil then
    for I := 0 to Tools.Count - 1 do
      if TJSONObject(Tools.Items[I]).Get('name', '') = Name then
      begin
        Inc(Invocations);
        Exit(Arguments.Clone);
      end;
  raise Exception.Create('unknown tool');
end;

procedure TTestHost.Emit(const EventType: UTF8String);
begin
  Events.Add(EventType);
  if FailEvent and (EventType = 'tool.call') then raise Exception.Create('event failure');
end;

procedure Check(Condition: Boolean; const Detail: UTF8String);
begin
  if not Condition then raise Exception.Create(Detail);
end;

function ReadText(const Path: UTF8String): UTF8String;
var S: TFileStream;
begin
  S := TFileStream.Create(Path, fmOpenRead or fmShareDenyWrite);
  try
    SetLength(Result, S.Size);
    if S.Size > 0 then S.ReadBuffer(Result[1], S.Size);
  finally
    S.Free;
  end;
end;

procedure TestVectors(const Root: UTF8String);
var
  Data: TJSONData;
  Vectors: TJSONArray;
  Vector, Input, Expected: TJSONObject;
  Host: TTestHost;
  R: TPraxoAgentResult;
  I: Integer;
  Code: UTF8String;
begin
  Data := PraxoParseJSON(ReadText(Root + '/vectors/agent-loop.json'));
  try
    Vectors := TJSONArray(TJSONObject(Data).Find('vectors'));
    Check(Vectors.Count > 0, 'empty vectors');
    for I := 0 to Vectors.Count - 1 do
    begin
      Vector := TJSONObject(Vectors.Items[I]);
      Input := TJSONObject(Vector.Find('input'));
      Expected := TJSONObject(Vector.Find('expect'));
      Host := TTestHost.Create;
      try
        Host.Script := TJSONArray(Input.Find('script'));
        Host.Tools := TJSONArray(Input.Find('tools'));
        Code := '';
        try
          R := PraxoRunAgent(Host, Input.Get('prompt', ''), Input.Get('maxSteps', 0), Input.Get('maxTokens', Int64(0)));
          Check(not Expected.Get('error', False), 'unexpected success');
          Check(R.Output = Expected.Get('output', ''), 'output');
          Check(R.Steps = Expected.Get('steps', 0), 'steps');
        except
          on E: EPraxoAgent do Code := E.Code;
        end;
        Check(Code = Expected.Get('errorCode', ''), Vector.Get('id', '') + ': error code ' + Code);
        Check(Host.Invocations = Expected.Get('toolInvocations', 0), 'invocations');
        Check(PraxoJSONEqual(Host.Events, Expected.Find('events')), 'events');
      finally
        Host.Free;
      end;
    end;
  finally
    Data.Free;
  end;
  Writeln('agent loop vectors passed');
end;

procedure TestFailure(const ScriptText, ExpectedMessage, ExpectedEvents: UTF8String; ModelFail, ToolFail, EventFail: Boolean);
var Host: TTestHost; Script, Expected: TJSONData; MessageText: UTF8String;
begin
  Script := PraxoParseJSON(ScriptText);
  Expected := PraxoParseJSON(ExpectedEvents);
  Host := TTestHost.Create;
  try
    Host.Script := TJSONArray(Script);
    Host.FailModel := ModelFail;
    Host.FailTool := ToolFail;
    Host.FailEvent := EventFail;
    MessageText := '';
    try
      PraxoRunAgent(Host, 'test', 2, 0);
    except
      on E: Exception do MessageText := E.Message;
    end;
    Check(MessageText = ExpectedMessage, 'failure propagation: ' + MessageText);
    Check(PraxoJSONEqual(Host.Events, Expected), 'failure events');
    Check(Host.Invocations = 0, 'unexpected invocation');
  finally
    Host.Free;
    Expected.Free;
    Script.Free;
  end;
end;

begin
  TestVectors(ParamStr(1));
  TestFailure('[]', 'model failure', '["run.started","run.failed"]', True, False, False);
  TestFailure('[]', 'script exhausted', '["run.started","run.failed"]', False, False, False);
  TestFailure('[{"content":"","toolCalls":[{"id":"1","name":"x","arguments":{}}]}]', 'tool failure', '["run.started","tool.call","run.failed"]', False, True, False);
  TestFailure('[{"content":"","toolCalls":[{"id":"1","name":"x","arguments":{}}]}]', 'unknown tool', '["run.started","tool.call","run.failed"]', False, False, False);
  TestFailure('[{"content":"","toolCalls":[{"id":"1","name":"x","arguments":{}}]}]', 'event failure', '["run.started","tool.call","run.failed"]', False, False, True);
  TestFailure('[{"content":"x","outputTokens":-1}]', 'Invalid token count: outputTokens', '["run.started","run.failed"]', False, False, False);
  TestFailure('[{"content":"","toolCalls":{}}]', 'toolCalls must be an array', '["run.started","run.failed"]', False, False, False);
  Writeln('agent error tests passed');
end.
