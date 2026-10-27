unit praxo_core;
{$mode objfpc}{$H+}

interface

uses SysUtils, Classes, RegExpr, fpjson, praxo;

type
  TPraxoStringArray = array of UTF8String;
  TPraxoStringArrays = array of TPraxoStringArray;

  TPraxoMemoryRecord = record
    Id, Frame, Content, CreatedAt: UTF8String;
  end;
  TPraxoMemoryRecords = array of TPraxoMemoryRecord;
  TPraxoMemoryStore = record
    Sessions: TPraxoStringArray;
    Records: array of TPraxoMemoryRecords;
    Sequence: Integer;
  end;

  TPraxoEvent = record
    Kind, SessionId, RunId: UTF8String;
    Data: TJSONData;
  end;
  TPraxoEventSink = class
  public
    Mode: Integer;
    Kinds: TPraxoStringArray;
    Predicate: TPraxoStringArray;
    Target: TPraxoEventSink;
    Sinks: array of TPraxoEventSink;
    constructor Create;
  end;

  TPraxoPathGrant = record
    Root, Access: UTF8String;
  end;
  TPraxoPathChecker = array of TPraxoPathGrant;
  TPraxoDecision = record
    Allowed: Boolean;
    Reason: UTF8String;
  end;

  TPraxoContextMessage = record
    Role, Content: UTF8String;
  end;
  TPraxoContextMessages = array of TPraxoContextMessage;
  TPraxoContextBudget = record
    MaxTokens, KeepRecent: Integer;
  end;

  TPraxoRepairer = function(const Text: UTF8String): UTF8String;

  TPraxoStructuredOutput = record
    Schema: TJSONData;
    MaxRepairs: Integer;
    Repairer: TPraxoRepairer;
  end;

  TPraxoCallLimit = record
    ModelLimit, ToolLimit, Models, Tools: Integer;
  end;

function PraxoMemoryNew: TPraxoMemoryStore;
function PraxoMemoryPut(var Store: TPraxoMemoryStore; const Session: UTF8String;
  const Value: TPraxoMemoryRecord): TPraxoMemoryRecord;
function PraxoMemorySearch(const Store: TPraxoMemoryStore; const Session, Query: UTF8String;
  Limit: Integer): TPraxoMemoryRecords;

function PraxoEventNew: TPraxoEventSink;
function PraxoEventMulti(const Sinks: array of TPraxoEventSink): TPraxoEventSink;
function PraxoEventFilter(Target: TPraxoEventSink; const Predicate: TPraxoStringArray): TPraxoEventSink;
procedure PraxoEventEmit(Sink: TPraxoEventSink; const Event: TPraxoEvent);
function PraxoStreamKinds: TPraxoStringArray;

function PraxoCheckpointNew: TPraxoStringArray;
procedure PraxoCheckpointRegister(var Allow: TPraxoStringArray; const Kind: UTF8String);
function PraxoCheckpointMarshal(const Allow: TPraxoStringArray; const Kind: UTF8String;
  Value: TJSONData; out Data: UTF8String): UTF8String;
function PraxoCheckpointUnmarshal(const Allow: TPraxoStringArray; const Data: UTF8String;
  out Value: TJSONData): UTF8String;

function PraxoNormalizePath(const Value: UTF8String): UTF8String;
function PraxoPathChecker(const Grants: array of TPraxoPathGrant; out Checker: TPraxoPathChecker): UTF8String;
function PraxoPathCheck(const Checker: TPraxoPathChecker; const Target, Need: UTF8String;
  out Decision: TPraxoDecision): UTF8String;
function PraxoPathAllowed(const Checker: TPraxoPathChecker; const Target, Need: UTF8String): Boolean;

function PraxoEstimateTokens(const Messages: TPraxoContextMessages): Integer;
function PraxoCompactContext(const Budget: TPraxoContextBudget;
  const Messages: TPraxoContextMessages; out Output: TPraxoContextMessages): Boolean;
function PraxoMessageWire(const Message: TPraxoContextMessage): TJSONObject;

function PraxoPiiRedact(const Text: UTF8String): UTF8String;
function PraxoRedactValue(Value: TJSONData): TJSONData;
function PraxoExtractJson(const Text: UTF8String): TJSONData;
function PraxoStructuredOutput(Schema: TJSONData; MaxRepairs: Integer;
  Repairer: TPraxoRepairer): TPraxoStructuredOutput;
function PraxoApplyStructured(const Config: TPraxoStructuredOutput; const Text: UTF8String): UTF8String;
function PraxoCallLimit(ModelLimit, ToolLimit: Integer): TPraxoCallLimit;
function PraxoCallLimitModel(var Limit: TPraxoCallLimit): UTF8String;
function PraxoCallLimitTool(var Limit: TPraxoCallLimit): UTF8String;
function PraxoSelectTools(const Selection, Tools: TPraxoStringArray): TPraxoStringArray;
function PraxoFallback(const PrimaryFailed: Boolean; const Primary, Fallback: UTF8String): UTF8String;
function PraxoCheckToolSelected(const Selection: TPraxoStringArray; const Name: UTF8String): UTF8String;

implementation

function ReplaceRegex(const Value, Pattern, Replacement: UTF8String): UTF8String;
var
  Regex: TRegExpr;
  Cursor: Integer;
begin
  Result := '';
  Cursor := 1;
  Regex := TRegExpr.Create(Pattern);
  try
    if Regex.Exec(Value) then
    begin
      repeat
        Result := Result + Copy(Value, Cursor, Regex.MatchPos[0] - Cursor) + Replacement;
        Cursor := Regex.MatchPos[0] + Regex.MatchLen[0];
        if Regex.MatchLen[0] = 0 then Break;
      until not Regex.ExecNext;
    end;
    Result := Result + Copy(Value, Cursor, Length(Value));
  finally
    Regex.Free;
  end;
end;

function PraxoMemoryNew: TPraxoMemoryStore;
begin
  SetLength(Result.Sessions, 0);
  SetLength(Result.Records, 0);
  Result.Sequence := 0;
end;

function SessionIndex(const Store: TPraxoMemoryStore; const Session: UTF8String): Integer;
begin
  for Result := 0 to High(Store.Sessions) do
    if Store.Sessions[Result] = Session then Exit;
  Result := -1;
end;

function PraxoMemoryPut(var Store: TPraxoMemoryStore; const Session: UTF8String;
  const Value: TPraxoMemoryRecord): TPraxoMemoryRecord;
var
  Index, Count: Integer;
begin
  Result := Value;
  if Result.Id = '' then
  begin
    Result.Id := 'mem-' + IntToStr(Store.Sequence) + '-' + IntToStr(Store.Sequence);
    Inc(Store.Sequence);
  end;
  if Result.CreatedAt = '' then Result.CreatedAt := IntToStr(Store.Sequence);
  Index := SessionIndex(Store, Session);
  if Index < 0 then
  begin
    Index := Length(Store.Sessions);
    SetLength(Store.Sessions, Index + 1);
    Store.Sessions[Index] := Session;
    SetLength(Store.Records, Index + 1);
    SetLength(Store.Records[Index], 0);
  end;
  Count := Length(Store.Records[Index]);
  SetLength(Store.Records[Index], Count + 1);
  Store.Records[Index][Count] := Result;
end;

function PraxoMemorySearch(const Store: TPraxoMemoryStore; const Session, Query: UTF8String;
  Limit: Integer): TPraxoMemoryRecords;
var
  Index, Count, I, J: Integer;
  Needle: UTF8String;
  Candidate: TPraxoMemoryRecord;
begin
  SetLength(Result, 0);
  Index := SessionIndex(Store, Session);
  if Index < 0 then Exit;
  Needle := LowerCase(Query);
  for I := 0 to High(Store.Records[Index]) do
    if (Needle = '') or (Pos(Needle, LowerCase(Store.Records[Index][I].Content)) > 0) then
    begin
      Count := Length(Result);
      SetLength(Result, Count + 1);
      Result[Count] := Store.Records[Index][I];
    end;
  for I := 0 to High(Result) do
    for J := I + 1 to High(Result) do
      if Result[J].CreatedAt > Result[I].CreatedAt then
      begin
        Candidate := Result[I];
        Result[I] := Result[J];
        Result[J] := Candidate;
      end;
  if (Limit > 0) and (Length(Result) > Limit) then SetLength(Result, Limit);
end;

constructor TPraxoEventSink.Create;
begin
  inherited Create;
  Mode := 0;
  SetLength(Kinds, 0);
  SetLength(Predicate, 0);
  Target := nil;
  SetLength(Sinks, 0);
end;

function PraxoEventNew: TPraxoEventSink;
begin
  Result := TPraxoEventSink.Create;
end;

function PraxoEventMulti(const Sinks: array of TPraxoEventSink): TPraxoEventSink;
var
  I: Integer;
begin
  Result := TPraxoEventSink.Create;
  Result.Mode := 1;
  SetLength(Result.Sinks, Length(Sinks));
  for I := 0 to High(Sinks) do Result.Sinks[I] := Sinks[I];
end;

function PraxoEventFilter(Target: TPraxoEventSink; const Predicate: TPraxoStringArray): TPraxoEventSink;
begin
  Result := TPraxoEventSink.Create;
  Result.Mode := 2;
  Result.Target := Target;
  Result.Predicate := Predicate;
end;

procedure AppendKind(var Kinds: TPraxoStringArray; const Kind: UTF8String);
var Count: Integer;
begin
  Count := Length(Kinds);
  SetLength(Kinds, Count + 1);
  Kinds[Count] := Kind;
end;

procedure PraxoEventEmit(Sink: TPraxoEventSink; const Event: TPraxoEvent);
var
  I: Integer;
  Match: Boolean;
begin
  if Sink.Mode = 1 then
  begin
    for I := 0 to High(Sink.Sinks) do PraxoEventEmit(Sink.Sinks[I], Event);
  end
  else if Sink.Mode = 2 then
  begin
    Match := Length(Sink.Predicate) = 0;
    for I := 0 to High(Sink.Predicate) do
      if Sink.Predicate[I] = Event.Kind then Match := True;
    if Match then PraxoEventEmit(Sink.Target, Event);
  end
  else
    AppendKind(Sink.Kinds, Event.Kind);
end;

function PraxoStreamKinds: TPraxoStringArray;
begin
  SetLength(Result, 6);
  Result[0] := 'values'; Result[1] := 'updates'; Result[2] := 'messages';
  Result[3] := 'tasks'; Result[4] := 'debug'; Result[5] := 'checkpoint';
end;

function PraxoCheckpointNew: TPraxoStringArray;
begin
  SetLength(Result, 0);
end;

procedure PraxoCheckpointRegister(var Allow: TPraxoStringArray; const Kind: UTF8String);
var I, Count: Integer;
begin
  if Kind = '' then raise Exception.Create('CHECKPOINT_ERROR');
  for I := 0 to High(Allow) do if Allow[I] = Kind then Exit;
  Count := Length(Allow);
  SetLength(Allow, Count + 1);
  Allow[Count] := Kind;
end;

function Allowed(const Allow: TPraxoStringArray; const Kind: UTF8String): Boolean;
var I: Integer;
begin
  for I := 0 to High(Allow) do if Allow[I] = Kind then Exit(True);
  Result := False;
end;

function PraxoCheckpointMarshal(const Allow: TPraxoStringArray; const Kind: UTF8String;
  Value: TJSONData; out Data: UTF8String): UTF8String;
var
  Envelope: TJSONObject;
begin
  Data := '';
  if not Allowed(Allow, Kind) then Exit('CHECKPOINT_TYPE_NOT_ALLOWED');
  Envelope := TJSONObject.Create;
  try
    Envelope.Add('type', Kind);
    Envelope.Add('data', Value.Clone);
    Data := PraxoEncodeJSON(Envelope);
    Result := '';
  finally
    Envelope.Free;
  end;
end;

function PraxoCheckpointUnmarshal(const Allow: TPraxoStringArray; const Data: UTF8String;
  out Value: TJSONData): UTF8String;
var
  Parsed: TJSONData;
  Envelope: TJSONObject;
  Kind: UTF8String;
begin
  Value := nil;
  try
    Parsed := PraxoParseJSON(Data);
  except
    Exit('CHECKPOINT_ERROR');
  end;
  if Parsed.JSONType <> jtObject then
  begin
    Parsed.Free;
    Exit('CHECKPOINT_ERROR');
  end;
  Envelope := TJSONObject(Parsed);
  Kind := Envelope.Get('type', '');
  if not Allowed(Allow, Kind) then
  begin
    Parsed.Free;
    Exit('CHECKPOINT_TYPE_NOT_ALLOWED');
  end;
  Value := Envelope.Find('data');
  if Value = nil then Value := TJSONNull.Create else Value := Value.Clone;
  Parsed.Free;
  Result := '';
end;

function PraxoNormalizePath(const Value: UTF8String): UTF8String;
var
  Path, Body, Part, Prefix: UTF8String;
  Absolute: Boolean;
  Parts: TPraxoStringArray;
  I, Count: Integer;

  procedure Push(const Item: UTF8String);
  begin
    SetLength(Parts, Length(Parts) + 1);
    Parts[High(Parts)] := Item;
  end;

  function Pop: Boolean;
  begin
    Result := Length(Parts) > 0;
    if Result then SetLength(Parts, Length(Parts) - 1);
  end;
begin
  Path := StringReplace(Value, '\', '/', [rfReplaceAll]);
  Prefix := '';
  Body := Path;
  Absolute := False;
  if (Length(Path) >= 2) and (Path[2] = ':') then
  begin
    Body := Copy(Path, 3, Length(Path));
    Absolute := (Body <> '') and (Body[1] = '/');
    Prefix := Copy(Path, 1, 2);
    if Absolute then Prefix := Prefix + '/';
  end
  else if (Path <> '') and (Path[1] = '/') then
  begin
    Prefix := '/';
    Absolute := True;
  end;
  SetLength(Parts, 0);
  while Body <> '' do
  begin
    I := Pos('/', Body);
    if I = 0 then begin Part := Body; Body := ''; end
    else begin Part := Copy(Body, 1, I - 1); Body := Copy(Body, I + 1, Length(Body)); end;
    if (Part = '') or (Part = '.') then Continue;
    if Part = '..' then
    begin
      if Length(Parts) = 0 then
      begin
        if not Absolute then Push('..');
      end
      else if Parts[High(Parts)] = '..' then Push('..')
      else Pop;
    end
    else Push(Part);
  end;
  Result := Prefix;
  for I := 0 to High(Parts) do
  begin
    if (I > 0) or ((Prefix <> '') and (Prefix[Length(Prefix)] <> '/')) then Result := Result + '/';
    if I = 0 then
    begin
      if (Prefix <> '') and (Prefix[Length(Prefix)] = '/') then Result := Result + Parts[I]
      else Result := Result + Parts[I];
    end
    else Result := Result + Parts[I];
  end;
  {$IFDEF WINDOWS}
  Result := LowerCase(Result);
  {$ENDIF}
end;

function Within(const Root, Target: UTF8String): Boolean;
begin
  Result := (Root = Target) or (Copy(Target, 1, Length(Root) + 1) = Root + '/');
end;

function AccessAllows(const Granted, Need: UTF8String): Boolean;
begin
  Result := (Granted = 'readwrite') or ((Granted = 'read') and (Need = 'read')) or
    ((Granted = 'write') and (Need = 'write'));
end;

function PraxoPathChecker(const Grants: array of TPraxoPathGrant; out Checker: TPraxoPathChecker): UTF8String;
var I: Integer;
begin
  SetLength(Checker, Length(Grants));
  for I := 0 to High(Grants) do
  begin
    if (Grants[I].Root = '') or ((Grants[I].Access <> 'read') and (Grants[I].Access <> 'write')
      and (Grants[I].Access <> 'readwrite')) then Exit('POLICY_ERROR');
    Checker[I].Root := PraxoNormalizePath(Grants[I].Root);
    Checker[I].Access := Grants[I].Access;
  end;
  Result := '';
end;

function PraxoPathCheck(const Checker: TPraxoPathChecker; const Target, Need: UTF8String;
  out Decision: TPraxoDecision): UTF8String;
var I: Integer; Resolved: UTF8String;
begin
  Decision.Allowed := False;
  Decision.Reason := '';
  if (Need <> 'read') and (Need <> 'write') and (Need <> 'readwrite') then Exit('POLICY_ERROR');
  if Length(Checker) = 0 then begin Decision.Reason := 'no allowed roots'; Exit(''); end;
  Resolved := PraxoNormalizePath(Target);
  for I := 0 to High(Checker) do
    if Within(Checker[I].Root, Resolved) and AccessAllows(Checker[I].Access, Need) then
    begin Decision.Allowed := True; Decision.Reason := 'allowed'; Exit(''); end;
  for I := 0 to High(Checker) do
    if Within(Checker[I].Root, Resolved) then begin Decision.Reason := 'insufficient grant'; Exit(''); end;
  Decision.Reason := 'outside roots';
  Result := '';
end;

function PraxoPathAllowed(const Checker: TPraxoPathChecker; const Target, Need: UTF8String): Boolean;
var Decision: TPraxoDecision;
begin
  Result := (PraxoPathCheck(Checker, Target, Need, Decision) = '') and Decision.Allowed;
end;

function PraxoEstimateTokens(const Messages: TPraxoContextMessages): Integer;
var I: Integer;
begin
  Result := 0;
  for I := 0 to High(Messages) do
    Result := Result + 4 + Length(Messages[I].Content) div 4;
end;

function PraxoMessageWire(const Message: TPraxoContextMessage): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('role', Message.Role);
  Result.Add('content', Message.Content);
end;

function PraxoCompactContext(const Budget: TPraxoContextBudget;
  const Messages: TPraxoContextMessages; out Output: TPraxoContextMessages): Boolean;
var
  System, Rest, Kept: TPraxoContextMessages;
  I, Start, Keep: Integer;
  Marker: TPraxoContextMessage;
  Temp: TPraxoContextMessages;

  procedure Append(var Target: TPraxoContextMessages; const Item: TPraxoContextMessage);
  begin
    SetLength(Target, Length(Target) + 1);
    Target[High(Target)] := Item;
  end;
begin
  SetLength(Output, 0);
  if (Budget.MaxTokens <= 0) or (PraxoEstimateTokens(Messages) <= Budget.MaxTokens) then
  begin
    Output := Messages;
    Exit(True);
  end;
  SetLength(System, 0);
  SetLength(Rest, 0);
  for I := 0 to High(Messages) do
    if Messages[I].Role = 'system' then Append(System, Messages[I]) else Append(Rest, Messages[I]);
  Temp := nil;
  for I := 0 to High(System) do
    if Copy(System[I].Content, 1, 19) <> '[context compacted:' then Append(Temp, System[I]);
  System := Temp;
  if PraxoEstimateTokens(System) > Budget.MaxTokens then begin
    if Length(System) = 0 then Exit(False);
    System[0].Content := Copy(System[0].Content, 1, (Budget.MaxTokens - 4) * 4);
    if PraxoEstimateTokens(System) > Budget.MaxTokens then Exit(False);
  end;
  Keep := Budget.KeepRecent;
  if Keep <= 0 then Keep := 4;
  Start := Length(Rest) - Keep;
  if Start < 0 then Start := 0;
  while (Start > 0) and (Rest[Start].Role = 'tool') do Dec(Start);
  Marker.Role := 'system';
  Marker.Content := '[context compacted: ' + IntToStr(Start) + ' older messages omitted]';
  SetLength(Kept, Length(Rest) - Start);
  for I := Start to High(Rest) do Kept[I - Start] := Rest[I];
  Output := System;
  if Start > 0 then Append(Output, Marker);
  for I := 0 to High(Kept) do Append(Output, Kept[I]);
  while (PraxoEstimateTokens(Output) > Budget.MaxTokens) and (Length(Kept) > 1) do
  begin
    if Kept[1].Role = 'tool' then Exit(False);
    for I := 1 to High(Kept) do Kept[I - 1] := Kept[I];
    SetLength(Kept, Length(Kept) - 1);
    Output := System;
    if Start > 0 then Append(Output, Marker);
    for I := 0 to High(Kept) do Append(Output, Kept[I]);
  end;
  Result := PraxoEstimateTokens(Output) <= Budget.MaxTokens;
end;

function PraxoPiiRedact(const Text: UTF8String): UTF8String;
begin
  Result := ReplaceRegex(Text, '[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}', '[REDACTED:email]');
  Result := ReplaceRegex(Result, '\b\d{3}-\d{2}-\d{4}\b', '[REDACTED:ssn]');
  Result := ReplaceRegex(Result, '\b(?:\d{4}[ -]?){3}\d{4}\b', '[REDACTED:credit_card]');
  Result := ReplaceRegex(Result, '\b(?:\+?1[-. ]?)?\(?\d{3}\)?[-. ]?\d{3}[-. ]?\d{4}\b', '[REDACTED:phone]');
end;

function PraxoRedactValue(Value: TJSONData): TJSONData;
var I: Integer; Obj: TJSONObject; Arr: TJSONArray;
begin
  if Value = nil then Exit(nil);
  if Value.JSONType = jtString then Exit(TJSONString.Create(PraxoPiiRedact(Value.AsString)));
  if Value.JSONType = jtArray then
  begin
    Arr := TJSONArray.Create;
    for I := 0 to TJSONArray(Value).Count - 1 do Arr.Add(PraxoRedactValue(TJSONArray(Value).Items[I]));
    Exit(Arr);
  end;
  if Value.JSONType = jtObject then
  begin
    Obj := TJSONObject.Create;
    for I := 0 to TJSONObject(Value).Count - 1 do
      Obj.Add(TJSONObject(Value).Names[I], PraxoRedactValue(TJSONObject(Value).Items[I]));
    Exit(Obj);
  end;
  Result := Value.Clone;
end;

function PraxoExtractJson(const Text: UTF8String): TJSONData;
var Value, Start, I: Integer; Body: UTF8String;
begin
  Result := nil;
  Body := Trim(Text);
  if Copy(Body, 1, 3) = '```' then
  begin
    I := Pos(#10, Body);
    if I > 0 then Body := Copy(Body, I + 1, Length(Body));
    I := Pos('```', Body);
    if I > 0 then Body := Copy(Body, 1, I - 1);
    Body := Trim(Body);
  end;
  Start := 0;
  for I := 1 to Length(Body) do
    if (Body[I] = '{') or (Body[I] = '[') then begin Start := I; Break; end;
  if Start = 0 then Exit;
  try
    Result := PraxoParseJSON(Copy(Body, Start, Length(Body)));
  except
    Result := nil;
  end;
end;

function PraxoStructuredOutput(Schema: TJSONData; MaxRepairs: Integer;
  Repairer: TPraxoRepairer): TPraxoStructuredOutput;
begin
  Result.Schema := Schema;
  Result.MaxRepairs := MaxRepairs;
  Result.Repairer := Repairer;
end;

function StructuredAttempt(const Config: TPraxoStructuredOutput; const Text: UTF8String;
  Attempt: Integer): UTF8String;
var Value: TJSONData; Repaired: UTF8String;
begin
  Value := PraxoExtractJson(Text);
  if Value <> nil then
  try
    if Length(PraxoValidateSchema(Config.Schema, Value)) = 0 then Exit(Text);
  finally
    Value.Free;
  end;
  if (Attempt >= Config.MaxRepairs) or not Assigned(Config.Repairer) then Exit('');
  Repaired := Config.Repairer(Text);
  if Trim(Repaired) = '' then Exit('');
  Result := StructuredAttempt(Config, Repaired, Attempt + 1);
end;

function PraxoApplyStructured(const Config: TPraxoStructuredOutput; const Text: UTF8String): UTF8String;
begin
  Result := StructuredAttempt(Config, Text, 0);
end;

function PraxoCallLimit(ModelLimit, ToolLimit: Integer): TPraxoCallLimit;
begin
  Result.ModelLimit := ModelLimit;
  Result.ToolLimit := ToolLimit;
  Result.Models := 0;
  Result.Tools := 0;
end;

function PraxoCallLimitModel(var Limit: TPraxoCallLimit): UTF8String;
begin
  Inc(Limit.Models);
  if (Limit.ModelLimit > 0) and (Limit.Models > Limit.ModelLimit) then Result := 'AGENT_MODEL_CALL_LIMIT'
  else Result := '';
end;

function PraxoCallLimitTool(var Limit: TPraxoCallLimit): UTF8String;
begin
  Inc(Limit.Tools);
  if (Limit.ToolLimit > 0) and (Limit.Tools > Limit.ToolLimit) then Result := 'AGENT_TOOL_CALL_LIMIT'
  else Result := '';
end;

function IndexStr(const Value: UTF8String; const Values: TPraxoStringArray): Integer;
var I: Integer;
begin
  for I := 0 to High(Values) do if Values[I] = Value then Exit(I);
  Result := -1;
end;

function PraxoSelectTools(const Selection, Tools: TPraxoStringArray): TPraxoStringArray;
var I, Count: Integer;
begin
  SetLength(Result, 0);
  for I := 0 to High(Tools) do
    if IndexStr(Tools[I], Selection) >= 0 then
    begin
      Count := Length(Result); SetLength(Result, Count + 1); Result[Count] := Tools[I];
    end;
end;

function PraxoFallback(const PrimaryFailed: Boolean; const Primary, Fallback: UTF8String): UTF8String;
begin
  if PrimaryFailed then Result := Fallback else Result := Primary;
end;

function PraxoCheckToolSelected(const Selection: TPraxoStringArray; const Name: UTF8String): UTF8String;
begin
  if IndexStr(Name, Selection) >= 0 then Result := '' else Result := 'AGENT_TOOL_NOT_SELECTED';
end;

end.
