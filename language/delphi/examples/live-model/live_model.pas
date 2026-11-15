program live_model_example;

{$mode objfpc}{$H+}

uses SysUtils, DateUtils, fpjson, praxo_agent, praxo_openai;

type
  TLiveHost = class(TPraxoAgentHost)
  private
    FAdapter: TPraxoOpenAIAdapter;
    FTools: TJSONArray;
  public
    constructor Create(const BaseURL, Model, APIKey: UTF8String);
    destructor Destroy; override;
    function Generate(Messages: TJSONArray): TJSONObject; override;
    function Invoke(const Name: UTF8String; Arguments: TJSONObject): TJSONData; override;
    procedure Emit(const EventType: UTF8String); override;
  end;

function EnvOr(const Name, Fallback: UTF8String): UTF8String;
begin
  Result := GetEnvironmentVariable(Name);
  if Result = '' then Result := Fallback;
end;

function LivePolicy(const Kind: UTF8String): Boolean;
begin
  Result := (Kind = 'model.generate') or (Kind = 'tool.invoke');
end;

constructor TLiveHost.Create(const BaseURL, Model, APIKey: UTF8String);
begin
  inherited Create;
  FAdapter := TPraxoOpenAIAdapter.Create(BaseURL, Model);
  FAdapter.APIKey := APIKey;
  FTools := TJSONArray.Create;
  FTools.Add(GetJSON(
    '{"name":"get_time","description":"Return the current time in ISO 8601 format for the requested zone.",'
    + '"parameters":{"type":"object","properties":{"zone":{"type":"string",'
    + '"enum":["utc","local"],"description":"utc or local; defaults to utc"}}}}'
  ));
  FAdapter.Tools := FTools;
end;

destructor TLiveHost.Destroy;
begin
  FAdapter.Free;
  FTools.Free;
  inherited Destroy;
end;

function TLiveHost.Generate(Messages: TJSONArray): TJSONObject;
begin
  Result := FAdapter.Generate(Messages);
end;

function TLiveHost.Invoke(const Name: UTF8String; Arguments: TJSONObject): TJSONData;
var
  Zone, Value: string;
begin
  if Name <> 'get_time' then
    raise EPraxoAgent.CreateCode('TOOL_NOT_FOUND', 'unknown tool: ' + Name);
  Zone := Arguments.Get('zone', 'utc');
  if Zone = 'local' then
    Value := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Now)
  else
    Value := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss"Z"', LocalTimeToUniversal(Now));
  Result := TJSONString.Create(Value);
end;

procedure TLiveHost.Emit(const EventType: UTF8String);
begin
end;

const
  DefaultBaseURL = 'http://localhost:11434/v1';
  DefaultModel = 'qwen3.5:4b';
  DefaultPrompt = 'What time is it? Use get_time with zone set to utc and reply with the time.';

var
  Host: TLiveHost;
  Allowed: TPraxoAgentStringArray;
  Result: TPraxoAgentResult;
  BaseURL, ModelName, APIKey, Prompt, ErrorMessage: UTF8String;

begin
  BaseURL := EnvOr('PRAXO_BASE_URL', DefaultBaseURL);
  ModelName := EnvOr('PRAXO_MODEL', DefaultModel);
  APIKey := EnvOr('PRAXO_API_KEY', '');
  Prompt := EnvOr('PRAXO_PROMPT', DefaultPrompt);

  Host := TLiveHost.Create(BaseURL, ModelName, APIKey);
  try
    SetLength(Allowed, 1);
    Allowed[0] := 'get_time';
    ErrorMessage := '';
    try
      Result := PraxoRunAgent(Host, Prompt, 4, 0, False, @LivePolicy,
        True, Allowed);
    except
      on E: Exception do ErrorMessage := E.Message;
    end;
  finally
    Host.Free;
  end;

  if ErrorMessage <> '' then
  begin
    WriteLn(StdErr, 'live model run failed: ', ErrorMessage);
    WriteLn(StdErr);
    WriteLn(StdErr, 'Check PRAXO_BASE_URL (', BaseURL, '), PRAXO_MODEL (',
      ModelName, '), and PRAXO_API_KEY');
    Halt(1);
  end;
  WriteLn(Result.Output);
end.
