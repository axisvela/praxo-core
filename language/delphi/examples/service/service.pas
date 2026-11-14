program service_example;

{$mode objfpc}{$H+}

type
  TResponse = record
    Status: Integer;
    Body: string;
  end;

function Contains(const Text, Needle: string): Boolean;
begin
  Result := Pos(Needle, Text) > 0;
end;

function Handle(const Method, Path, Principal, Body: string): TResponse;
begin
  if (Method = 'GET') and (Path = '/healthz') then
  begin
    Result.Status := 200;
    Result.Body := '{"status":"ok"}';
    Exit;
  end;
  if (Method <> 'POST') or (Path <> '/run') then
  begin
    Result.Status := 404;
    Result.Body := '{"error":"not found"}';
    Exit;
  end;
  if Principal = '' then
  begin
    Result.Status := 401;
    Result.Body := '{"error":"missing X-Praxo-Principal"}';
    Exit;
  end;
  if not Contains(Body, '"prompt"') then
  begin
    Result.Status := 400;
    Result.Body := '{"error":"prompt is required"}';
    Exit;
  end;
  Result.Status := 200;
  Result.Body := '{"output":"hello from the service"}';
end;

begin
  if Handle('GET', '/healthz', '', '').Status <> 200 then Halt(1);
  if Handle('POST', '/run', '', '{"prompt":"hi"}').Status <> 401 then Halt(1);
  if Handle('POST', '/run', 'user-1', '{"prompt":"hi"}').Status <> 200 then Halt(1);
  WriteLn('Delphi service example passed');
end.
