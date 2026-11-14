program structured_output_example;

{$mode objfpc}{$H+}

uses fpjson, praxo, praxo_core;

var
  Schema, Valid, Invalid: TJSONData;
  Errors: TPraxoStringArray;
begin
  Schema := GetJSON('{"type":"object","required":["name"],"properties":{"name":{"type":"string"}}}');
  Valid := GetJSON('{"name":"ok"}');
  Invalid := GetJSON('{}');
  try
    Errors := PraxoValidateSchema(Schema, Valid);
    if Length(Errors) <> 0 then Halt(1);
    Errors := PraxoValidateSchema(Schema, Invalid);
    if Length(Errors) = 0 then Halt(1);
  finally
    Schema.Free;
    Valid.Free;
    Invalid.Free;
  end;
  WriteLn('Delphi structured output example passed');
end.
