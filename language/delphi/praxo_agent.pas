unit praxo_agent;
{$mode objfpc}{$H+}

interface

uses SysUtils, fpjson;

type
  EPraxoAgent = class(Exception)
  public
    Code: UTF8String;
    constructor CreateCode(const ACode, AMessage: UTF8String);
  end;

  TPraxoAgentHost = class
  public
    function Generate(Messages: TJSONArray): TJSONObject; virtual; abstract;
    function Invoke(const Name: UTF8String; Arguments: TJSONObject): TJSONData; virtual; abstract;
    procedure Emit(const EventType: UTF8String); virtual; abstract;
  end;

  TPraxoAgentResult = record
    Output: UTF8String;
    Steps: Integer;
    InputTokens: Int64;
    OutputTokens: Int64;
  end;

function PraxoRunAgent(Host: TPraxoAgentHost; const Prompt: UTF8String; MaxSteps: Integer; MaxTokens: Int64): TPraxoAgentResult;

implementation

uses praxo;

constructor EPraxoAgent.CreateCode(const ACode, AMessage: UTF8String);
begin
  inherited Create(AMessage);
  Code := ACode;
end;

function StringValue(Obj: TJSONObject; const Name: UTF8String): UTF8String;
var V: TJSONData;
begin
  V := Obj.Find(Name);
  if (V = nil) or (V.JSONType <> jtString) then
    raise EPraxoAgent.CreateCode('AGENT_INVALID_RESPONSE', 'Expected string: ' + Name);
  Result := V.AsString;
end;

function Tokens(Obj: TJSONObject; const Name: UTF8String): Int64;
var V: TJSONData;
begin
  V := Obj.Find(Name);
  if V = nil then Exit(0);
  if (V.JSONType <> jtNumber) or (V.AsFloat < 0) or
    (V.AsFloat >= 9223372036854775808.0) or (Frac(V.AsFloat) <> 0) then
    raise EPraxoAgent.CreateCode('AGENT_INVALID_RESPONSE', 'Invalid token count: ' + Name);
  Result := V.AsInt64;
end;

function PraxoRunAgent(Host: TPraxoAgentHost; const Prompt: UTF8String; MaxSteps: Integer; MaxTokens: Int64): TPraxoAgentResult;
var
  Messages, Calls: TJSONArray;
  Response, Message, Call, Args: TJSONObject;
  V, ToolResult: TJSONData;
  Step, I: Integer;
  InputCount, OutputCount: Int64;
  Name, ID, Content, Encoded: UTF8String;
begin
  Result.Output := '';
  Result.Steps := 0;
  Result.InputTokens := 0;
  Result.OutputTokens := 0;
  if Host = nil then
    raise EPraxoAgent.CreateCode('AGENT_INVALID_HOST', 'Agent host is required');
  if MaxSteps <= 0 then MaxSteps := 8;
  Messages := TJSONArray.Create;
  try
    try
      Message := TJSONObject.Create;
      Message.Add('role', 'user');
      Message.Add('content', Prompt);
      Messages.Add(Message);
      Host.Emit('run.started');
      for Step := 1 to MaxSteps do
      begin
        Response := Host.Generate(Messages);
        if Response = nil then
          raise EPraxoAgent.CreateCode('AGENT_INVALID_RESPONSE', 'Model returned nil');
        try
          Content := StringValue(Response, 'content');
          InputCount := Tokens(Response, 'inputTokens');
          OutputCount := Tokens(Response, 'outputTokens');
          if (InputCount > High(Int64) - Result.InputTokens) or
             (OutputCount > High(Int64) - Result.OutputTokens) then
            raise EPraxoAgent.CreateCode('AGENT_INVALID_RESPONSE', 'Token count overflow');
          Inc(Result.InputTokens, InputCount);
          Inc(Result.OutputTokens, OutputCount);
          if (MaxTokens > 0) and ((Result.InputTokens > MaxTokens) or
            (Result.OutputTokens > MaxTokens - Result.InputTokens)) then
            raise EPraxoAgent.CreateCode('AGENT_MAX_TOKENS', 'Token budget exceeded');
          V := Response.Find('toolCalls');
          if (V <> nil) and (V.JSONType <> jtArray) then
            raise EPraxoAgent.CreateCode('AGENT_INVALID_RESPONSE', 'toolCalls must be an array');
          Calls := TJSONArray(V);
          Message := TJSONObject.Create;
          Message.Add('role', 'assistant');
          Message.Add('content', Content);
          if Calls <> nil then Message.Add('toolCalls', Calls.Clone);
          Messages.Add(Message);
          if (Calls = nil) or (Calls.Count = 0) then
          begin
            Result.Output := Content;
            Result.Steps := Step;
            Host.Emit('run.completed');
            Exit;
          end;
          for I := 0 to Calls.Count - 1 do
          begin
            if Calls.Items[I].JSONType <> jtObject then
              raise EPraxoAgent.CreateCode('AGENT_INVALID_RESPONSE', 'Invalid tool call');
            Call := TJSONObject(Calls.Items[I]);
            Name := StringValue(Call, 'name');
            ID := StringValue(Call, 'id');
            V := Call.Find('arguments');
            if (Name = '') or (V = nil) or (V.JSONType <> jtObject) then
              raise EPraxoAgent.CreateCode('AGENT_INVALID_RESPONSE', 'Invalid tool arguments or name');
            Args := TJSONObject(V);
            Host.Emit('tool.call');
            ToolResult := Host.Invoke(Name, Args);
            if ToolResult = nil then
              raise EPraxoAgent.CreateCode('AGENT_INVALID_RESPONSE', 'Tool returned nil');
            try
              Encoded := PraxoEncodeJSON(ToolResult);
              Message := TJSONObject.Create;
              Message.Add('role', 'tool');
              Message.Add('toolCallId', ID);
              Message.Add('content', Encoded);
              Messages.Add(Message);
            finally
              ToolResult.Free;
            end;
          end;
        finally
          Response.Free;
        end;
      end;
      raise EPraxoAgent.CreateCode('AGENT_MAX_STEPS', 'Step budget exceeded');
    except
      try
        Host.Emit('run.failed');
      except
      end;
      raise;
    end;
  finally
    Messages.Free;
  end;
end;

end.
