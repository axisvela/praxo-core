unit praxo;
{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, StrUtils, Math, fpjson, jsonparser, RegExpr;

const
  PraxoSpecVersion = '0.2.0';
  PraxoSdkVersion = '0.1.0';

type
  EPraxoJSON = class(Exception);
  EPraxoSchema = class(Exception);
  EPraxoToolCall = class(Exception);
  TPraxoStringArray = array of UTF8String;
  TPraxoMetadata = record
    Operation: UTF8String;
    Resource: UTF8String;
    Risk: UTF8String;
    Reason: UTF8String;
    IdempotencyKey: UTF8String;
  end;
  TPraxoCall = record
    Name: UTF8String;
    Input: TJSONObject;
    Metadata: TPraxoMetadata;
  end;

function PraxoParseJSON(const Text: UTF8String): TJSONData;
function PraxoEncodeJSON(Data: TJSONData): UTF8String;
function PraxoParseToolCall(const Content: UTF8String; out Call: TPraxoCall): Boolean;
function PraxoStripToolCallMarkup(const Content: UTF8String): UTF8String;
function PraxoValidateSchema(Schema, Data: TJSONData): TPraxoStringArray;
function PraxoValidateManifest(const Raw: UTF8String; out Manifest: TJSONObject): Boolean;
function PraxoJSONEqual(A, B: TJSONData): Boolean;

implementation

const
  MaxJSONChars = 1048576;
  MaxToolCallChars = 262144;
  MaxDepth = 64;

function IsSpaceByte(b: Byte): Boolean; inline;
begin
  Result := (b = 32) or (b = 9) or (b = 10) or (b = 13);
end;

function TrimText(const S: UTF8String): UTF8String;
begin
  Result := Trim(S);
end;

function StrIn(const Value: UTF8String; const Choices: array of UTF8String): Boolean;
var
  i: Integer;
begin
  for i := Low(Choices) to High(Choices) do
    if Value = Choices[i] then
      Exit(True);
  Result := False;
end;

function MatchesRegex(const Value, Pattern: UTF8String): Boolean;
var
  regex: TRegExpr;
begin
  regex := TRegExpr.Create(Pattern);
  try
    Result := regex.Exec(Value);
  finally
    regex.Free;
  end;
end;

function UTF8CodePoints(const S: UTF8String; out Count: Integer): Boolean;
var
  i, n, extra, j, cp, minimum: Integer;
  b: Byte;
begin
  i := 1;
  n := Length(S);
  Count := 0;
  while i <= n do
  begin
    b := Ord(S[i]);
    if b < 128 then
    begin
      extra := 0;
      cp := b;
      minimum := 0;
    end
    else if (b >= 194) and (b <= 223) then
    begin
      extra := 1;
      cp := b - 192;
      minimum := 128;
    end
    else if (b >= 224) and (b <= 239) then
    begin
      extra := 2;
      cp := b - 224;
      minimum := 2048;
    end
    else if (b >= 240) and (b <= 244) then
    begin
      extra := 3;
      cp := b - 240;
      minimum := 65536;
    end
    else
      Exit(False);
    if i + extra > n then
      Exit(False);
    for j := 1 to extra do
    begin
      if (Ord(S[i + j]) and $C0) <> $80 then
        Exit(False);
      cp := cp * 64 + Ord(S[i + j]) - 128;
    end;
    if (cp < minimum) or (cp > 1114111) or ((cp >= 55296) and (cp <= 57343)) then
      Exit(False);
    Inc(Count);
    Inc(i, extra + 1);
  end;
  Result := True;
end;

procedure ValidateTree(Data: TJSONData; Depth: Integer);
var
  i: Integer;
  number: TJSONNumber;
begin
  if Depth > MaxDepth then
    raise EPraxoJSON.Create('JSON nesting exceeds capacity');
  if Data = nil then
    Exit;
  case Data.JSONType of
    jtObject:
      for i := 0 to TJSONObject(Data).Count - 1 do
        ValidateTree(TJSONObject(Data).Items[i], Depth + 1);
    jtArray:
      for i := 0 to TJSONArray(Data).Count - 1 do
        ValidateTree(TJSONArray(Data).Items[i], Depth + 1);
    jtNumber:
      begin
        number := TJSONNumber(Data);
        if IsNan(number.AsFloat) or IsInfinite(number.AsFloat) then
          raise EPraxoJSON.Create('JSON number is not finite');
      end;
  end;
end;

function HexDigitValue(c: Char): Integer;
begin
  case c of
    '0'..'9': Result := Ord(c) - Ord('0');
    'a'..'f': Result := Ord(c) - Ord('a') + 10;
    'A'..'F': Result := Ord(c) - Ord('A') + 10;
  else
    Result := -1;
  end;
end;

function ReadHex4(const Text: UTF8String; Index: Integer): Integer;
var
  i, digit: Integer;
begin
  Result := 0;
  for i := 0 to 3 do
  begin
    if Index + i > Length(Text) then
      raise EPraxoJSON.Create('Incomplete Unicode escape');
    digit := HexDigitValue(Text[Index + i]);
    if digit < 0 then
      raise EPraxoJSON.Create('Invalid Unicode escape');
    Result := Result * 16 + digit;
  end;
end;

procedure AppendCodePoint(var Output: UTF8String; CodePoint: Integer);
var
  bytes: array[0..3] of Byte;
  count, i: Integer;
begin
  if (CodePoint < 0) or (CodePoint > 1114111) or
    ((CodePoint >= 55296) and (CodePoint <= 57343)) then
    raise EPraxoJSON.Create('Invalid Unicode code point');
  if CodePoint < 128 then
  begin
    SetLength(Output, Length(Output) + 1);
    Output[Length(Output)] := Chr(CodePoint);
    Exit;
  end;
  if CodePoint < 2048 then
  begin
    count := 2;
    bytes[0] := 192 + CodePoint div 64;
  end
  else if CodePoint < 65536 then
  begin
    count := 3;
    bytes[0] := 224 + CodePoint div 4096;
  end
  else
  begin
    count := 4;
    bytes[0] := 240 + CodePoint div 262144;
  end;
  if count >= 2 then
    bytes[1] := 128 + (CodePoint div 64) mod 64;
  if count >= 3 then
    bytes[2] := 128 + (CodePoint div 4096) mod 64;
  if count = 4 then
    bytes[3] := 128 + (CodePoint div 262144) mod 8;
  if count = 3 then
    bytes[2] := 128 + (CodePoint div 4096) mod 64;
  if count = 4 then
  begin
    bytes[1] := 128 + (CodePoint div 4096) mod 64;
    bytes[2] := 128 + (CodePoint div 64) mod 64;
    bytes[3] := 128 + CodePoint mod 64;
  end;
  for i := 0 to count - 1 do
  begin
    SetLength(Output, Length(Output) + 1);
    Output[Length(Output)] := Chr(bytes[i]);
  end;
end;

function ExpandUnicodeEscapes(const Text: UTF8String): UTF8String;
var
  i, n, codePoint, low: Integer;
  inString: Boolean;
  c: Char;
begin
  Result := '';
  i := 1;
  n := Length(Text);
  inString := False;
  while i <= n do
  begin
    c := Text[i];
    if not inString then
    begin
      Result := Result + c;
      if c = '"' then
        inString := True;
      Inc(i);
      Continue;
    end;
    if c = '"' then
    begin
      inString := False;
      Result := Result + c;
      Inc(i);
      Continue;
    end;
    if c = '\' then
    begin
      if i = n then
        raise EPraxoJSON.Create('Incomplete escape');
      if Text[i + 1] = 'u' then
      begin
        codePoint := ReadHex4(Text, i + 2);
        if (codePoint >= 55296) and (codePoint <= 56319) then
        begin
          if (i + 11 > n) or (Text[i + 6] <> '\') or (Text[i + 7] <> 'u') then
            raise EPraxoJSON.Create('Missing low surrogate');
          low := ReadHex4(Text, i + 8);
          if (low < 56320) or (low > 57343) then
            raise EPraxoJSON.Create('Invalid low surrogate');
          codePoint := 65536 + (codePoint - 55296) * 1024 + low - 56320;
          Inc(i, 12);
        end
        else
        begin
          if (codePoint >= 56320) and (codePoint <= 57343) then
            raise EPraxoJSON.Create('Unexpected low surrogate');
          Inc(i, 6);
        end;
        AppendCodePoint(Result, codePoint);
        Continue;
      end;
      if Text[i + 1] = '"' then
      begin
        Result := Result + '\"';
        Inc(i, 2);
        Continue;
      end;
      Result := Result + c + Text[i + 1];
      Inc(i, 2);
      Continue;
    end;
    Result := Result + c;
    Inc(i);
  end;
end;

function ExtractFirstValue(const Text: UTF8String; out ValueText: UTF8String): Boolean;
var
  i, n, start, depth, finish: Integer;
  inString, escaped: Boolean;
  c: Char;
begin
  i := 1;
  n := Length(Text);
  while (i <= n) and IsSpaceByte(Ord(Text[i])) do
    Inc(i);
  if i > n then
    Exit(False);
  start := i;
  finish := 0;
  if (Text[i] = '{') or (Text[i] = '[') then
  begin
    depth := 0;
    inString := False;
    escaped := False;
    while i <= n do
    begin
      c := Text[i];
      if inString then
      begin
        if escaped then
          escaped := False
        else if c = '\' then
          escaped := True
        else if c = '"' then
          inString := False;
      end
      else if c = '"' then
        inString := True
      else if (c = '{') or (c = '[') then
        Inc(depth)
      else if (c = '}') or (c = ']') then
      begin
        Dec(depth);
        if depth = 0 then
        begin
          finish := i;
          Break;
        end;
      end;
      Inc(i);
    end;
  end
  else if Text[i] = '"' then
  begin
    inString := True;
    escaped := False;
    Inc(i);
    while i <= n do
    begin
      c := Text[i];
      if escaped then
        escaped := False
      else if c = '\' then
        escaped := True
      else if c = '"' then
      begin
        finish := i;
        Break;
      end;
      Inc(i);
    end;
  end
  else
  begin
    while (i <= n) and not IsSpaceByte(Ord(Text[i])) do
      Inc(i);
    finish := i - 1;
  end;
  if finish = 0 then
    Exit(False);
  ValueText := Copy(Text, start, finish - start + 1);
  Result := Trim(Copy(Text, finish + 1, MaxInt)) = '';
end;

function PraxoParseJSON(const Text: UTF8String): TJSONData;
var
  valueText, expanded: UTF8String;
  codePoints: Integer;
begin
  if Length(Text) > MaxJSONChars then
    raise EPraxoJSON.Create('JSON input exceeds capacity');
  expanded := ExpandUnicodeEscapes(Text);
  if not UTF8CodePoints(expanded, codePoints) then
    raise EPraxoJSON.Create('Invalid UTF-8 string');
  if not ExtractFirstValue(expanded, valueText) then
    raise EPraxoJSON.Create('Invalid JSON or trailing content');
  try
    Result := GetJSON(valueText);
  except
    on E: Exception do
      raise EPraxoJSON.Create('Invalid JSON: ' + E.Message);
  end;
  try
    ValidateTree(Result, 0);
  except
    Result.Free;
    raise;
  end;
end;

function PraxoEncodeJSON(Data: TJSONData): UTF8String;
begin
  ValidateTree(Data, 0);
  Result := Data.AsJSON;
  if Length(Result) > MaxJSONChars then
    raise EPraxoJSON.Create('JSON output exceeds capacity');
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

function FieldCount(ObjectValue: TJSONObject; const Name: UTF8String): Integer;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to ObjectValue.Count - 1 do
    if ObjectValue.Names[i] = Name then
      Inc(Result);
end;

function FieldString(ObjectValue: TJSONObject; const Name: UTF8String; out Value: UTF8String): Boolean;
var
  data: TJSONData;
begin
  data := LastField(ObjectValue, Name);
  Result := (data <> nil) and (data.JSONType = jtString);
  if Result then
    Value := TJSONString(data).AsString
  else
    Value := '';
end;

function TryParseObject(const Text: UTF8String; out ObjectValue: TJSONObject): Boolean;
var
  data: TJSONData;
begin
  ObjectValue := nil;
  try
    data := PraxoParseJSON(Text);
  except
    Exit(False);
  end;
  if data.JSONType = jtObject then
  begin
    ObjectValue := TJSONObject(data);
    Result := True;
  end
  else
  begin
    data.Free;
    Result := False;
  end;
end;

function ValidDottedName(const Name: UTF8String): Boolean;
var
  i: Integer;
  c: Char;
begin
  Result := False;
  if (Length(Name) < 3) or (Pos('.', Name) = 0) or (Name[1] = '.') or (Name[Length(Name)] = '.') then
    Exit;
  for i := 1 to Length(Name) do
  begin
    c := Name[i];
    if not (((c >= 'a') and (c <= 'z')) or ((c >= 'A') and (c <= 'Z')) or
      ((c >= '0') and (c <= '9')) or (c = '_') or (c = '.') or (c = '-')) then
      Exit;
  end;
  Result := True;
end;

procedure InitMetadata(out Metadata: TPraxoMetadata);
begin
  Metadata.Operation := '';
  Metadata.Resource := '';
  Metadata.Risk := '';
  Metadata.Reason := '';
  Metadata.IdempotencyKey := '';
end;

function MetadataFromObject(ObjectValue: TJSONObject; out Metadata: TPraxoMetadata): Boolean;
var
  names: array[0..4] of UTF8String;
  targets: array[0..4] of ^UTF8String;
  data: TJSONData;
  i: Integer;
begin
  InitMetadata(Metadata);
  names[0] := 'operation'; targets[0] := @Metadata.Operation;
  names[1] := 'resource'; targets[1] := @Metadata.Resource;
  names[2] := 'risk'; targets[2] := @Metadata.Risk;
  names[3] := 'reason'; targets[3] := @Metadata.Reason;
  names[4] := 'idempotency_key'; targets[4] := @Metadata.IdempotencyKey;
  Result := True;
  for i := 0 to 4 do
  begin
    data := LastField(ObjectValue, names[i]);
    if data = nil then
      Continue;
    if data.JSONType = jtString then
      targets[i]^ := TJSONString(data).AsString
    else if data.JSONType <> jtNull then
      Exit(False);
  end;
end;

function CallFromObject(ObjectValue: TJSONObject; out Call: TPraxoCall): Boolean;
var
  name: UTF8String;
  input: TJSONData;
  empty: TJSONObject;
begin
  Result := False;
  if not FieldString(ObjectValue, 'name', name) or (name = '') then
    Exit;
  if not MetadataFromObject(ObjectValue, Call.Metadata) then
    Exit;
  input := LastField(ObjectValue, 'input');
  if (input = nil) or (input.JSONType = jtNull) then
  begin
    empty := TJSONObject.Create;
    Call.Input := empty;
  end
  else if input.JSONType = jtObject then
    Call.Input := TJSONObject(input.Clone)
  else
    Exit;
  Call.Name := name;
  Result := True;
end;

function FindText(const Haystack, Needle: UTF8String; StartAt: Integer): Integer;
begin
  Result := Pos(Needle, Copy(Haystack, StartAt, MaxInt));
  if Result > 0 then
    Inc(Result, StartAt - 1);
end;

function ParseXMLBlock(const Content: UTF8String; out Call: TPraxoCall): Boolean;
var
  searchAt, openPos, headerEnd, closePos, nameStart, nameEnd: Integer;
  header, name, lastName, lastBody: UTF8String;
  found: Boolean;
begin
  Result := False;
  found := False;
  searchAt := 1;
  lastName := '';
  lastBody := '';
  while True do
  begin
    openPos := FindText(Content, '<tool_call', searchAt);
    if openPos = 0 then
      Break;
    headerEnd := FindText(Content, '>', openPos + 10);
    if headerEnd = 0 then
      Break;
    header := Copy(Content, openPos + 10, headerEnd - openPos - 10);
    nameStart := FindText(header, 'name="', 1);
    if nameStart = 0 then
    begin
      searchAt := headerEnd + 1;
      Continue;
    end;
    name := Copy(header, nameStart + 6, MaxInt);
    nameEnd := Pos('"', name);
    if (nameEnd = 0) or (Copy(name, 1, nameEnd - 1) = '') then
      Break;
    name := Copy(name, 1, nameEnd - 1);
    closePos := FindText(Content, '</tool_call>', headerEnd + 1);
    if closePos = 0 then
      Break;
    lastName := name;
    lastBody := Copy(Content, headerEnd + 1, closePos - headerEnd - 1);
    found := True;
    searchAt := closePos + Length('</tool_call>');
  end;
  if not found then
    Exit;
  if TryParseObject(lastBody, Call.Input) then
  begin
    Call.Name := lastName;
    InitMetadata(Call.Metadata);
    Result := True;
  end;
end;

function ParseTagBlock(const Content: UTF8String; out Call: TPraxoCall): Boolean;
var
  searchAt, openPos, headerEnd, closePos: Integer;
  name, lastName, lastBody: UTF8String;
  found: Boolean;
begin
  Result := False;
  found := False;
  searchAt := 1;
  lastName := '';
  lastBody := '';
  while True do
  begin
    openPos := FindText(Content, '<', searchAt);
    if openPos = 0 then
      Break;
    headerEnd := FindText(Content, '>', openPos + 1);
    if headerEnd = 0 then
      Break;
    name := Copy(Content, openPos + 1, headerEnd - openPos - 1);
    if ValidDottedName(name) then
    begin
      closePos := FindText(Content, '</' + name + '>', headerEnd + 1);
      if closePos = 0 then
        Break;
      lastName := name;
      lastBody := Copy(Content, headerEnd + 1, closePos - headerEnd - 1);
      found := True;
      searchAt := closePos + Length('</' + name + '>');
    end
    else
      searchAt := headerEnd + 1;
  end;
  if not found then
    Exit;
  if TryParseObject(lastBody, Call.Input) then
  begin
    Call.Name := lastName;
    InitMetadata(Call.Metadata);
    Result := True;
  end;
end;

function ParsePlainLine(const Content: UTF8String; out Call: TPraxoCall): Boolean;
var
  lines: TPraxoStringArray;
  i, startPos, endPos, spacePos: Integer;
  line, name, body: UTF8String;
begin
  Result := False;
  SetLength(lines, 0);
  startPos := 1;
  while startPos <= Length(Content) + 1 do
  begin
    endPos := startPos;
    while (endPos <= Length(Content)) and (Content[endPos] <> #10) do
      Inc(endPos);
    line := Copy(Content, startPos, endPos - startPos);
    if (Length(line) > 0) and (line[Length(line)] = #13) then
      SetLength(line, Length(line) - 1);
    SetLength(lines, Length(lines) + 1);
    lines[High(lines)] := line;
    if endPos > Length(Content) then
      Break;
    startPos := endPos + 1;
  end;
  for i := High(lines) downto 0 do
  begin
    line := Trim(lines[i]);
    if line = '' then
      Continue;
    spacePos := Pos(' ', line);
    if spacePos = 0 then
      Continue;
    name := Copy(line, 1, spacePos - 1);
    body := Trim(Copy(line, spacePos + 1, MaxInt));
    if not ValidDottedName(name) then
      Continue;
    if (Length(body) < 2) or (body[1] <> '{') or (body[Length(body)] <> '}') then
      Exit;
    if TryParseObject(body, Call.Input) then
    begin
      Call.Name := name;
      InitMetadata(Call.Metadata);
      Result := True;
    end;
    Exit;
  end;
end;

function PraxoParseToolCall(const Content: UTF8String; out Call: TPraxoCall): Boolean;
var
  data: TJSONData;
  objectValue: TJSONObject;
begin
  Result := False;
  if Length(Content) > MaxToolCallChars then
    raise EPraxoToolCall.Create('Content exceeds capacity');
  try
    data := PraxoParseJSON(Content);
  except
    data := nil;
  end;
  if data <> nil then
  begin
    if data.JSONType = jtObject then
    begin
      objectValue := TJSONObject(data);
      Result := CallFromObject(objectValue, Call);
      data.Free;
      Exit;
    end;
    data.Free;
    Exit;
  end;
  if ParseXMLBlock(Content, Call) then
    Exit(True);
  if Pos('<tool_call', Content) > 0 then
    Exit(False);
  if ParseTagBlock(Content, Call) then
    Exit(True);
  if Pos('</', Content) > 0 then
    Exit(False);
  Result := ParsePlainLine(Content, Call);
end;

function StripBlocks(const Content, OpenPrefix, CloseTag: UTF8String): UTF8String;
var
  searchAt, openPos, headerEnd, closePos: Integer;
begin
  Result := Content;
  searchAt := 1;
  while True do
  begin
    openPos := FindText(Result, OpenPrefix, searchAt);
    if openPos = 0 then
      Exit;
    headerEnd := FindText(Result, '>', openPos + Length(OpenPrefix));
    if headerEnd = 0 then
      Exit;
    if CloseTag <> '' then
    begin
      closePos := FindText(Result, CloseTag, headerEnd + 1);
      if closePos = 0 then
      begin
        Delete(Result, openPos, Length(Result) - openPos + 1);
        Exit;
      end;
      closePos := closePos + Length(CloseTag);
    end
    else
    begin
      closePos := FindText(Result, '</', headerEnd + 1);
      if closePos = 0 then
      begin
        Delete(Result, openPos, Length(Result) - openPos + 1);
        Exit;
      end;
      closePos := FindText(Result, '>', closePos + 2);
      if closePos = 0 then
      begin
        Delete(Result, openPos, Length(Result) - openPos + 1);
        Exit;
      end;
      closePos := closePos + 1;
    end;
    Delete(Result, openPos, closePos - openPos);
    searchAt := openPos;
  end;
end;

function StripDottedBlocks(const Content: UTF8String): UTF8String;
var
  searchAt, openPos, headerEnd, closePos: Integer;
  name: UTF8String;
begin
  Result := Content;
  searchAt := 1;
  while True do
  begin
    openPos := FindText(Result, '<', searchAt);
    if openPos = 0 then
      Exit;
    headerEnd := FindText(Result, '>', openPos + 1);
    if headerEnd = 0 then
      Exit;
    name := Copy(Result, openPos + 1, headerEnd - openPos - 1);
    if ValidDottedName(name) then
    begin
      closePos := FindText(Result, '</' + name + '>', headerEnd + 1);
      if closePos = 0 then
      begin
        Delete(Result, openPos, Length(Result) - openPos + 1);
        Exit;
      end;
      Delete(Result, openPos, closePos - openPos + Length('</' + name + '>'));
      searchAt := openPos;
    end
    else
      searchAt := headerEnd + 1;
  end;
end;

function PraxoStripToolCallMarkup(const Content: UTF8String): UTF8String;
begin
  if Length(Content) > MaxToolCallChars then
    raise EPraxoToolCall.Create('Content exceeds capacity');
  Result := StripBlocks(Content, '<tool_call', '</tool_call>');
  Result := StripDottedBlocks(Result);
  Result := StringReplace(Result, #10#10#10, #10#10, [rfReplaceAll]);
  Result := Trim(Result);
end;

function JsonEqual(A, B: TJSONData): Boolean;
var
  i, j: Integer;
  found: Boolean;
begin
  if (A = nil) or (B = nil) then
    Exit(A = B);
  if A.JSONType <> B.JSONType then
  begin
    if (A.JSONType = jtNumber) and (B.JSONType = jtNumber) then
      Exit(TJSONNumber(A).AsFloat = TJSONNumber(B).AsFloat);
    Exit(False);
  end;
  case A.JSONType of
    jtNull: Result := True;
    jtBoolean: Result := A.AsBoolean = B.AsBoolean;
    jtString: Result := TJSONString(A).AsString = TJSONString(B).AsString;
    jtNumber: Result := TJSONNumber(A).AsFloat = TJSONNumber(B).AsFloat;
    jtArray:
      begin
        if TJSONArray(A).Count <> TJSONArray(B).Count then
          Exit(False);
        for i := 0 to TJSONArray(A).Count - 1 do
          if not JsonEqual(TJSONArray(A).Items[i], TJSONArray(B).Items[i]) then
            Exit(False);
        Result := True;
      end;
    jtObject:
      begin
        if TJSONObject(A).Count <> TJSONObject(B).Count then
          Exit(False);
        for i := 0 to TJSONObject(A).Count - 1 do
        begin
          found := False;
          for j := 0 to TJSONObject(B).Count - 1 do
            if TJSONObject(A).Names[i] = TJSONObject(B).Names[j] then
            begin
              if not JsonEqual(TJSONObject(A).Items[i], TJSONObject(B).Items[j]) then
                Exit(False);
              found := True;
              Break;
            end;
          if not found then
            Exit(False);
        end;
        Result := True;
      end;
  else
    Result := False;
  end;
end;

function PatternSupported(const Pattern: UTF8String): Boolean;
var
  i: Integer;
  c: Char;
begin
  Result := False;
  if (Length(Pattern) < 2) or (Pattern[1] <> '^') or (Pattern[Length(Pattern)] <> '$') then
    Exit;
  for i := 1 to Length(Pattern) do
  begin
    c := Pattern[i];
    if (Ord(c) < 32) or (Ord(c) > 126) then
      Exit;
    if (c = '(') or (c = ')') or (c = '{') or (c = '}') or (c = '|') then
      Exit;
    if (c = '\') and (i < Length(Pattern)) and (Pattern[i + 1] in ['1'..'9']) then
      Exit;
  end;
  Result := True;
end;

function PatternMatches(const Pattern, Value: UTF8String): Boolean;
var
  regex: TRegExpr;
begin
  if Value = '' then
    Exit(False);
  regex := TRegExpr.Create(Pattern);
  try
    Result := regex.Exec(Value) and (regex.MatchPos[0] = 1) and
      (regex.MatchLen[0] = Length(Value));
  finally
    regex.Free;
  end;
end;

procedure AddPath(var Paths: TPraxoStringArray; const Path: UTF8String);
begin
  SetLength(Paths, Length(Paths) + 1);
  Paths[High(Paths)] := Path;
end;

procedure CheckSchemaShape(Schema: TJSONData; Depth: Integer);
var
  objectValue: TJSONObject;
  data: TJSONData;
  i: Integer;
  text: UTF8String;
begin
  if Depth > MaxDepth then
    raise EPraxoSchema.Create('Schema nesting exceeds capacity');
  if (Schema = nil) or (Schema.JSONType <> jtObject) then
    raise EPraxoSchema.Create('Schema must be an object');
  objectValue := TJSONObject(Schema);
  data := LastField(objectValue, 'type');
  if data <> nil then
  begin
    if (data.JSONType <> jtString) or not StrIn(TJSONString(data).AsString,
      ['', 'object', 'array', 'string', 'number', 'integer', 'boolean']) then
      raise EPraxoSchema.Create('Invalid schema type');
  end;
  data := LastField(objectValue, 'properties');
  if data <> nil then
  begin
    if data.JSONType <> jtObject then
      raise EPraxoSchema.Create('Invalid properties');
    for i := 0 to TJSONObject(data).Count - 1 do
      CheckSchemaShape(TJSONObject(data).Items[i], Depth + 1);
  end;
  data := LastField(objectValue, 'items');
  if data <> nil then
    CheckSchemaShape(data, Depth + 1);
  data := LastField(objectValue, 'required');
  if data <> nil then
  begin
    if data.JSONType <> jtArray then
      raise EPraxoSchema.Create('Invalid required');
    for i := 0 to TJSONArray(data).Count - 1 do
      if TJSONArray(data).Items[i].JSONType <> jtString then
        raise EPraxoSchema.Create('Invalid required');
  end;
  data := LastField(objectValue, 'enum');
  if (data <> nil) and (data.JSONType <> jtArray) then
    raise EPraxoSchema.Create('Invalid enum');
  for text in ['minLength', 'maxLength'] do
  begin
    data := LastField(objectValue, text);
    if data <> nil then
    begin
      if (data.JSONType <> jtNumber) or (TJSONNumber(data).NumberType <> ntInteger) or
        (TJSONNumber(data).AsInt64 < 0) then
        raise EPraxoSchema.Create('Invalid length');
    end;
  end;
  for text in ['minimum', 'maximum'] do
  begin
    data := LastField(objectValue, text);
    if (data <> nil) and (data.JSONType <> jtNumber) then
      raise EPraxoSchema.Create('Invalid bound');
  end;
  data := LastField(objectValue, 'pattern');
  if data <> nil then
  begin
    if data.JSONType <> jtString then
      raise EPraxoSchema.Create('Invalid pattern');
    if not PatternSupported(TJSONString(data).AsString) then
      raise EPraxoSchema.Create('Unsupported pattern');
  end;
  data := LastField(objectValue, 'description');
  if (data <> nil) and (data.JSONType <> jtString) then
    raise EPraxoSchema.Create('Invalid description');
end;

procedure ValidateNode(Schema, Data: TJSONData; const Path: UTF8String; Depth: Integer;
  var Paths: TPraxoStringArray);
var
  objectValue, dataObject, properties: TJSONObject;
  schemaType, key, pattern: UTF8String;
  typeData, keyword: TJSONData;
  i, j, codePoints: Integer;
  matched, found: Boolean;
  number: TJSONNumber;
  text: UTF8String;
begin
  if Depth > MaxDepth then
    raise EPraxoSchema.Create('Schema nesting exceeds capacity');
  if (Schema = nil) or (Schema.JSONType <> jtObject) then
    raise EPraxoSchema.Create('Schema must be an object');
  objectValue := TJSONObject(Schema);
  typeData := LastField(objectValue, 'type');
  schemaType := '';
  if typeData <> nil then
    schemaType := TJSONString(typeData).AsString;
  if Data.JSONType = jtNull then
  begin
    if schemaType <> '' then
      AddPath(Paths, Path);
    Exit;
  end;
  if schemaType = '' then
    Exit;
  if schemaType = 'object' then
  begin
    if Data.JSONType <> jtObject then
    begin
      AddPath(Paths, Path);
      Exit;
    end;
    dataObject := TJSONObject(Data);
    keyword := LastField(objectValue, 'required');
    if keyword <> nil then
      for i := 0 to TJSONArray(keyword).Count - 1 do
      begin
        key := TJSONString(TJSONArray(keyword).Items[i]).AsString;
        if LastField(dataObject, key) = nil then
          AddPath(Paths, Path + '.' + key);
      end;
    properties := nil;
    keyword := LastField(objectValue, 'properties');
    if keyword <> nil then
      properties := TJSONObject(keyword);
    if properties <> nil then
      for i := 0 to properties.Count - 1 do
      begin
        key := properties.Names[i];
        keyword := LastField(dataObject, key);
        if keyword <> nil then
          ValidateNode(properties.Items[i], keyword, Path + '.' + key, Depth + 1, Paths);
      end;
  end
  else if schemaType = 'array' then
  begin
    if Data.JSONType <> jtArray then
    begin
      AddPath(Paths, Path);
      Exit;
    end;
    keyword := LastField(objectValue, 'items');
    if keyword <> nil then
      for i := 0 to TJSONArray(Data).Count - 1 do
        ValidateNode(keyword, TJSONArray(Data).Items[i], Path + '[' + IntToStr(i) + ']', Depth + 1, Paths);
  end
  else if schemaType = 'string' then
  begin
    if Data.JSONType <> jtString then
    begin
      AddPath(Paths, Path);
      Exit;
    end;
    text := TJSONString(Data).AsString;
    if not UTF8CodePoints(text, codePoints) then
      raise EPraxoSchema.Create('Invalid UTF-8 data');
    keyword := LastField(objectValue, 'minLength');
    if (keyword <> nil) and (TJSONNumber(keyword).AsInt64 > 0) and (codePoints < TJSONNumber(keyword).AsInt64) then
      AddPath(Paths, Path);
    keyword := LastField(objectValue, 'maxLength');
    if (keyword <> nil) and (TJSONNumber(keyword).AsInt64 > 0) and (codePoints > TJSONNumber(keyword).AsInt64) then
      AddPath(Paths, Path);
    keyword := LastField(objectValue, 'pattern');
    if keyword <> nil then
    begin
      pattern := TJSONString(keyword).AsString;
      if not PatternMatches(pattern, text) then
        AddPath(Paths, Path);
    end;
    keyword := LastField(objectValue, 'enum');
    if keyword <> nil then
    begin
      matched := False;
      for i := 0 to TJSONArray(keyword).Count - 1 do
        if JsonEqual(TJSONArray(keyword).Items[i], Data) then
        begin
          matched := True;
          Break;
        end;
      if not matched then
        AddPath(Paths, Path);
    end;
  end
  else if (schemaType = 'number') or (schemaType = 'integer') then
  begin
    if Data.JSONType <> jtNumber then
    begin
      AddPath(Paths, Path);
      Exit;
    end;
    number := TJSONNumber(Data);
    if (schemaType = 'integer') and (Trunc(number.AsFloat) <> number.AsFloat) then
    begin
      AddPath(Paths, Path);
      Exit;
    end;
    keyword := LastField(objectValue, 'enum');
    if keyword <> nil then
    begin
      matched := False;
      for i := 0 to TJSONArray(keyword).Count - 1 do
        if JsonEqual(TJSONArray(keyword).Items[i], Data) then
        begin
          matched := True;
          Break;
        end;
      if not matched then
        AddPath(Paths, Path);
    end;
    keyword := LastField(objectValue, 'minimum');
    if (keyword <> nil) and (TJSONNumber(keyword).AsFloat <> 0) and
      (number.AsFloat < TJSONNumber(keyword).AsFloat) then
      AddPath(Paths, Path);
    keyword := LastField(objectValue, 'maximum');
    if (keyword <> nil) and (TJSONNumber(keyword).AsFloat <> 0) and
      (number.AsFloat > TJSONNumber(keyword).AsFloat) then
      AddPath(Paths, Path);
  end
  else if schemaType = 'boolean' then
  begin
    if Data.JSONType <> jtBoolean then
    begin
      AddPath(Paths, Path);
      Exit;
    end;
    keyword := LastField(objectValue, 'enum');
    if keyword <> nil then
    begin
      matched := False;
      for i := 0 to TJSONArray(keyword).Count - 1 do
        if JsonEqual(TJSONArray(keyword).Items[i], Data) then
        begin
          matched := True;
          Break;
        end;
      if not matched then
        AddPath(Paths, Path);
    end;
  end;
  found := False;
  for i := 0 to objectValue.Count - 1 do
    if objectValue.Names[i] = 'type' then
      found := True;
  if not found then
    Exit;
end;

function PraxoValidateSchema(Schema, Data: TJSONData): TPraxoStringArray;
begin
  SetLength(Result, 0);
  CheckSchemaShape(Schema, 0);
  ValidateNode(Schema, Data, '$', 0, Result);
end;

function ValidEnvName(const Value: UTF8String): Boolean;
var
  i: Integer;
  c: Char;
begin
  Result := False;
  if Value = '' then
    Exit;
  c := Value[1];
  if not (((c >= 'A') and (c <= 'Z')) or ((c >= 'a') and (c <= 'z')) or (c = '_')) then
    Exit;
  for i := 2 to Length(Value) do
  begin
    c := Value[i];
    if not (((c >= 'A') and (c <= 'Z')) or ((c >= 'a') and (c <= 'z')) or
      ((c >= '0') and (c <= '9')) or (c = '_')) then
      Exit;
  end;
  Result := True;
end;

function RelativePath(const Value: UTF8String): Boolean;
var
  normalized: UTF8String;
  i, segmentStart: Integer;
begin
  Result := False;
  if (Value = '') or (Value[1] = '/') or (Value[1] = '\') then
    Exit;
  if (Length(Value) >= 2) and (Value[2] = ':') then
    Exit;
  normalized := StringReplace(Value, '\', '/', [rfReplaceAll]);
  segmentStart := 1;
  for i := 1 to Length(normalized) + 1 do
    if (i > Length(normalized)) or (normalized[i] = '/') then
    begin
      if Copy(normalized, segmentStart, i - segmentStart) = '..' then
        Exit;
      segmentStart := i + 1;
    end;
  Result := True;
end;

function HasOnlyFields(ObjectValue: TJSONObject; const Allowed: array of UTF8String; Required: Boolean): Boolean;
var
  i, j: Integer;
  found: Boolean;
begin
  Result := False;
  for i := 0 to ObjectValue.Count - 1 do
  begin
    found := False;
    for j := Low(Allowed) to High(Allowed) do
      if ObjectValue.Names[i] = Allowed[j] then
      begin
        found := True;
        Break;
      end;
    if not found then
      Exit;
    if FieldCount(ObjectValue, ObjectValue.Names[i]) > 1 then
      Exit;
  end;
  if Required then
    for j := Low(Allowed) to High(Allowed) do
      if FieldCount(ObjectValue, Allowed[j]) = 0 then
        Exit;
  Result := True;
end;

function ManifestInteger(ObjectValue: TJSONObject; const Name: UTF8String; out Value: Int64): Boolean;
var
  data: TJSONData;
begin
  data := LastField(ObjectValue, Name);
  Result := (data <> nil) and (data.JSONType = jtNumber) and
    (TJSONNumber(data).NumberType = ntInteger);
  if Result then
    Value := TJSONNumber(data).AsInt64
  else
    Value := 0;
end;

function ManifestString(ObjectValue: TJSONObject; const Name: UTF8String; out Value: UTF8String): Boolean;
begin
  Result := FieldString(ObjectValue, Name, Value) and (Value <> '');
end;

function ValidatePermissions(Permissions: TJSONObject): Boolean;
var
  data, item: TJSONData;
  i: Integer;
  objectValue: TJSONObject;
  path, mode, host, env: UTF8String;
  port: Int64;
begin
  Result := False;
  if not HasOnlyFields(Permissions, ['filesystem', 'network', 'env'], False) then
    Exit;
  data := LastField(Permissions, 'filesystem');
  if data <> nil then
  begin
    if data.JSONType <> jtArray then
      Exit;
    for i := 0 to TJSONArray(data).Count - 1 do
    begin
      item := TJSONArray(data).Items[i];
      if item.JSONType <> jtObject then
        Exit;
      objectValue := TJSONObject(item);
      if not HasOnlyFields(objectValue, ['path', 'mode'], True) then
        Exit;
      if not ManifestString(objectValue, 'path', path) then
        Exit;
      if not RelativePath(path) then
        Exit;
      if not ManifestString(objectValue, 'mode', mode) then
        Exit;
      if not StrIn(mode, ['read', 'write', 'readwrite']) then
        Exit;
    end;
  end;
  data := LastField(Permissions, 'network');
  if data <> nil then
  begin
    if data.JSONType <> jtArray then
      Exit;
    for i := 0 to TJSONArray(data).Count - 1 do
    begin
      item := TJSONArray(data).Items[i];
      if item.JSONType <> jtObject then
        Exit;
      objectValue := TJSONObject(item);
      if not HasOnlyFields(objectValue, ['host', 'port'], True) then
        Exit;
      if not ManifestString(objectValue, 'host', host) then
        Exit;
      if not ManifestInteger(objectValue, 'port', port) then
        Exit;
      if (port < 1) or (port > 65535) then
        Exit;
    end;
  end;
  data := LastField(Permissions, 'env');
  if data <> nil then
  begin
    if data.JSONType <> jtArray then
      Exit;
    for i := 0 to TJSONArray(data).Count - 1 do
    begin
      if TJSONArray(data).Items[i].JSONType <> jtString then
        Exit;
      env := TJSONString(TJSONArray(data).Items[i]).AsString;
      if not ValidEnvName(env) then
        Exit;
    end;
  end;
  Result := True;
end;

function ValidateManifestObject(Manifest: TJSONObject): Boolean;
var
  data: TJSONData;
  i: Integer;
  id, version, kind, protocol, isolation, value, method, sbom: UTF8String;
  entry: TJSONObject;
  entryType, required: UTF8String;
  permissions: TJSONObject;
  caps: TStringList;
  interval, number: Int64;
  fields: array[0..12] of UTF8String;
  requirements: array[0..10] of UTF8String;
  entryFields: array[0..3] of UTF8String;
  limitFields: array[0..3] of UTF8String;
begin
  Result := False;
  fields[0] := 'schemaVersion'; fields[1] := 'id'; fields[2] := 'version';
  fields[3] := 'kind'; fields[4] := 'entrypoint'; fields[5] := 'protocol';
  fields[6] := 'capabilities'; fields[7] := 'permissions'; fields[8] := 'limits';
  fields[9] := 'isolation'; fields[10] := 'health'; fields[11] := 'signature';
  fields[12] := 'sbom';
  if not HasOnlyFields(Manifest, fields, False) then
    Exit;
  requirements[0] := 'schemaVersion'; requirements[1] := 'id'; requirements[2] := 'version';
  requirements[3] := 'kind'; requirements[4] := 'entrypoint'; requirements[5] := 'protocol';
  requirements[6] := 'capabilities'; requirements[7] := 'permissions'; requirements[8] := 'limits';
  requirements[9] := 'health'; requirements[10] := 'isolation';
  for i := 0 to 10 do
    if LastField(Manifest, requirements[i]) = nil then
      Exit;
  if not ManifestInteger(Manifest, 'schemaVersion', number) or (number <> 1) then
    Exit;
  if not ManifestString(Manifest, 'id', id) then
    Exit;
  if not MatchesRegex(id, '^([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z0-9]([a-z0-9-]*[a-z0-9])?$') then
    Exit;
  if not ManifestString(Manifest, 'version', version) then
    Exit;
  if not MatchesRegex(version, '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$') then
    Exit;
  if not ManifestString(Manifest, 'kind', kind) then
    Exit;
  if not StrIn(kind, ['tool.provider.v1', 'model.provider.v1', 'policy.provider.v1',
    'memory.provider.v1', 'sandbox.provider.v1']) then
    Exit;
  if not ManifestString(Manifest, 'protocol', protocol) or (protocol <> 'jsonrpc-2') then
    Exit;
  data := LastField(Manifest, 'entrypoint');
  if (data = nil) or (data.JSONType <> jtObject) then
    Exit;
  entry := TJSONObject(data);
  if not HasOnlyFields(entry, ['type', 'command', 'module', 'image', 'args', 'dir'], False) then
    Exit;
  if not ManifestString(entry, 'type', entryType) then
    Exit;
  if not StrIn(entryType, ['process', 'wasm', 'container']) then
    Exit;
  if entryType = 'process' then
    required := 'command'
  else if entryType = 'wasm' then
    required := 'module'
  else
    required := 'image';
  if not ManifestString(entry, required, value) then
    Exit;
  entryFields[0] := 'command';
  entryFields[1] := 'module';
  entryFields[2] := 'image';
  entryFields[3] := 'dir';
  for i := 0 to 3 do
    if LastField(entry, entryFields[i]) <> nil then
      if not ManifestString(entry, entryFields[i], value) then
        Exit;
  data := LastField(entry, 'args');
  if data <> nil then
  begin
    if data.JSONType <> jtArray then
      Exit;
    for i := 0 to TJSONArray(data).Count - 1 do
      if TJSONArray(data).Items[i].JSONType <> jtString then
        Exit;
  end;
  if not ManifestString(Manifest, 'isolation', isolation) or (isolation <> entryType) then
    Exit;
  data := LastField(Manifest, 'capabilities');
  if (data = nil) or (data.JSONType <> jtArray) then
    Exit;
  caps := TStringList.Create;
  try
    for i := 0 to TJSONArray(data).Count - 1 do
    begin
      if TJSONArray(data).Items[i].JSONType <> jtString then
        Exit;
      value := TJSONString(TJSONArray(data).Items[i]).AsString;
      if value = '' then
        Exit;
      if caps.IndexOf(value) >= 0 then
        Exit;
      caps.Add(value);
    end;
  finally
    caps.Free;
  end;
  data := LastField(Manifest, 'permissions');
  if (data = nil) or (data.JSONType <> jtObject) then
    Exit;
  permissions := TJSONObject(data);
  if not ValidatePermissions(permissions) then
    Exit;
  data := LastField(Manifest, 'limits');
  if (data = nil) or (data.JSONType <> jtObject) then
    Exit;
  limitFields[0] := 'memoryMB';
  limitFields[1] := 'cpuMillis';
  limitFields[2] := 'timeoutMs';
  limitFields[3] := 'maxInflight';
  if not HasOnlyFields(TJSONObject(data), limitFields, False) then
    Exit;
  for i := 0 to 3 do
    if LastField(TJSONObject(data), limitFields[i]) <> nil then
    begin
      if not ManifestInteger(TJSONObject(data), limitFields[i], number) or (number < 0) then
        Exit;
    end;
  data := LastField(Manifest, 'health');
  if (data = nil) or (data.JSONType <> jtObject) then
    Exit;
  if not HasOnlyFields(TJSONObject(data), ['method', 'intervalMs'], False) then
    Exit;
  method := '';
  if LastField(TJSONObject(data), 'method') <> nil then
    if not FieldString(TJSONObject(data), 'method', method) then
      Exit;
  interval := 0;
  if LastField(TJSONObject(data), 'intervalMs') <> nil then
  begin
    if not ManifestInteger(TJSONObject(data), 'intervalMs', interval) or (interval < 0) then
      Exit;
    if (interval > 0) and (method = '') then
      Exit;
  end;
  data := LastField(Manifest, 'signature');
  if data <> nil then
  begin
    if data.JSONType <> jtObject then
      Exit;
    if not HasOnlyFields(TJSONObject(data), ['algorithm', 'keyId'], True) then
      Exit;
    if not ManifestString(TJSONObject(data), 'algorithm', value) then
      Exit;
    if not ManifestString(TJSONObject(data), 'keyId', value) then
      Exit;
  end;
  data := LastField(Manifest, 'sbom');
  if data <> nil then
  begin
    if data.JSONType <> jtString then
      Exit;
    sbom := TJSONString(data).AsString;
    if (sbom <> '') and not RelativePath(sbom) then
      Exit;
  end;
  Result := True;
end;

function PraxoJSONEqual(A, B: TJSONData): Boolean;
begin
  Result := JsonEqual(A, B);
end;

function PraxoValidateManifest(const Raw: UTF8String; out Manifest: TJSONObject): Boolean;
var
  data: TJSONData;
begin
  Manifest := nil;
  Result := False;
  try
    data := PraxoParseJSON(Raw);
  except
    Exit(False);
  end;
  try
    if data.JSONType <> jtObject then
      Exit;
    Manifest := TJSONObject(data);
    Result := ValidateManifestObject(Manifest);
  except
    Result := False;
  end;
end;

end.
