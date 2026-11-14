program event_sink_example;

{$mode objfpc}{$H+}

uses fpjson, praxo_core;

function Contains(const Values: TPraxoStringArray; const Value: UTF8String): Boolean;
var
  I: Integer;
begin
  for I := 0 to High(Values) do
    if Values[I] = Value then Exit(True);
  Result := False;
end;

var
  All, Tool, Filter, Multi: TPraxoEventSink;
  Event: TPraxoEvent;
  Predicate: TPraxoStringArray;
begin
  All := PraxoEventNew;
  Tool := PraxoEventNew;
  Predicate := ['tool.call'];
  Filter := PraxoEventFilter(Tool, Predicate);
  Multi := PraxoEventMulti([All, Filter]);
  Event.Kind := 'run.started';
  Event.SessionId := 's1';
  Event.RunId := '';
  Event.Data := GetJSON('null');
  PraxoEventEmit(Multi, Event);
  Event.Kind := 'tool.call';
  PraxoEventEmit(Multi, Event);
  Event.Kind := 'run.completed';
  PraxoEventEmit(Multi, Event);
  if Length(All.Kinds) <> 3 then Halt(1);
  if (Length(Tool.Kinds) <> 1) or (not Contains(Tool.Kinds, 'tool.call')) then Halt(1);
  WriteLn('Delphi event sink example passed');
end.
