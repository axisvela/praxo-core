program checkpoint_example;

{$mode objfpc}{$H+}

uses fpjson, praxo_core;

var
  Allow: TPraxoStringArray;
  Value: TJSONData;
  Decoded: TJSONData;
  Data: UTF8String;
  Error: UTF8String;
begin
  Allow := PraxoCheckpointNew;
  PraxoCheckpointRegister(Allow, 'order');
  Value := GetJSON('{"value":"x"}');
  try
    Error := PraxoCheckpointMarshal(Allow, 'order', Value, Data);
    if Error <> '' then Halt(1);
    Error := PraxoCheckpointUnmarshal(Allow, Data, Decoded);
    if Error <> '' then Halt(1);
    if Decoded.FormatJSON <> Value.FormatJSON then Halt(1);
    Decoded.Free;
  finally
    Value.Free;
  end;
  WriteLn('Delphi checkpoint example passed');
end.
