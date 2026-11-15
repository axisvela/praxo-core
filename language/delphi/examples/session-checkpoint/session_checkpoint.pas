program session_checkpoint_example;
{$mode objfpc}{$H+}

uses SysUtils, Classes, fpjson, praxo, praxo_core, praxo_agent;

type
  TTurnHost = class(TPraxoAgentHost)
  public
    function Generate(Messages: TJSONArray): TJSONObject; override;
    function Invoke(const Name: UTF8String; Arguments: TJSONObject): TJSONData; override;
    procedure Emit(const EventType: UTF8String); override;
  end;

var
  Allow: TPraxoStringArray;

function TTurnHost.Generate(Messages: TJSONArray): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('content', 'turn ' + IntToStr(Messages.Count));
  Result.Add('inputTokens', 0);
  Result.Add('outputTokens', 0);
end;

function TTurnHost.Invoke(const Name: UTF8String; Arguments: TJSONObject): TJSONData;
begin
  Result := nil;
  raise Exception.Create('unexpected tool invocation');
end;

procedure TTurnHost.Emit(const EventType: UTF8String);
begin
end;

procedure Check(Condition: Boolean; const Detail: UTF8String);
begin
  if not Condition then raise Exception.Create(Detail);
end;

procedure SaveMessages(Store: TStringList; const SessionId: UTF8String; Messages: TJSONArray);
var Data, Error: UTF8String;
begin
  Error := PraxoCheckpointMarshal(Allow, 'session', Messages, Data);
  if Error <> '' then raise Exception.Create(Error);
  Store.Values[SessionId] := Data;
end;

function LoadMessages(Store: TStringList; const SessionId: UTF8String): TJSONArray;
var Data, Error: UTF8String; Value: TJSONData;
begin
  Data := Store.Values[SessionId];
  if Data = '' then raise Exception.Create('checkpoint not found');
  Value := nil;
  Error := PraxoCheckpointUnmarshal(Allow, Data, Value);
  if Error <> '' then raise Exception.Create(Error);
  Result := TJSONArray(Value);
end;

function NewMessage(const Role, Content: UTF8String): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('role', Role);
  Result.Add('content', Content);
end;

var
  Store: TStringList;
  Seed, Prior, Saved: TJSONArray;
  Options: TPraxoAgentOptions;
  Host: TTurnHost;
  FirstRun, SecondRun: TPraxoAgentResult;
begin
  Allow := PraxoCheckpointNew;
  PraxoCheckpointRegister(Allow, 'session');
  Store := TStringList.Create;
  Host := TTurnHost.Create;
  try
    Seed := TJSONArray.Create;
    Seed.Add(NewMessage('user', 'first'));
    Seed.Add(NewMessage('assistant', 'ack'));
    SaveMessages(Store, 'session-1', Seed);
    Seed.Free;

    Prior := LoadMessages(Store, 'session-1');
    try
      Options := PraxoAgentOptionsNew;
      Options.MaxSteps := 2;
      Options.SessionId := 'session-1';
      FirstRun := PraxoRunAgentSession(Host, Prior, 'second', Options);
      try
        Check(FirstRun.Output = 'turn 3', 'unexpected second turn: ' + FirstRun.Output);
        Check(FirstRun.Messages.Count = 4, 'second turn history');
        SaveMessages(Store, 'session-1', FirstRun.Messages);
      finally
        FirstRun.Messages.Free;
      end;
    finally
      Prior.Free;
    end;

    Saved := LoadMessages(Store, 'session-1');
    try
      Check(Saved.Count = 4, 'restored message count');
      Options := PraxoAgentOptionsNew;
      Options.MaxSteps := 2;
      Options.SessionId := 'session-1';
      SecondRun := PraxoRunAgentSession(Host, Saved, 'third', Options);
      try
        Check(SecondRun.Output = 'turn 5', 'unexpected third turn: ' + SecondRun.Output);
        WriteLn('restored messages: ', Saved.Count);
        WriteLn('output: ', SecondRun.Output);
      finally
        SecondRun.Messages.Free;
      end;
    finally
      Saved.Free;
    end;
  finally
    Host.Free;
    Store.Free;
  end;
end.
