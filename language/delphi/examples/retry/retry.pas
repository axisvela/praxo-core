program retry_example;

{$mode objfpc}{$H+}

uses SysUtils;

type
  TOutcome = record
    Output: string;
    Code: string;
    Calls: Integer;
  end;

function RunRetry(Failures, MaxAttempts: Integer): TOutcome;
var
  Attempt: Integer;
begin
  for Attempt := 1 to MaxAttempts do
    if Attempt > Failures then
    begin
      Result.Output := 'status: green';
      Result.Code := '';
      Result.Calls := Attempt;
      Exit;
    end;
  Result.Output := '';
  Result.Code := 'MODEL_UNAVAILABLE';
  Result.Calls := MaxAttempts;
end;

var
  Outcome: TOutcome;
begin
  Outcome := RunRetry(2, 3);
  if (Outcome.Output <> 'status: green') or (Outcome.Calls <> 3) then
    Halt(1);
  Outcome := RunRetry(3, 3);
  if (Outcome.Code <> 'MODEL_UNAVAILABLE') or (Outcome.Calls <> 3) then
    Halt(1);
  WriteLn('Delphi retry example passed');
end.
