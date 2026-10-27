program core_tests;
{$mode objfpc}{$H+}

uses SysUtils, Classes, fpjson, praxo, praxo_core;

var
  SpecRoot: UTF8String;
  RepairText: UTF8String;

function ReadTextFile(const Path: UTF8String): UTF8String;
var Stream: TFileStream;
begin
  Stream := TFileStream.Create(Path, fmOpenRead or fmShareDenyWrite);
  try
    SetLength(Result, Stream.Size);
    if Stream.Size > 0 then Stream.ReadBuffer(Result[1], Stream.Size);
  finally
    Stream.Free;
  end;
end;

function LastField(ObjectValue: TJSONObject; const Name: UTF8String): TJSONData;
var I: Integer;
begin
  Result := nil;
  for I := 0 to ObjectValue.Count - 1 do
    if ObjectValue.Names[I] = Name then Result := ObjectValue.Items[I];
end;

function Str(ObjectValue: TJSONObject; const Name: UTF8String; const Fallback: UTF8String = ''): UTF8String;
var Data: TJSONData;
begin
  Data := LastField(ObjectValue, Name);
  if (Data = nil) or (Data.JSONType <> jtString) then Result := Fallback else Result := Data.AsString;
end;

function Num(ObjectValue: TJSONObject; const Name: UTF8String; Fallback: Integer = 0): Integer;
var Data: TJSONData;
begin
  Data := LastField(ObjectValue, Name);
  if (Data = nil) or (Data.JSONType <> jtNumber) then Result := Fallback else Result := Data.AsInteger;
end;

function BoolVal(ObjectValue: TJSONObject; const Name: UTF8String; Fallback: Boolean = False): Boolean;
var Data: TJSONData;
begin
  Data := LastField(ObjectValue, Name);
  if (Data = nil) or (Data.JSONType <> jtBoolean) then Result := Fallback else Result := Data.AsBoolean;
end;

procedure Check(Condition: Boolean; const MessageText: UTF8String);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

function Group(const Name: UTF8String): TJSONArray;
var Document: TJSONData; Vectors: TJSONData;
begin
  Document := PraxoParseJSON(ReadTextFile(IncludeTrailingPathDelimiter(SpecRoot) + 'vectors/' + Name + '.json'));
  Vectors := LastField(TJSONObject(Document), 'vectors');
  Result := TJSONArray(Vectors.Clone);
  Document.Free;
end;

function StringsJSON(const Values: TPraxoStringArray): TJSONArray;
var I: Integer;
begin
  Result := TJSONArray.Create;
  for I := 0 to High(Values) do Result.Add(Values[I]);
end;

function StringList(Value: TJSONArray): TPraxoStringArray;
var I: Integer;
begin
  SetLength(Result, Value.Count);
  for I := 0 to Value.Count - 1 do Result[I] := Value.Items[I].AsString;
end;

procedure TestMemory;
var Vectors: TJSONArray; Vector, Input, Expect, Puts, RecordValue, Ids, Contents: TJSONObject;
  Store: TPraxoMemoryStore; RecordData: TPraxoMemoryRecord; Records: TPraxoMemoryRecords;
  I, J: Integer; Session: UTF8String; IdArray, ContentArray: TJSONArray;
begin
  Vectors := Group('memory');
  try
    for I := 0 to Vectors.Count - 1 do
    begin
      Vector := TJSONObject(Vectors.Items[I]);
      Input := TJSONObject(LastField(Vector, 'input'));
      Expect := TJSONObject(LastField(Vector, 'expect'));
      Store := PraxoMemoryNew;
      Puts := TJSONObject(TJSONArray(LastField(Input, 'puts')).Items[0]);
      for J := 0 to TJSONArray(LastField(Input, 'puts')).Count - 1 do
      begin
        Puts := TJSONObject(TJSONArray(LastField(Input, 'puts')).Items[J]);
        RecordValue := TJSONObject(LastField(Puts, 'record'));
        RecordData.Id := Str(RecordValue, 'id');
        RecordData.Frame := Str(RecordValue, 'frame');
        RecordData.Content := Str(RecordValue, 'content');
        RecordData.CreatedAt := Str(RecordValue, 'createdAt');
        Session := Str(Puts, 'session');
        PraxoMemoryPut(Store, Session, RecordData);
      end;
      Records := PraxoMemorySearch(Store, Str(Input, 'session'), Str(Input, 'query'), Num(Input, 'limit'));
      IdArray := TJSONArray.Create;
      ContentArray := TJSONArray.Create;
      for J := 0 to High(Records) do
      begin
        IdArray.Add(Records[J].Id);
        ContentArray.Add(Records[J].Content);
      end;
      if Length(Records) = 0 then
      begin
        Check(LastField(Expect, 'ids').JSONType = jtNull, 'memory ids');
        Check(LastField(Expect, 'contents').JSONType = jtNull, 'memory contents');
      end
      else
      begin
        Check(PraxoJSONEqual(IdArray, LastField(Expect, 'ids')), 'memory ids');
        Check(PraxoJSONEqual(ContentArray, LastField(Expect, 'contents')), 'memory contents');
      end;
      IdArray.Free;
      ContentArray.Free;
    end;
  finally
    Vectors.Free;
  end;
  writeln('test_memory passed');
end;

procedure TestEvent;
var Vectors: TJSONArray; I, J, Count: Integer; Vector, Input, Expect: TJSONObject;
  Events: array of TPraxoEvent; Sink: TPraxoEventSink; Multi: TPraxoEventSink;
  PerSink: TJSONArray; Kinds: TJSONArray; Delivered: TJSONData;
begin
  Vectors := Group('event');
  try
    for I := 0 to Vectors.Count - 1 do
    begin
      Vector := TJSONObject(Vectors.Items[I]);
      Input := TJSONObject(LastField(Vector, 'input'));
      Expect := TJSONObject(LastField(Vector, 'expect'));
      SetLength(Events, TJSONArray(LastField(Input, 'events')).Count);
      for J := 0 to High(Events) do
      begin
        Events[J].Kind := TJSONArray(LastField(Input, 'events')).Items[J].AsString;
        Events[J].SessionId := 's1';
      end;
      if Str(Input, 'sink') = 'multi' then
      begin
        Count := Num(Input, 'sinkCount', 1);
        if Count < 1 then Count := 1;
        Multi := PraxoEventMulti([]);
        SetLength(Multi.Sinks, Count);
        for J := 0 to Count - 1 do Multi.Sinks[J] := PraxoEventNew;
        for J := 0 to High(Events) do PraxoEventEmit(Multi, Events[J]);
        PerSink := TJSONArray.Create;
        for J := 0 to Count - 1 do PerSink.Add(StringsJSON(Multi.Sinks[J].Kinds));
        Check(PraxoJSONEqual(PerSink, LastField(Expect, 'perSink')), 'perSink');
        PerSink.Free;
      end
      else
      begin
        Sink := PraxoEventFilter(PraxoEventNew, []);
        if LastField(Input, 'predicateTypes') <> nil then
          Sink.Predicate := StringList(TJSONArray(LastField(Input, 'predicateTypes')));
        for J := 0 to High(Events) do PraxoEventEmit(Sink, Events[J]);
        Kinds := StringsJSON(Sink.Target.Kinds);
        Delivered := LastField(Expect, 'delivered');
        if Length(Sink.Target.Kinds) = 0 then Check(Delivered.JSONType = jtNull, 'delivered')
        else Check(PraxoJSONEqual(Kinds, Delivered), 'delivered');
        Kinds.Free;
      end;
    end;
  finally
    Vectors.Free;
  end;
  writeln('test_event passed');
end;

procedure TestStream;
var Vectors: TJSONArray; I: Integer; Expect: TJSONObject; Kinds: TJSONArray;
begin
  Vectors := Group('stream');
  try
    for I := 0 to Vectors.Count - 1 do
    begin
      Expect := TJSONObject(LastField(TJSONObject(Vectors.Items[I]), 'expect'));
      Kinds := StringsJSON(PraxoStreamKinds);
      Check(PraxoJSONEqual(Kinds, LastField(Expect, 'kinds')), 'stream kinds');
      Kinds.Free;
    end;
  finally
    Vectors.Free;
  end;
  writeln('test_stream passed');
end;

procedure TestCheckpoint;
var Vectors: TJSONArray; I, J: Integer; Vector, Input, Expect: TJSONObject;
  Allow: TPraxoStringArray; Operation, Kind, Code, Data: UTF8String; Value: TJSONData;
  Envelope: TJSONObject; Registered: TJSONArray;
begin
  Vectors := Group('checkpoint');
  try
    for I := 0 to Vectors.Count - 1 do
    begin
      Vector := TJSONObject(Vectors.Items[I]);
      Input := TJSONObject(LastField(Vector, 'input'));
      Expect := TJSONObject(LastField(Vector, 'expect'));
      Allow := PraxoCheckpointNew;
      Registered := TJSONArray(LastField(Input, 'registered'));
      if Registered <> nil then
        for J := 0 to Registered.Count - 1 do PraxoCheckpointRegister(Allow, Registered.Items[J].AsString);
      Operation := Str(Input, 'operation', 'roundtrip');
      Kind := Str(Input, 'type');
      if LastField(Input, 'value') = nil then Value := TJSONNull.Create else Value := LastField(Input, 'value').Clone;
      if Operation = 'roundtrip' then
      begin
        Code := PraxoCheckpointMarshal(Allow, Kind, Value, Data);
        Check(Code = '', 'checkpoint marshal');
        Code := PraxoCheckpointUnmarshal(Allow, Data, Value);
        Check(Code = '', 'checkpoint unmarshal');
        Check(PraxoJSONEqual(Value, LastField(Expect, 'value')), 'checkpoint value');
      end
      else if Operation = 'marshal' then
      begin
        Code := PraxoCheckpointMarshal(Allow, Kind, Value, Data);
        Check(Code = Str(Expect, 'errorCode'), 'checkpoint marshal code');
      end
      else
      begin
        Envelope := TJSONObject.Create;
        Envelope.Add('type', Kind);
        Envelope.Add('data', Value.Clone);
        Data := PraxoEncodeJSON(Envelope);
        Envelope.Free;
        Code := PraxoCheckpointUnmarshal(Allow, Data, Value);
        Check(Code = Str(Expect, 'errorCode'), 'checkpoint unmarshal code');
      end;
      Value.Free;
    end;
  finally
    Vectors.Free;
  end;
  writeln('test_checkpoint passed');
end;

procedure TestPolicy;
var Vectors: TJSONArray; I, J: Integer; Vector, Input, Expect: TJSONObject;
  Grants: array of TPraxoPathGrant; Checker: TPraxoPathChecker; Decision: TPraxoDecision;
  Code, Target, Need: UTF8String; RawGrants: TJSONArray;
begin
  Vectors := Group('policy');
  try
    for I := 0 to Vectors.Count - 1 do
    begin
      Vector := TJSONObject(Vectors.Items[I]);
      Input := TJSONObject(LastField(Vector, 'input'));
      Expect := TJSONObject(LastField(Vector, 'expect'));
      RawGrants := TJSONArray(LastField(Input, 'grants'));
      SetLength(Grants, 0);
      if RawGrants <> nil then
      begin
        SetLength(Grants, RawGrants.Count);
        for J := 0 to RawGrants.Count - 1 do
        begin
          Grants[J].Root := Str(TJSONObject(RawGrants.Items[J]), 'root');
          Grants[J].Access := Str(TJSONObject(RawGrants.Items[J]), 'access', 'read');
        end;
      end;
      Target := Str(Input, 'target');
      Need := Str(Input, 'need', 'read');
      Code := PraxoPathChecker(Grants, Checker);
      if Code = '' then Code := PraxoPathCheck(Checker, Target, Need, Decision);
      if BoolVal(Expect, 'error') then
        Check(Code <> '', 'expected policy error')
      else
      begin
        Check(Code = '', 'policy error');
        Check(Decision.Allowed = BoolVal(Expect, 'allowed'), 'policy allowed');
      end;
    end;
  finally
    Vectors.Free;
  end;
  writeln('test_policy passed');
end;

procedure TestContext;
var Vectors: TJSONArray; I, J: Integer; Vector, Input, Expect, BudgetValue: TJSONObject;
  Messages, Output: TPraxoContextMessages; Budget: TPraxoContextBudget; Ok: Boolean;
  Wire: TJSONArray; Message: TJSONObject; RawMessages: TJSONArray;
begin
  Vectors := Group('context');
  try
    for I := 0 to Vectors.Count - 1 do
    begin
      Vector := TJSONObject(Vectors.Items[I]);
      Input := TJSONObject(LastField(Vector, 'input'));
      Expect := TJSONObject(LastField(Vector, 'expect'));
      RawMessages := TJSONArray(LastField(Input, 'messages'));
      SetLength(Messages, RawMessages.Count);
      for J := 0 to RawMessages.Count - 1 do
      begin
        Messages[J].Role := Str(TJSONObject(RawMessages.Items[J]), 'role');
        Messages[J].Content := Str(TJSONObject(RawMessages.Items[J]), 'content');
      end;
      if Str(Input, 'operation') = 'estimate' then
        Check(PraxoEstimateTokens(Messages) = Num(Expect, 'tokens'), 'token estimate')
      else
      begin
        BudgetValue := TJSONObject(LastField(Input, 'budget'));
        Budget.MaxTokens := Num(BudgetValue, 'maxTokens');
        Budget.KeepRecent := Num(BudgetValue, 'keepRecent');
        Ok := PraxoCompactContext(Budget, Messages, Output);
        Check(Ok = BoolVal(Expect, 'ok', True), 'context ok');
        if BoolVal(Expect, 'ok', True) then
        begin
          Check(PraxoEstimateTokens(Output) = Num(Expect, 'tokens'), 'compacted tokens');
          Wire := TJSONArray.Create;
          for J := 0 to High(Output) do
          begin
            Message := PraxoMessageWire(Output[J]);
            Wire.Add(Message);
          end;
          Check(PraxoJSONEqual(Wire, LastField(Expect, 'messages')), 'compacted messages');
          Wire.Free;
        end;
      end;
    end;
  finally
    Vectors.Free;
  end;
  writeln('test_context passed');
end;

function RepairProc(const Text: UTF8String): UTF8String;
begin
  Result := RepairText;
end;

procedure TestMiddleware;
var Vectors: TJSONArray; I, J: Integer; Vector, Input, Expect: TJSONObject;
  Operation, Text, Code: UTF8String; Value: TJSONData; Config: TPraxoStructuredOutput;
  Limit: TPraxoCallLimit; Calls: TJSONArray; Selection, Tools, Advertised: TPraxoStringArray;
  Outcomes: TJSONArray; Repairer: TPraxoRepairer;
begin
  Vectors := Group('middleware');
  try
    for I := 0 to Vectors.Count - 1 do
    begin
      Vector := TJSONObject(Vectors.Items[I]);
      Input := TJSONObject(LastField(Vector, 'input'));
      Expect := TJSONObject(LastField(Vector, 'expect'));
      Operation := Str(Input, 'operation');
      if Operation = 'pii' then
        Check(PraxoPiiRedact(Str(Input, 'text')) = Str(Expect, 'text'), 'pii')
      else if Operation = 'pii-value' then
      begin
        Value := PraxoRedactValue(LastField(Input, 'value'));
        Check(PraxoJSONEqual(Value, LastField(Expect, 'value')), 'pii value');
        Value.Free;
      end
      else if Operation = 'structured' then
      begin
        RepairText := Str(Input, 'repairOutput');
        if LastField(Input, 'repairOutput') <> nil then Repairer := @RepairProc else Repairer := nil;
        Config := PraxoStructuredOutput(LastField(Input, 'schema'), Num(Input, 'maxRepairs'), Repairer);
        Text := PraxoApplyStructured(Config, Str(Input, 'output'));
        if BoolVal(Expect, 'ok') then
          Check(Text = Str(Expect, 'output'), 'structured output')
        else
          Check(Text = '', 'structured failure');
      end
      else if Operation = 'call-limit' then
      begin
        Limit := PraxoCallLimit(Num(Input, 'modelLimit'), Num(Input, 'toolLimit'));
        Outcomes := TJSONArray.Create;
        Calls := TJSONArray(LastField(Input, 'calls'));
        for J := 0 to Calls.Count - 1 do
        begin
          if Calls.Items[J].AsString = 'model' then Code := PraxoCallLimitModel(Limit)
          else Code := PraxoCallLimitTool(Limit);
          if Code = '' then Outcomes.Add('ok') else Outcomes.Add(Code);
        end;
        Check(PraxoJSONEqual(Outcomes, LastField(Expect, 'outcomes')), 'call limit');
        Outcomes.Free;
      end
      else if Operation = 'tool-selection' then
      begin
        Selection := StringList(TJSONArray(LastField(Input, 'selected')));
        Tools := StringList(TJSONArray(LastField(Input, 'tools')));
        Advertised := PraxoSelectTools(Selection, Tools);
        Check(PraxoJSONEqual(StringsJSON(Advertised), LastField(Expect, 'advertised')), 'advertised');
        Code := PraxoCheckToolSelected(Selection, Str(Input, 'requested'));
        if Code = '' then Code := 'ok';
        Check(Code = Str(Expect, 'reject'), 'reject');
      end
      else if Operation = 'fallback' then
        Check(PraxoFallback(True, '', Str(Input, 'fallbackContent')) = Str(Expect, 'output'), 'fallback');
    end;
  finally
    Vectors.Free;
  end;
  writeln('test_middleware passed');
end;

begin
  if ParamCount < 1 then
  begin
    writeln('usage: core_tests <spec-directory>');
    Halt(1);
  end;
  SpecRoot := ParamStr(1);
  TestMemory;
  TestEvent;
  TestStream;
  TestCheckpoint;
  TestPolicy;
  TestContext;
  TestMiddleware;
  writeln('All declared Delphi Core vector groups passed');
end.
