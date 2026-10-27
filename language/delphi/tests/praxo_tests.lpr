program praxo_tests;
{$mode objfpc}{$H+}

uses
  SysUtils, Classes, Math, fpjson, praxo;

var
  SpecRoot: UTF8String;

function ReadTextFile(const Path: UTF8String): UTF8String;
var
  stream: TFileStream;
begin
  stream := TFileStream.Create(Path, fmOpenRead or fmShareDenyWrite);
  try
    SetLength(Result, stream.Size);
    if stream.Size > 0 then
      stream.ReadBuffer(Result[1], stream.Size);
  finally
    stream.Free;
  end;
end;

function LastField(ObjectValue: TJSONObject; const Name: UTF8String): TJSONData;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to ObjectValue.Count - 1 do
    if ObjectValue.Names[i] = Name then
      Result := ObjectValue.Items[i];
end;

function StringField(ObjectValue: TJSONObject; const Name: UTF8String): UTF8String;
var
  data: TJSONData;
begin
  data := LastField(ObjectValue, Name);
  if (data = nil) or (data.JSONType <> jtString) then
    raise Exception.Create('missing string field ' + Name);
  Result := TJSONString(data).AsString;
end;

function BoolField(ObjectValue: TJSONObject; const Name: UTF8String): Boolean;
var
  data: TJSONData;
begin
  data := LastField(ObjectValue, Name);
  if (data = nil) or (data.JSONType <> jtBoolean) then
    raise Exception.Create('missing boolean field ' + Name);
  Result := data.AsBoolean;
end;

procedure Check(Condition: Boolean; const MessageText: UTF8String);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

procedure CheckPaths(const Actual: TPraxoStringArray; Expected: TJSONArray; const MessageText: UTF8String);
var
  i, j: Integer;
  found: Boolean;
begin
  Check(Length(Actual) = Expected.Count, MessageText + ': path count');
  for i := 0 to Expected.Count - 1 do
  begin
    found := False;
    for j := 0 to High(Actual) do
      if Actual[j] = TJSONString(Expected.Items[i]).AsString then
        found := True;
    Check(found, MessageText + ': path ' + TJSONString(Expected.Items[i]).AsString);
  end;
end;

procedure TestJSON;
var
  node: TJSONData;
  text: UTF8String;
begin
  node := PraxoParseJSON('{"a":[true,false,null,{"b":"x"}],"n":1.5}');
  try
    Check(node.JSONType = jtObject, 'object');
    Check(PraxoEncodeJSON(node) <> '', 'encode');
  finally
    node.Free;
  end;
  try
    PraxoParseJSON(''); Check(False, 'empty accepted');
  except
    on E: EPraxoJSON do ;
  end;
  try
    PraxoParseJSON('{} {}'); Check(False, 'trailing accepted');
  except
    on E: EPraxoJSON do ;
  end;
  try
    PraxoParseJSON(StringOfChar('[', 66) + '0' + StringOfChar(']', 66));
    Check(False, 'depth accepted');
  except
    on E: EPraxoJSON do ;
  end;
  try
    PraxoParseJSON(StringOfChar(' ', 1048577)); Check(False, 'capacity accepted');
  except
    on E: EPraxoJSON do ;
  end;
  node := PraxoParseJSON('"\u00e9\ud83d\ude00"');
  try
    text := TJSONString(node).AsString;
    Check(Length(text) = 6, 'unicode bytes');
  finally
    node.Free;
  end;
  Writeln('test_json passed');
end;

procedure TestToolCall;
var
  document, input, expect, vectors, vector: TJSONObject;
  arrayValue: TJSONArray;
  data: TJSONData;
  call: TPraxoCall;
  i: Integer;
  content, operation: UTF8String;
begin
  data := PraxoParseJSON(ReadTextFile(SpecRoot + '/vectors/toolcall.json'));
  try
    vectors := TJSONObject(data);
    arrayValue := TJSONArray(LastField(vectors, 'vectors'));
    Check(arrayValue.Count > 0, 'toolcall vectors');
    for i := 0 to arrayValue.Count - 1 do
    begin
      vector := TJSONObject(arrayValue.Items[i]);
      input := TJSONObject(LastField(vector, 'input'));
      expect := TJSONObject(LastField(vector, 'expect'));
      content := StringField(input, 'content');
      operation := StringField(input, 'operation');
      if operation = 'strip' then
        Check(PraxoStripToolCallMarkup(content) = StringField(expect, 'text'), 'strip vector')
      else
      begin
        if LastField(expect, 'nil') <> nil then
          Check(not PraxoParseToolCall(content, call), 'expected no call')
        else
        begin
          Check(PraxoParseToolCall(content, call), 'expected call');
          Check(call.Name = StringField(expect, 'name'), 'call name');
          Check(PraxoJSONEqual(call.Input, LastField(expect, 'input')), 'call input');
        end;
      end;
    end;
  finally
    data.Free;
  end;
  Check(PraxoParseToolCall('<a.one>{}</a.one><b.two>{bad}</b.two>', call) = False, 'invalid final block');
  Check(PraxoParseToolCall('{"name":"x","input":{},"risk":42}', call) = False, 'typed metadata');
  Check(PraxoStripToolCallMarkup('x.y {}') = 'x.y {}', 'strip preserves plain');
  Check(not PraxoParseToolCall('echo {}', call), 'plain needs dotted name');
  Check(PraxoStripToolCallMarkup('a<tool_call name="x">unfinished') = 'a', 'unfinished block');
  Writeln('test_toolcall passed');
end;

procedure TestSchema;
var
  document, vector, input, expect: TJSONObject;
  data, schemaNode, expectedData: TJSONData;
  arrayValue: TJSONArray;
  paths: TPraxoStringArray;
  valid: Boolean;
  i: Integer;
begin
  data := PraxoParseJSON(ReadTextFile(SpecRoot + '/vectors/jsonschema.json'));
  try
    arrayValue := TJSONArray(LastField(TJSONObject(data), 'vectors'));
    for i := 0 to arrayValue.Count - 1 do
    begin
      vector := TJSONObject(arrayValue.Items[i]);
      input := TJSONObject(LastField(vector, 'input'));
      expect := TJSONObject(LastField(vector, 'expect'));
      try
        paths := PraxoValidateSchema(LastField(input, 'schema'), LastField(input, 'data'));
      except
        on E: EPraxoSchema do
        begin
          Writeln('schema vector ', i, ': ', PraxoEncodeJSON(LastField(input, 'schema')));
          raise;
        end;
      end;
      valid := BoolField(expect, 'valid');
      Check((Length(paths) = 0) = valid, 'schema validity ' + IntToStr(i));
      if not valid then
        CheckPaths(paths, TJSONArray(LastField(expect, 'errorPaths')), 'schema vector ' + IntToStr(i));
    end;
  finally
    data.Free;
  end;
  schemaNode := PraxoParseJSON('{"type":"string","pattern":"^a+$"}');
  try
    expectedData := PraxoParseJSON('"a\n"');
    try
      paths := PraxoValidateSchema(schemaNode, expectedData);
      Check(Length(paths) = 1, 'pattern newline');
    finally
      expectedData.Free;
    end;
  finally
    schemaNode.Free;
  end;
  try
    schemaNode := PraxoParseJSON('{"pattern":"(a)"}');
    expectedData := PraxoParseJSON('"a"');
    try
      PraxoValidateSchema(schemaNode, expectedData);
      Check(False, 'unsupported pattern accepted');
    except
      on E: EPraxoSchema do ;
    end;
    schemaNode.Free;
    expectedData.Free;
  except
    ;
  end;
  Writeln('test_schema passed');
end;

procedure TestManifest;
var
  document, vector, input, expect: TJSONObject;
  data, manifestData: TJSONData;
  arrayValue: TJSONArray;
  manifest: TJSONObject;
  raw: UTF8String;
  valid: Boolean;
  i: Integer;
begin
  data := PraxoParseJSON(ReadTextFile(SpecRoot + '/vectors/plugin.json'));
  try
    arrayValue := TJSONArray(LastField(TJSONObject(data), 'vectors'));
    for i := 0 to arrayValue.Count - 1 do
    begin
      vector := TJSONObject(arrayValue.Items[i]);
      input := TJSONObject(LastField(vector, 'input'));
      expect := TJSONObject(LastField(vector, 'expect'));
      if LastField(input, 'raw') <> nil then
        raw := StringField(input, 'raw')
      else
        raw := PraxoEncodeJSON(LastField(input, 'manifest'));
      valid := PraxoValidateManifest(raw, manifest);
      Check(valid = BoolField(expect, 'valid'), 'manifest validity ' + IntToStr(i));
      if valid then
      begin
        if LastField(expect, 'id') <> nil then
          Check(manifest.Find('id').AsString = StringField(expect, 'id'), 'manifest id');
        if LastField(expect, 'kind') <> nil then
          Check(manifest.Find('kind').AsString = StringField(expect, 'kind'), 'manifest kind');
        manifest.Free;
      end;
    end;
  finally
    data.Free;
  end;
  Check(not PraxoValidateManifest('{} {}', manifest), 'trailing manifest');
  Check(not PraxoValidateManifest('', manifest), 'empty manifest');
  Writeln('test_manifest passed');
end;

begin
  if ParamCount >= 1 then
    SpecRoot := ParamStr(1)
  else
    SpecRoot := '../../spec';
  TestJSON;
  TestToolCall;
  TestSchema;
  TestManifest;
  Writeln('All declared Delphi wire vector groups passed');
end.
