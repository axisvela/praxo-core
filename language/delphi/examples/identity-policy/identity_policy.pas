program identity_policy_example;

{$mode objfpc}{$H+}

function Authorize(const Tenant, Role: string; Active: Boolean;
  const Tool, TargetTenant: string): Boolean;
begin
  if not Active then Exit(False);
  if Role <> 'operator' then Exit(False);
  if Tenant <> TargetTenant then Exit(False);
  Result := Tool = 'record';
end;

begin
  if not Authorize('acme', 'operator', True, 'record', 'acme') then Halt(1);
  if Authorize('acme', 'viewer', True, 'record', 'acme') then Halt(1);
  if Authorize('acme', 'operator', True, 'record', 'other') then Halt(1);
  if Authorize('acme', 'operator', False, 'record', 'acme') then Halt(1);
  WriteLn('Delphi identity policy example passed');
end.
