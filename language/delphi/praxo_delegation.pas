unit praxo_delegation;
{$mode objfpc}{$H+}

interface

uses SysUtils;

type
  EPraxoDelegation = class(Exception)
  public
    Code: UTF8String;
    constructor CreateCode(const ACode, AMessage: UTF8String);
  end;

  TPraxoSubagentRequest = record
    ParentSessionId, AgentId, Prompt, Mode: UTF8String;
  end;

  TPraxoSubagentResult = record
    TaskId, AgentId, Output: UTF8String;
  end;

  TPraxoSubagentTask = record
    Id, ParentSessionId, AgentId, Mode, Status, Output, Error,
      CreatedAt, UpdatedAt: UTF8String;
  end;

  TPraxoSubagentRunner = function(const Request: TPraxoSubagentRequest):
    TPraxoSubagentResult;
  TPraxoDelegationClock = function: UTF8String;

  TPraxoSubagentManager = class
  public
    Runner: TPraxoSubagentRunner;
    Clock: TPraxoDelegationClock;
    constructor Create;
    function Run(const Request: TPraxoSubagentRequest): TPraxoSubagentTask;
  end;

implementation

uses DateUtils;

constructor EPraxoDelegation.CreateCode(const ACode, AMessage: UTF8String);
begin
  inherited Create(AMessage);
  Code := ACode;
end;

function DefaultDelegationClock: UTF8String;
begin
  Result := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss.zzz"Z"',
    LocalTimeToUniversal(Now));
end;

constructor TPraxoSubagentManager.Create;
begin
  inherited Create;
  Clock := @DefaultDelegationClock;
end;

function TPraxoSubagentManager.Run(const Request: TPraxoSubagentRequest):
  TPraxoSubagentTask;
var
  Timestamp: UTF8String;
  ResultValue: TPraxoSubagentResult;
begin
  if (Request.ParentSessionId = '') or (Request.AgentId = '') then
    raise EPraxoDelegation.CreateCode('SUBAGENT_INVALID',
      'agent: subagent parent session and agent id are required');
  if not Assigned(Runner) then
    raise EPraxoDelegation.CreateCode('SUBAGENT_INVALID',
      'agent: subagent runner is required');
  if Assigned(Clock) then Timestamp := Clock() else Timestamp := DefaultDelegationClock;
  Result.Id := 'subagent';
  Result.ParentSessionId := Request.ParentSessionId;
  Result.AgentId := Request.AgentId;
  if Request.Mode = 'fork' then Result.Mode := 'fork'
  else Result.Mode := 'isolated';
  Result.Status := 'running';
  Result.Output := '';
  Result.Error := '';
  Result.CreatedAt := Timestamp;
  Result.UpdatedAt := Timestamp;
  try
    ResultValue := Runner(Request);
    Result.Status := 'completed';
    Result.Output := ResultValue.Output;
  except
    on E: EPraxoDelegation do
    begin
      Result.Status := 'failed';
      Result.Output := '';
      Result.Error := E.Code;
    end;
    on E: Exception do
    begin
      Result.Status := 'failed';
      Result.Output := '';
      Result.Error := 'SUBAGENT_ERROR';
    end;
  end;
end;

end.
