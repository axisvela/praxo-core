program streaming_example;

{$mode objfpc}{$H+}

var
  Chunks: array[0..1] of string = ('status: ', 'green');
  Received, Output: string;
  I: Integer;
begin
  Received := '';
  Output := '';
  for I := Low(Chunks) to High(Chunks) do
  begin
    Output := Output + Chunks[I];
    Received := Received + Chunks[I];
  end;
  if (Output <> 'status: green') or (Received <> Output) then Halt(1);
  WriteLn('Delphi streaming example passed');
end.
