unit praxo_harmovela;
{$mode objfpc}{$H+}

interface

uses SysUtils, fpjson, praxo, praxo_core;

type
  EPraxoHarmovela = class(Exception)
  public
    Code: UTF8String;
    Status: Integer;
    constructor CreateCode(const ACode, AMessage: UTF8String; AStatus: Integer = 0);
  end;

  TPraxoHarmovelaRequest = record
    Method, URL, ContentType, Body: UTF8String;
  end;

  TPraxoHarmovelaResponse = record
    StatusCode: Integer;
    Body: UTF8String;
  end;

  TPraxoHarmovelaTransport = function(const Request: TPraxoHarmovelaRequest):
    TPraxoHarmovelaResponse of object;
  TPraxoHarmovelaClock = function: Int64;

  TPraxoHarmovelaSink = class
  private
    FBaseURL, FSource, FSpecVersion: UTF8String;
    FTransport: TPraxoHarmovelaTransport;
    FClock: TPraxoHarmovelaClock;
    function Send(const Request: TPraxoHarmovelaRequest): TPraxoHarmovelaResponse;
  public
    constructor Create(const ABaseURL: UTF8String);
    procedure Emit(const Event: TPraxoEvent);
    property BaseURL: UTF8String read FBaseURL write FBaseURL;
    property Source: UTF8String read FSource write FSource;
    property SpecVersion: UTF8String read FSpecVersion write FSpecVersion;
    property Transport: TPraxoHarmovelaTransport read FTransport write FTransport;
    property Clock: TPraxoHarmovelaClock read FClock write FClock;
  end;

function PraxoHarmovelaTimestamp(Nanos: Int64): UTF8String;

implementation

uses Classes, DateUtils, fphttpclient;

constructor EPraxoHarmovela.CreateCode(const ACode, AMessage: UTF8String;
  AStatus: Integer);
begin
  inherited Create(AMessage);
  Code := ACode;
  Status := AStatus;
end;

function DefaultClock: Int64;
var
  Utc: TDateTime;
  Year, Month, Day, Hour, Minute, Second, Milli: Word;
begin
  Utc := LocalTimeToUniversal(Now);
  DecodeDateTime(Utc, Year, Month, Day, Hour, Minute, Second, Milli);
  Result := DateTimeToUnix(Utc, True) * Int64(1000000000) +
    Int64(Milli) * 1000000;
end;

function PraxoHarmovelaTimestamp(Nanos: Int64): UTF8String;
var
  Seconds, Fraction: Int64;
  DateValue: TDateTime;
begin
  Seconds := Nanos div Int64(1000000000);
  Fraction := Nanos mod Int64(1000000000);
  if Fraction < 0 then
  begin
    Fraction := Fraction + Int64(1000000000);
    Dec(Seconds);
  end;
  DateValue := UnixToDateTime(Seconds, True);
  Result := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', DateValue) + '.' +
    Format('%.9d', [Fraction]) + 'Z';
end;

function BuildEnvelope(Sink: TPraxoHarmovelaSink; const Event: TPraxoEvent;
  Nanos: Int64): TJSONObject;
var
  Payload: TJSONObject;
  Data: TJSONObject;
  I: Integer;
  Name, Prefix, Source, Spec: UTF8String;
begin
  Payload := TJSONObject.Create;
  try
    if (Event.Data <> nil) and (Event.Data.JSONType = jtObject) then
    begin
      Data := TJSONObject(Event.Data);
      for I := 0 to Data.Count - 1 do
      begin
        Name := Data.Names[I];
        if ((Name <> 'session_id') or (Event.SessionId = '')) and
           ((Name <> 'run_id') or (Event.RunId = '')) then
          Payload.Add(Name, Data.Items[I].Clone);
      end;
    end;
    if Event.SessionId <> '' then Payload.Add('session_id', Event.SessionId);
    if Event.RunId <> '' then Payload.Add('run_id', Event.RunId);
    if Event.RunId <> '' then Prefix := Event.RunId
    else if Event.SessionId <> '' then Prefix := Event.SessionId
    else Prefix := 'event';
    if Sink.Source = '' then Source := 'praxo-core' else Source := Sink.Source;
    if Sink.SpecVersion = '' then Spec := '0.2' else Spec := Sink.SpecVersion;
    Result := TJSONObject.Create;
    try
      Result.Add('spec_version', Spec);
      Result.Add('id', Prefix + '-' + IntToStr(Nanos));
      Result.Add('type', Event.Kind);
      Result.Add('source', Source);
      Result.Add('created_at', PraxoHarmovelaTimestamp(Nanos));
      Result.Add('payload', Payload);
      Payload := nil;
    except
      Result.Free;
      raise;
    end;
  finally
    Payload.Free;
  end;
end;

constructor TPraxoHarmovelaSink.Create(const ABaseURL: UTF8String);
begin
  inherited Create;
  FBaseURL := ABaseURL;
  FSource := 'praxo-core';
  FSpecVersion := '0.2';
  FClock := @DefaultClock;
end;

procedure TPraxoHarmovelaSink.Emit(const Event: TPraxoEvent);
var
  Request: TPraxoHarmovelaRequest;
  Response: TPraxoHarmovelaResponse;
  Envelope: TJSONObject;
  Sender: TPraxoHarmovelaTransport;
  Nanos: Int64;
  Base: UTF8String;
begin
  if FBaseURL = '' then
    raise EPraxoHarmovela.CreateCode('HARMOVELA_URL',
      'harmovela: base URL is required');
  Nanos := DefaultClock;
  if Assigned(FClock) then Nanos := FClock();
  Envelope := BuildEnvelope(Self, Event, Nanos);
  try
    Base := FBaseURL;
    while (Length(Base) > 0) and (Base[Length(Base)] = '/') do
      Delete(Base, Length(Base), 1);
    Request.Method := 'POST';
    Request.URL := Base + '/events';
    Request.ContentType := 'application/json';
    Request.Body := PraxoEncodeJSON(Envelope);
  finally
    Envelope.Free;
  end;
  Sender := FTransport;
  if Assigned(Sender) then Response := Sender(Request) else Response := Send(Request);
  if (Response.StatusCode < 200) or (Response.StatusCode >= 300) then
    raise EPraxoHarmovela.CreateCode('HARMOVELA_HTTP',
      'harmovela: HTTP ' + IntToStr(Response.StatusCode) + ': ' +
      Copy(Trim(Response.Body), 1, 512), Response.StatusCode);
end;

function TPraxoHarmovelaSink.Send(const Request: TPraxoHarmovelaRequest):
  TPraxoHarmovelaResponse;
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
          raise EPraxoHarmovela.CreateCode('HARMOVELA_HTTP',
            'harmovela: request failed: ' + E.Message);
      end;
    end;
  finally
    Client.Free;
    RequestStream.Free;
    ResponseStream.Free;
  end;
end;

end.
