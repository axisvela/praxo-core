unit praxo_otel;
{$mode objfpc}{$H+}

interface

uses SysUtils, fpjson, praxo, praxo_core;

type
  EPraxoOtel = class(Exception)
  public
    Code: UTF8String;
    Status: Integer;
    constructor CreateCode(const ACode, AMessage: UTF8String; AStatus: Integer = 0);
  end;

  TPraxoOtelKeys = array of UTF8String;

  TPraxoOtelRequest = record
    Method, URL, ContentType, Body: UTF8String;
  end;

  TPraxoOtelResponse = record
    StatusCode: Integer;
    Body: UTF8String;
  end;

  TPraxoOtelTransport = function(const Request: TPraxoOtelRequest):
    TPraxoOtelResponse of object;
  TPraxoOtelClock = function: Int64;

  TPraxoOtelSink = class
  private
    FEndpoint, FServiceName: UTF8String;
    FAllowedDataKeys: TPraxoOtelKeys;
    FTransport: TPraxoOtelTransport;
    FClock: TPraxoOtelClock;
    function Send(const Request: TPraxoOtelRequest): TPraxoOtelResponse;
  public
    constructor Create(const AEndpoint: UTF8String);
    procedure AllowDataKey(const Key: UTF8String);
    procedure Emit(const Event: TPraxoEvent);
    property Endpoint: UTF8String read FEndpoint write FEndpoint;
    property ServiceName: UTF8String read FServiceName write FServiceName;
    property AllowedDataKeys: TPraxoOtelKeys read FAllowedDataKeys write FAllowedDataKeys;
    property Transport: TPraxoOtelTransport read FTransport write FTransport;
    property Clock: TPraxoOtelClock read FClock write FClock;
  end;

implementation

uses Classes, DateUtils, fphttpclient;

const
  MaxOtelBody = 512;

constructor EPraxoOtel.CreateCode(const ACode, AMessage: UTF8String;
  AStatus: Integer);
begin
  inherited Create(AMessage);
  Code := ACode;
  Status := AStatus;
end;

function DefaultOtelClock: Int64;
var
  Utc: TDateTime;
  Year, Month, Day, Hour, Minute, Second, Milli: Word;
begin
  Utc := LocalTimeToUniversal(Now);
  DecodeDateTime(Utc, Year, Month, Day, Hour, Minute, Second, Milli);
  Result := DateTimeToUnix(Utc, True) * Int64(1000000000) +
    Int64(Milli) * 1000000;
end;

function StableId(const Text: UTF8String): UTF8String;
var
  I: Integer;
  Hash: LongWord;
begin
  Hash := LongWord($811C9DC5);
  for I := 1 to Length(Text) do
  begin
    Hash := Hash xor LongWord(Ord(Text[I]));
    Hash := LongWord((QWord(Hash) * QWord($01000193)) and QWord($FFFFFFFF));
  end;
  Result := LowerCase(IntToHex(Int64(Hash), 8));
end;

function OtelText(Value: TJSONData): UTF8String;
begin
  if Value = nil then Exit('');
  if Value.JSONType = jtNull then Exit('');
  if Value.JSONType = jtString then Exit(Value.AsString);
  Result := PraxoEncodeJSON(Value);
end;

function OtelAttribute(const Key, Value: UTF8String): TJSONObject;
var
  ValueObject: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('key', Key);
  ValueObject := TJSONObject.Create;
  ValueObject.Add('stringValue', Value);
  Result.Add('value', ValueObject);
end;

function EventKey(const Event: TPraxoEvent; const Stamp: UTF8String): UTF8String;
var
  DataText: UTF8String;
begin
  if Event.Data = nil then DataText := ''
  else DataText := PraxoEncodeJSON(Event.Data);
  Result := Event.SessionId + '|' + Event.RunId + '|' + Event.Kind + '|' +
    Stamp + '|' + DataText;
end;

function BuildPayload(Sink: TPraxoOtelSink; const Event: TPraxoEvent;
  Nanos: Int64): TJSONObject;
var
  Key, Stamp, TraceId, SpanId, Service, Name, Text: UTF8String;
  Data: TJSONObject;
  Value: TJSONData;
  I: Integer;
  Attributes, ResourceAttributes, ScopeSpans, Spans, ResourceSpans: TJSONArray;
  Span, Scope, Resource, ResourceSpan: TJSONObject;
begin
  Stamp := IntToStr(Nanos);
  Key := EventKey(Event, Stamp);
  TraceId := StableId('trace-a:' + Key) + StableId('trace-b:' + Key) +
    StableId('trace-c:' + Key) + StableId('trace-d:' + Key);
  SpanId := StableId('span-a:' + Key) + StableId('span-b:' + Key);

  Attributes := TJSONArray.Create;
  Attributes.Add(OtelAttribute('praxo.event.type', Event.Kind));
  if Event.SessionId <> '' then
    Attributes.Add(OtelAttribute('praxo.session.id', Event.SessionId));
  if Event.RunId <> '' then
    Attributes.Add(OtelAttribute('praxo.run.id', Event.RunId));
  Attributes.Add(OtelAttribute('praxo.event.at', Stamp));
  if (Event.Data <> nil) and (Event.Data.JSONType = jtObject) then
  begin
    Data := TJSONObject(Event.Data);
    for I := 0 to High(Sink.AllowedDataKeys) do
    begin
      Name := Sink.AllowedDataKeys[I];
      Value := Data.Find(Name);
      if Value <> nil then
      begin
        Text := OtelText(Value);
        Attributes.Add(OtelAttribute('praxo.event.data.' + Name, Text));
      end;
    end;
  end;

  Span := TJSONObject.Create;
  Span.Add('traceId', TraceId);
  Span.Add('spanId', SpanId);
  Span.Add('name', 'praxo.' + Event.Kind);
  Span.Add('kind', 1);
  Span.Add('startTimeUnixNano', Stamp);
  Span.Add('endTimeUnixNano', Stamp);
  Span.Add('attributes', Attributes);

  Spans := TJSONArray.Create;
  Spans.Add(Span);
  Scope := TJSONObject.Create;
  Scope.Add('name', 'praxo-core');
  Scope.Add('spans', Spans);
  ScopeSpans := TJSONArray.Create;
  ScopeSpans.Add(Scope);

  Service := Sink.ServiceName;
  if Service = '' then Service := 'praxo-core';
  ResourceAttributes := TJSONArray.Create;
  ResourceAttributes.Add(OtelAttribute('service.name', Service));
  Resource := TJSONObject.Create;
  Resource.Add('attributes', ResourceAttributes);
  ResourceSpan := TJSONObject.Create;
  ResourceSpan.Add('resource', Resource);
  ResourceSpan.Add('scopeSpans', ScopeSpans);
  ResourceSpans := TJSONArray.Create;
  ResourceSpans.Add(ResourceSpan);

  Result := TJSONObject.Create;
  Result.Add('resourceSpans', ResourceSpans);
end;

constructor TPraxoOtelSink.Create(const AEndpoint: UTF8String);
begin
  inherited Create;
  FEndpoint := AEndpoint;
  FServiceName := 'praxo-core';
  SetLength(FAllowedDataKeys, 0);
  FClock := @DefaultOtelClock;
end;

procedure TPraxoOtelSink.AllowDataKey(const Key: UTF8String);
var
  Count: Integer;
begin
  Count := Length(FAllowedDataKeys);
  SetLength(FAllowedDataKeys, Count + 1);
  FAllowedDataKeys[Count] := Key;
end;

procedure TPraxoOtelSink.Emit(const Event: TPraxoEvent);
var
  Request: TPraxoOtelRequest;
  Response: TPraxoOtelResponse;
  Payload: TJSONObject;
  Sender: TPraxoOtelTransport;
  Nanos: Int64;
  Target: UTF8String;
begin
  Target := Trim(FEndpoint);
  if Target = '' then
    raise EPraxoOtel.CreateCode('OTEL_URL', 'otel: endpoint is required');
  Nanos := DefaultOtelClock;
  if Assigned(FClock) then Nanos := FClock();
  Payload := BuildPayload(Self, Event, Nanos);
  try
    Request.Method := 'POST';
    Request.URL := Target;
    Request.ContentType := 'application/json';
    Request.Body := PraxoEncodeJSON(Payload);
  finally
    Payload.Free;
  end;
  Sender := FTransport;
  if Assigned(Sender) then Response := Sender(Request) else Response := Send(Request);
  if (Response.StatusCode < 200) or (Response.StatusCode >= 300) then
    raise EPraxoOtel.CreateCode('OTEL_HTTP',
      'otel: HTTP ' + IntToStr(Response.StatusCode) + ': ' +
      Copy(Trim(Response.Body), 1, MaxOtelBody), Response.StatusCode);
end;

function TPraxoOtelSink.Send(const Request: TPraxoOtelRequest):
  TPraxoOtelResponse;
var
  Client: TFPHTTPClient;
  RequestStream, ResponseStream: TStringStream;
begin
  Result.StatusCode := 0;
  Result.Body := '';
  Client := TFPHTTPClient.Create(nil);
  RequestStream := TStringStream.Create(Request.Body);
  ResponseStream := TStringStream.Create('');
  try
    Client.RequestBody := RequestStream;
    Client.AddHeader('Content-Type', Request.ContentType);
    try
      Client.HTTPMethod(Request.Method, Request.URL, ResponseStream, []);
      Result.StatusCode := Client.ResponseStatusCode;
      Result.Body := ResponseStream.DataString;
    except
      on E: Exception do
      begin
        Result.StatusCode := Client.ResponseStatusCode;
        Result.Body := ResponseStream.DataString;
        if Result.StatusCode < 400 then
          raise EPraxoOtel.CreateCode('OTEL_HTTP',
            'otel: request failed: ' + E.Message);
      end;
    end;
  finally
    Client.Free;
    RequestStream.Free;
    ResponseStream.Free;
  end;
end;

end.
