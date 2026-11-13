program adapter_tests;
{$mode objfpc}{$H+}

uses SysUtils, fpjson, praxo, praxo_core, praxo_otel, praxo_retriever,
  praxo_delegation;

type
  TFakeOtelTransport = class
  public
    Requests: array of TPraxoOtelRequest;
    StatusCode: Integer;
    ResponseBody: UTF8String;
    function Send(const Request: TPraxoOtelRequest): TPraxoOtelResponse;
  end;

var
  LastQuery: UTF8String;
  LastLimit, RetrieverCalls: Integer;

function TFakeOtelTransport.Send(const Request: TPraxoOtelRequest):
  TPraxoOtelResponse;
var
  Count: Integer;
begin
  Count := Length(Requests);
  SetLength(Requests, Count + 1);
  Requests[Count] := Request;
  Result.StatusCode := StatusCode;
  Result.Body := ResponseBody;
end;

function LastField(ObjectValue: TJSONObject; const Name: UTF8String): TJSONData;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to ObjectValue.Count - 1 do
    if ObjectValue.Names[I] = Name then Result := ObjectValue.Items[I];
end;

function Str(ObjectValue: TJSONObject; const Name: UTF8String;
  const Fallback: UTF8String = ''): UTF8String;
var
  Data: TJSONData;
begin
  Data := LastField(ObjectValue, Name);
  if (Data = nil) or (Data.JSONType <> jtString) then Result := Fallback
  else Result := Data.AsString;
end;

function Num(ObjectValue: TJSONObject; const Name: UTF8String;
  Fallback: Integer = 0): Integer;
var
  Data: TJSONData;
begin
  Data := LastField(ObjectValue, Name);
  if (Data = nil) or (Data.JSONType <> jtNumber) then Result := Fallback
  else Result := Data.AsInteger;
end;

function AttributeValue(Attributes: TJSONArray; const Key: UTF8String): UTF8String;
var
  I: Integer;
  Item, Value: TJSONObject;
begin
  Result := '';
  for I := 0 to Attributes.Count - 1 do
  begin
    Item := TJSONObject(Attributes.Items[I]);
    if Str(Item, 'key') = Key then
    begin
      Value := TJSONObject(LastField(Item, 'value'));
      Exit(Str(Value, 'stringValue'));
    end;
  end;
end;

function HasAttribute(Attributes: TJSONArray; const Key: UTF8String): Boolean;
var
  I: Integer;
begin
  for I := 0 to Attributes.Count - 1 do
    if Str(TJSONObject(Attributes.Items[I]), 'key') = Key then Exit(True);
  Result := False;
end;

procedure Check(Condition: Boolean; const Detail: UTF8String);
begin
  if not Condition then
  begin
    WriteLn('FAIL: ', Detail);
    Halt(1);
  end;
end;

function FakeOtelClock: Int64;
begin
  Result := 1794294000000000000;
end;

procedure TestOtel;
var
  Fake: TFakeOtelTransport;
  Sink: TPraxoOtelSink;
  Event: TPraxoEvent;
  Data, Root, ResourceSpan, Scope, Span: TJSONObject;
  ResourceSpans, ScopeSpans, Spans, Attributes: TJSONArray;
  TraceId, SpanId, Body: UTF8String;
  I: Integer;
  Caught: Boolean;
  Statuses: array[0..3] of Integer = (200, 201, 204, 299);
begin
  Fake := TFakeOtelTransport.Create;
  Fake.StatusCode := 200;
  Sink := TPraxoOtelSink.Create('https://otel.test/v1/traces');
  Data := TJSONObject.Create;
  Data.Add('name', 'echo');
  Data.Add('secret', 'hidden');
  Event.Kind := 'tool.call';
  Event.SessionId := 's1';
  Event.RunId := 'run-123';
  Event.Data := Data;
  try
    Sink.Transport := @Fake.Send;
    Sink.Clock := @FakeOtelClock;
    Sink.AllowDataKey('name');
    Sink.Emit(Event);
    Check(Length(Fake.Requests) = 1, 'otel request count');
    Check(Fake.Requests[0].Method = 'POST', 'otel method');
    Check(Fake.Requests[0].URL = 'https://otel.test/v1/traces', 'otel url');
    Check(Fake.Requests[0].ContentType = 'application/json',
      'otel content type');
    Body := Fake.Requests[0].Body;

    Root := TJSONObject(PraxoParseJSON(Body));
    try
      ResourceSpans := TJSONArray(LastField(Root, 'resourceSpans'));
      Check((ResourceSpans <> nil) and (ResourceSpans.Count = 1),
        'otel resource spans');
      ResourceSpan := TJSONObject(ResourceSpans.Items[0]);
      ScopeSpans := TJSONArray(LastField(ResourceSpan, 'scopeSpans'));
      Check((ScopeSpans <> nil) and (ScopeSpans.Count = 1),
        'otel scope spans');
      Scope := TJSONObject(ScopeSpans.Items[0]);
      Check(Str(Scope, 'name') = 'praxo-core', 'otel scope name');
      Spans := TJSONArray(LastField(Scope, 'spans'));
      Check((Spans <> nil) and (Spans.Count = 1), 'otel spans');
      Span := TJSONObject(Spans.Items[0]);
      Check(Str(Span, 'name') = 'praxo.tool.call', 'otel span name');
      Check(Num(Span, 'kind') = 1, 'otel span kind');
      TraceId := Str(Span, 'traceId');
      SpanId := Str(Span, 'spanId');
      Check(Length(TraceId) = 32, 'otel trace id length');
      Check(Length(SpanId) = 16, 'otel span id length');
      Check(Str(Span, 'startTimeUnixNano') = '1794294000000000000',
        'otel start time');
      Check(Str(Span, 'endTimeUnixNano') = '1794294000000000000',
        'otel end time');
      Attributes := TJSONArray(LastField(Span, 'attributes'));
      Check(AttributeValue(Attributes, 'praxo.event.type') = 'tool.call',
        'otel event type attribute');
      Check(AttributeValue(Attributes, 'praxo.session.id') = 's1',
        'otel session attribute');
      Check(AttributeValue(Attributes, 'praxo.run.id') = 'run-123',
        'otel run attribute');
      Check(AttributeValue(Attributes, 'praxo.event.at') =
        '1794294000000000000', 'otel event time attribute');
      Check(AttributeValue(Attributes, 'praxo.event.data.name') = 'echo',
        'otel allowed data');
      Check(not HasAttribute(Attributes, 'praxo.event.data.secret'),
        'otel hidden data');
    finally
      Root.Free;
    end;

    Sink.Emit(Event);
    Check(Fake.Requests[1].Body = Body, 'otel deterministic payload');

    Fake.StatusCode := 200;
    Sink.ServiceName := '';
    SetLength(Fake.Requests, 0);
    Sink.AllowDataKey('secret');
    Sink.Emit(Event);
    Root := TJSONObject(PraxoParseJSON(Fake.Requests[0].Body));
    try
      ResourceSpans := TJSONArray(LastField(Root, 'resourceSpans'));
      ResourceSpan := TJSONObject(ResourceSpans.Items[0]);
      ScopeSpans := TJSONArray(LastField(ResourceSpan, 'scopeSpans'));
      Scope := TJSONObject(ScopeSpans.Items[0]);
      Spans := TJSONArray(LastField(Scope, 'spans'));
      Span := TJSONObject(Spans.Items[0]);
      Attributes := TJSONArray(LastField(Span, 'attributes'));
      Check(AttributeValue(Attributes, 'praxo.event.data.secret') = 'hidden',
        'otel second allowed data');
    finally
      Root.Free;
    end;

    Sink.Free;
    Sink := TPraxoOtelSink.Create('https://otel.test/v1/traces');
    Sink.Transport := @Fake.Send;
    Sink.Clock := @FakeOtelClock;
    SetLength(Fake.Requests, 0);
    Sink.Emit(Event);
    Root := TJSONObject(PraxoParseJSON(Fake.Requests[0].Body));
    try
      ResourceSpans := TJSONArray(LastField(Root, 'resourceSpans'));
      ResourceSpan := TJSONObject(ResourceSpans.Items[0]);
      ScopeSpans := TJSONArray(LastField(ResourceSpan, 'scopeSpans'));
      Scope := TJSONObject(ScopeSpans.Items[0]);
      Spans := TJSONArray(LastField(Scope, 'spans'));
      Span := TJSONObject(Spans.Items[0]);
      Attributes := TJSONArray(LastField(Span, 'attributes'));
      Check(not HasAttribute(Attributes, 'praxo.event.data.name'),
        'otel default data exclusion');
      Check(not HasAttribute(Attributes, 'praxo.event.data.secret'),
        'otel default secret exclusion');
    finally
      Root.Free;
    end;

    for I := 0 to High(Statuses) do
    begin
      Fake.StatusCode := Statuses[I];
      Sink.Emit(Event);
    end;

    Fake.StatusCode := 503;
    Fake.ResponseBody := '';
    for I := 1 to 60 do Fake.ResponseBody := Fake.ResponseBody + 'unavailable ';
    Caught := False;
    try
      Sink.Emit(Event);
    except
      on E: EPraxoOtel do
      begin
        Caught := True;
        Check(E.Code = 'OTEL_HTTP', 'otel error code');
        Check(E.Status = 503, 'otel error status');
        Check(Pos('503', E.Message) > 0, 'otel error status text');
        Check(Pos('unavailable', E.Message) > 0, 'otel error body');
        Check(Length(E.Message) <= 600, 'otel error bounded');
      end;
    end;
    Check(Caught, 'otel non-2xx raises');

    Sink.Endpoint := '';
    Sink.Free;
    Sink := TPraxoOtelSink.Create('');
    Sink.Transport := @Fake.Send;
    Sink.Clock := @FakeOtelClock;
    SetLength(Fake.Requests, 0);
    Caught := False;
    try
      Sink.Emit(Event);
    except
      on E: EPraxoOtel do
      begin
        Caught := True;
        Check(E.Code = 'OTEL_URL', 'otel url code');
      end;
    end;
    Check(Caught, 'otel missing endpoint raises');
    Check(Length(Fake.Requests) = 0, 'otel missing endpoint skips transport');
  finally
    Event.Data.Free;
    Sink.Free;
    Fake.Free;
  end;
  WriteLn('test_otel passed');
end;

function EchoRetriever(const Query: UTF8String; Limit: Integer): TPraxoDocuments;
begin
  LastQuery := Query;
  LastLimit := Limit;
  Inc(RetrieverCalls);
  Result := nil;
  SetLength(Result, 1);
  Result[0] := PraxoDocument('doc-1', Query + ':' + IntToStr(Limit));
end;

procedure TestRetriever;
var
  Documents: TPraxoDocuments;
  Metadata: TJSONObject;
  Single: TPraxoDocument;
  Caught: Boolean;
  Calls: Integer;
begin
  LastQuery := '';
  LastLimit := -1;
  RetrieverCalls := 0;
  Documents := PraxoRetrieveDocuments(@EchoRetriever, 'hello', 3);
  Check(Length(Documents) = 1, 'retriever count');
  Check(Documents[0].Id = 'doc-1', 'retriever id');
  Check(Documents[0].Content = 'hello:3', 'retriever query and limit');
  Check(LastQuery = 'hello', 'retriever forwarded query');
  Check(LastLimit = 3, 'retriever forwarded limit');

  Metadata := TJSONObject.Create;
  Metadata.Add('source', 'test');
  Single := PraxoDocument('doc-2', 'content', Metadata, 0.75, True);
  Check(Single.Id = 'doc-2', 'document id');
  Check(Single.Content = 'content', 'document content');
  Check(Single.Metadata = Metadata, 'document metadata');
  Check(Single.HasScore and (Abs(Single.Score - 0.75) < 0.0001),
    'document score');
  Metadata.Free;

  Calls := RetrieverCalls;
  Caught := False;
  try
    PraxoRetrieveDocuments(@EchoRetriever, 'hello', -1);
  except
    on E: EPraxoRetriever do
    begin
      Caught := True;
      Check(E.Code = 'RETRIEVER_INVALID', 'retriever invalid code');
    end;
  end;
  Check(Caught, 'retriever negative limit raises');
  Check(RetrieverCalls = Calls, 'retriever invalid limit skips callback');
  WriteLn('test_retriever passed');
end;

function CompleteRunner(const Request: TPraxoSubagentRequest):
  TPraxoSubagentResult;
begin
  Result.TaskId := 'task-1';
  Result.AgentId := Request.AgentId;
  Result.Output := 'done';
end;

function FailRunner(const Request: TPraxoSubagentRequest):
  TPraxoSubagentResult;
begin
  Result.TaskId := '';
  Result.AgentId := '';
  Result.Output := '';
  raise EPraxoDelegation.CreateCode('BOOM', 'boom');
end;

function CrashRunner(const Request: TPraxoSubagentRequest):
  TPraxoSubagentResult;
begin
  Result.TaskId := '';
  Result.AgentId := '';
  Result.Output := '';
  raise Exception.Create('boom');
end;

function FakeDelegationClock: UTF8String;
begin
  Result := '2026-11-13T00:00:00.000Z';
end;

procedure CheckSubagentInvalid(Manager: TPraxoSubagentManager;
  const Request: TPraxoSubagentRequest; const Detail: UTF8String);
var
  Caught: Boolean;
begin
  Caught := False;
  try
    Manager.Run(Request);
  except
    on E: EPraxoDelegation do
    begin
      Caught := True;
      Check(E.Code = 'SUBAGENT_INVALID', Detail);
    end;
  end;
  Check(Caught, Detail);
end;

procedure TestDelegation;
var
  Manager: TPraxoSubagentManager;
  Request: TPraxoSubagentRequest;
  Task: TPraxoSubagentTask;
begin
  Manager := TPraxoSubagentManager.Create;
  try
    Manager.Runner := @CompleteRunner;
    Manager.Clock := @FakeDelegationClock;
    Request.ParentSessionId := 'parent';
    Request.AgentId := 'child';
    Request.Prompt := 'look up';
    Request.Mode := 'fork';

    Task := Manager.Run(Request);
    Check(Task.Id = 'subagent', 'delegate id');
    Check(Task.ParentSessionId = 'parent', 'delegate parent');
    Check(Task.AgentId = 'child', 'delegate agent');
    Check(Task.Mode = 'fork', 'delegate mode');
    Check(Task.Status = 'completed', 'delegate completed');
    Check(Task.Output = 'done', 'delegate output');
    Check(Task.Error = '', 'delegate completed error empty');
    Check(Task.CreatedAt = '2026-11-13T00:00:00.000Z', 'delegate created');
    Check(Task.UpdatedAt = '2026-11-13T00:00:00.000Z', 'delegate updated');

    Request.Mode := 'isolated';
    Manager.Runner := @FailRunner;
    Task := Manager.Run(Request);
    Check(Task.Status = 'failed', 'delegate failed status');
    Check(Task.Error = 'BOOM', 'delegate preserved error code');

    Manager.Runner := @CrashRunner;
    Task := Manager.Run(Request);
    Check(Task.Status = 'failed', 'delegate generic failed status');
    Check(Task.Error = 'SUBAGENT_ERROR', 'delegate generic error code');

    Request.ParentSessionId := '';
    Request.AgentId := 'child';
    CheckSubagentInvalid(Manager, Request, 'delegate empty parent');

    Request.ParentSessionId := 'parent';
    Request.AgentId := '';
    CheckSubagentInvalid(Manager, Request, 'delegate empty agent');
  finally
    Manager.Free;
  end;
  WriteLn('test_delegation passed');
end;

begin
  TestOtel;
  TestRetriever;
  TestDelegation;
  WriteLn('All Delphi adapter tests passed');
end.
