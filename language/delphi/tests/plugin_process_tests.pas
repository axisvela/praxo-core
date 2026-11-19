program plugin_process_tests;

{$mode objfpc}{$H+}

uses
  SysUtils, praxo_plugin_process;

var
  Config: TPraxoPluginProcessConfig;
  Host: TPraxoPluginProcess;
  Response: RawByteString;
begin
  Config.PluginId := 'com.example.echo';
  Config.Path := 'C:\Python314\python.exe';
  Config.Args := ['tests\fixtures\process_plugin.py'];
  Config.Token := '';
  Config.StartTimeoutMs := 10000;
  Config.InvokeTimeoutMs := 30000;
  Host := TPraxoPluginProcess.Create(Config);
  try
    Host.Start;
    Response := Host.Invoke('tool.provider', 'echo', '{"text":"hi"}');
    if Response <> '{"text":"hi"}' then
      raise Exception.Create('unexpected response: ' + Response);
    WriteLn('delphi plugin process tests passed');
  finally
    Host.Free;
  end;
end.
