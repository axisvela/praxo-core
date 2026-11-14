program provider_fallback_example;

{$mode objfpc}{$H+}

function RunFallback(PrimaryFails, FallbackFails: Boolean): string;
begin
  if not PrimaryFails then Exit('primary');
  if not FallbackFails then Exit('fallback');
  Result := 'MODEL_UNAVAILABLE';
end;

begin
  if RunFallback(False, False) <> 'primary' then Halt(1);
  if RunFallback(True, False) <> 'fallback' then Halt(1);
  if RunFallback(True, True) <> 'MODEL_UNAVAILABLE' then Halt(1);
  WriteLn('Delphi provider fallback example passed');
end.
