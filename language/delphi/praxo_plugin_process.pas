unit praxo_plugin_process;
{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Process, fpjson, jsonparser, base64;

const
  PraxoPluginProtocolVersion = 1;
  PraxoPluginControlService = 'host.control';
  PraxoPluginHealth = 'health';
  PraxoPluginShutdown = 'shutdown';
  PraxoPluginTokenEnv = 'PRAXOVELA_PLUGIN_TOKEN';

type
  EPraxoPluginProcess = class(Exception);

  TPraxoPluginProcessConfig = record
    PluginId: string;
    Path: string;
    Args: array of string;
    Token: string;
    StartTimeoutMs: Cardinal;
    InvokeTimeoutMs: Cardinal;
  end;

  TPraxoPluginProcess = class
  private
    FConfig: TPraxoPluginProcessConfig;
    FToken: string;
    FProcess: TProcess;
    FSeq: Integer;
    FActive: Boolean;
    function Call(const Service, Method: string; const Payload: RawByteString): RawByteString;
  public
    constructor Create(const Config: TPraxoPluginProcessConfig);
    destructor Destroy; override;
    procedure Start;
    function Invoke(const Service, Method: string;
      const Payload: RawByteString = ''): RawByteString;
    procedure Stop;
    property Active: Boolean read FActive;
  end;

implementation

constructor TPraxoPluginProcess.Create(const Config: TPraxoPluginProcessConfig);
var
  Guid: TGUID;
begin
  if Config.PluginId = '' then
    raise EPraxoPluginProcess.Create('plugin: PluginID is required');
  if Config.Path = '' then
    raise EPraxoPluginProcess.Create('plugin: path is required');
  FConfig := Config;
  if FConfig.Token <> '' then
    FToken := FConfig.Token
  else
  begin
    CreateGUID(Guid);
    FToken := GUIDToString(Guid);
  end;
end;

destructor TPraxoPluginProcess.Destroy;
begin
  Stop;
  inherited Destroy;
end;

procedure TPraxoPluginProcess.Start;
var
  I: Integer;
begin
  if FProcess <> nil then
    raise EPraxoPluginProcess.Create('plugin: host already started');
  FProcess := TProcess.Create(nil);
  FProcess.Executable := FConfig.Path;
  for I := 0 to High(FConfig.Args) do
    FProcess.Parameters.Add(FConfig.Args[I]);
  FProcess.Options := [poUsePipes];
  FProcess.Environment.Add(PraxoPluginTokenEnv + '=' + FToken);
  FProcess.Execute;
  try
    Call(PraxoPluginControlService, PraxoPluginHealth, '');
  except
    Stop;
    raise;
  end;
  FActive := True;
end;

procedure TPraxoPluginProcess.Stop;
begin
  if FProcess = nil then
    Exit;
  if FActive then
  begin
    try
      Call(PraxoPluginControlService, PraxoPluginShutdown, '');
    except
    end;
  end;
  FActive := False;
  FProcess.Terminate(0);
  FreeAndNil(FProcess);
end;

function TPraxoPluginProcess.Call(const Service, Method: string;
  const Payload: RawByteString): RawByteString;
var
  Frame: TJSONObject;
  Line: string;
  Data: TJSONData;
  Response: TJSONObject;
  Encoded: string;
  Ch: Char;
begin
  Inc(FSeq);
  Frame := TJSONObject.Create;
  try
    Frame.Add('id', 'req-' + IntToStr(FSeq));
    Frame.Add('version', PraxoPluginProtocolVersion);
    Frame.Add('plugin_id', FConfig.PluginId);
    Frame.Add('service', Service);
    Frame.Add('method', Method);
    Frame.Add('token', FToken);
    Frame.Add('payload', EncodeStringBase64(Payload));
    Line := Frame.AsJSON + #10;
  finally
    Frame.Free;
  end;
  FProcess.Input.Write(Line[1], Length(Line));
  Line := '';
  repeat
    Ch := #0;
    if FProcess.Output.Read(Ch, 1) <> 1 then
      raise EPraxoPluginProcess.Create('plugin: process closed the stream');
    if Ch <> #10 then
      Line := Line + Ch;
  until Ch = #10;
  Data := GetJSON(Line);
  try
    Response := Data as TJSONObject;
    if not Response.Booleans['ok'] then
      raise EPraxoPluginProcess.Create(Response.Strings['message']);
    Encoded := Response.Strings['payload'];
    if Encoded = '' then
      Result := ''
    else
      Result := DecodeStringBase64(Encoded);
  finally
    Data.Free;
  end;
end;

function TPraxoPluginProcess.Invoke(const Service, Method: string;
  const Payload: RawByteString): RawByteString;
begin
  if not FActive then
    raise EPraxoPluginProcess.Create('plugin: host is not active');
  Result := Call(Service, Method, Payload);
end;

end.
