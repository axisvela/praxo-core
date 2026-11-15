program consumer_example;

{$mode objfpc}{$H+}

uses SysUtils, fpjson, praxo_agent;

type
  TFixtureHost = class(TPraxoAgentHost)
  private
    FTarget: UTF8String;
    FInvocations: Integer;
    FUnsafe: Boolean;
  public
    constructor Create(const Target: UTF8String);
    function Generate(Messages: TJSONArray): TJSONObject; override;
    function Invoke(const Name: UTF8String; Arguments: TJSONObject): TJSONData; override;
    procedure Emit(const EventType: UTF8String); override;
    property Invocations: Integer read FInvocations;
  end;

var
  DenyUnsafeTarget: Boolean = False;

function Authorize(const Kind: UTF8String): Boolean;
begin
  if Kind = 'model.generate' then Exit(True);
  if Kind = 'tool.invoke' then Exit(not DenyUnsafeTarget);
  Result := False;
end;

constructor TFixtureHost.Create(const Target: UTF8String);
begin
  inherited Create;
  FTarget := Target;
  FInvocations := 0;
  FUnsafe := Target <> 'public';
end;

function TFixtureHost.Generate(Messages: TJSONArray): TJSONObject;
var
  Call, Args, Response, Last: TJSONObject;
  Calls: TJSONArray;
begin
  DenyUnsafeTarget := FUnsafe;
  Last := TJSONObject(Messages.Items[Messages.Count - 1]);
  Response := TJSONObject.Create;
  Response.Add('inputTokens', Int64(0));
  Response.Add('outputTokens', Int64(0));
  if Last.Get('role', '') = 'tool' then
  begin
    Response.Add('content', 'recorded');
    Exit(Response);
  end;
  Response.Add('content', '');
  Args := TJSONObject.Create;
  Args.Add('target', FTarget);
  Call := TJSONObject.Create;
  Call.Add('id', 'record-1');
  Call.Add('name', 'record');
  Call.Add('arguments', Args);
  Calls := TJSONArray.Create;
  Calls.Add(Call);
  Response.Add('toolCalls', Calls);
  Result := Response;
end;

function TFixtureHost.Invoke(const Name: UTF8String; Arguments: TJSONObject): TJSONData;
begin
  if Name <> 'record' then
    raise EPraxoAgent.CreateCode('TOOL_NOT_FOUND', 'unknown tool: ' + Name);
  Inc(FInvocations);
  Result := TJSONString.Create('recorded');
end;

procedure TFixtureHost.Emit(const EventType: UTF8String);
begin
end;

procedure RunCase(const Target: UTF8String; out Effects: Integer;
  out Code: UTF8String; out Output: UTF8String);
var
  Host: TFixtureHost;
  Allowed: TPraxoAgentStringArray;
  Result: TPraxoAgentResult;
begin
  Host := TFixtureHost.Create(Target);
  try
    SetLength(Allowed, 1);
    Allowed[0] := 'record';
    Code := '';
    Output := '';
    try
      Result := PraxoRunAgent(Host, 'Record the requested target.', 3, 0,
        False, @Authorize, True, Allowed);
      Output := Result.Output;
    except
      on E: EPraxoAgent do Code := E.Code;
    end;
    Effects := Host.Invocations;
  finally
    Host.Free;
  end;
end;

var
  Effects: Integer;
  Code, Output: UTF8String;

begin
  RunCase('public', Effects, Code, Output);
  if (Code <> '') or (Output <> 'recorded') or (Effects <> 1) then
  begin
    WriteLn(StdErr, 'allow verification failed: output=', Output,
      ' effects=', Effects, ' code=', Code);
    Halt(1);
  end;
  WriteLn('allow: recorded; effects=1');

  RunCase('private', Effects, Code, Output);
  if (Code <> 'AGENT_POLICY_DENIED') or (Effects <> 0) then
  begin
    WriteLn(StdErr, 'deny verification failed: effects=', Effects,
      ' code=', Code);
    Halt(1);
  end;
  WriteLn('deny: policy rejected; effects=0');
end.
