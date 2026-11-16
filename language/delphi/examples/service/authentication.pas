unit authentication;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, fpjson, jsonparser;

type
  TServicePrincipal = record
    Subject: string;
    Tenant: string;
    Expires: Int64;
  end;

  TServiceResponse = record
    Status: Integer;
    Body: string;
  end;

  TServiceTransport = function(const Url, Form: string; const Authorization: string): TServiceResponse of object;

  TServiceAuthError = class(Exception);

  TIntrospectionAuthenticator = class
  private
    FTransport: TServiceTransport;
    FEndpoint: string;
    FClientId: string;
    FClientSecret: string;
    FTenantClaim: string;
    function BasicAuthorization: string;
    function ParsePrincipal(const Body: string; NowUnix: Int64;
      out Principal: TServicePrincipal): Boolean;
  public
    constructor Create(Transport: TServiceTransport; const Endpoint, ClientId,
      ClientSecret: string; const TenantClaim: string = 'tenant');
    function Authenticate(const Authorization: string; NowUnix: Int64;
      out Principal: TServicePrincipal): Boolean;
  end;

  TRevocationClient = class
  private
    FTransport: TServiceTransport;
    FEndpoint: string;
    FClientId: string;
    FClientSecret: string;
    function BasicAuthorization: string;
  public
    constructor Create(Transport: TServiceTransport; const Endpoint, ClientId,
      ClientSecret: string);
    procedure Revoke(const Token: string);
  end;

function UrlEncode(const Value: string): string;
function Base64Text(const Value: string): string;

implementation

const
  Base64Alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  HexDigits = '0123456789ABCDEF';

function UrlEncode(const Value: string): string;
var
  I: Integer;
  B: Byte;
begin
  Result := '';
  for I := 1 to Length(Value) do
  begin
    B := Ord(Value[I]);
    if ((B >= Ord('A')) and (B <= Ord('Z'))) or
       ((B >= Ord('a')) and (B <= Ord('z'))) or
       ((B >= Ord('0')) and (B <= Ord('9'))) or
       (B = Ord('-')) or (B = Ord('.')) or (B = Ord('_')) or (B = Ord('~')) then
      Result := Result + Chr(B)
    else
      Result := Result + '%' + HexDigits[(B shr 4) + 1] + HexDigits[(B and $0F) + 1];
  end;
end;

function Base64Text(const Value: string): string;
var
  I, N, B1, B2, B3: Integer;
begin
  Result := '';
  N := Length(Value);
  I := 1;
  while I <= N do
  begin
    B1 := Ord(Value[I]);
    if I + 1 <= N then B2 := Ord(Value[I + 1]) else B2 := 0;
    if I + 2 <= N then B3 := Ord(Value[I + 2]) else B3 := 0;
    Result := Result + Base64Alphabet[(B1 shr 2) + 1];
    Result := Result + Base64Alphabet[(((B1 and 3) shl 4) or (B2 shr 4)) + 1];
    if I + 1 <= N then
      Result := Result + Base64Alphabet[(((B2 and $0F) shl 2) or (B3 shr 6)) + 1]
    else
      Result := Result + '=';
    if I + 2 <= N then
      Result := Result + Base64Alphabet[(B3 and $3F) + 1]
    else
      Result := Result + '=';
    Inc(I, 3);
  end;
end;

constructor TIntrospectionAuthenticator.Create(Transport: TServiceTransport;
  const Endpoint, ClientId, ClientSecret: string;
  const TenantClaim: string = 'tenant');
begin
  FTransport := Transport;
  FEndpoint := Endpoint;
  FClientId := ClientId;
  FClientSecret := ClientSecret;
  if TenantClaim = '' then
    FTenantClaim := 'tenant'
  else
    FTenantClaim := TenantClaim;
end;

function TIntrospectionAuthenticator.BasicAuthorization: string;
begin
  if FClientId = '' then
    Exit('');
  Result := 'Basic ' + Base64Text(FClientId + ':' + FClientSecret);
end;

function TIntrospectionAuthenticator.ParsePrincipal(const Body: string;
  NowUnix: Int64; out Principal: TServicePrincipal): Boolean;
var
  Data: TJSONData;
  Root: TJSONObject;
  Active, SubjectValue, TenantValue, ExpValue: TJSONData;
  Subject, Tenant: string;
  Expires: Int64;
begin
  Result := False;
  Principal.Subject := '';
  Principal.Tenant := '';
  Principal.Expires := 0;
  Data := nil;
  try
    try
      Data := GetJSON(Body);
    except
      Exit;
    end;
    if Data.JSONType <> jtObject then Exit;
    Root := TJSONObject(Data);
    Active := Root.Find('active');
    if (Active = nil) or (Active.JSONType <> jtBoolean) then Exit;
    if not Active.AsBoolean then Exit;
    SubjectValue := Root.Find('sub');
    if (SubjectValue = nil) or (SubjectValue.JSONType <> jtString) then Exit;
    Subject := SubjectValue.AsString;
    if Subject = '' then Exit;
    TenantValue := Root.Find(FTenantClaim);
    if (TenantValue = nil) or (TenantValue.JSONType <> jtString) then Exit;
    Tenant := TenantValue.AsString;
    if Tenant = '' then Exit;
    ExpValue := Root.Find('exp');
    if (ExpValue = nil) or (ExpValue.JSONType <> jtNumber) then Exit;
    if TJSONNumber(ExpValue).NumberType <> ntInteger then Exit;
    Expires := TJSONNumber(ExpValue).AsInt64;
    if Expires <= NowUnix then Exit;
    Principal.Subject := Subject;
    Principal.Tenant := Tenant;
    Principal.Expires := Expires;
    Result := True;
  finally
    Data.Free;
  end;
end;

function TIntrospectionAuthenticator.Authenticate(const Authorization: string;
  NowUnix: Int64; out Principal: TServicePrincipal): Boolean;
const
  Scheme = 'Bearer ';
var
  Token, Form, Basic: string;
  Response: TServiceResponse;
begin
  Result := False;
  Principal.Subject := '';
  Principal.Tenant := '';
  Principal.Expires := 0;
  if Length(Authorization) <= Length(Scheme) then Exit;
  if Copy(Authorization, 1, Length(Scheme)) <> Scheme then Exit;
  Token := Trim(Copy(Authorization, Length(Scheme) + 1,
    Length(Authorization) - Length(Scheme)));
  if Token = '' then Exit;
  Form := 'token=' + UrlEncode(Token) + '&client_id=' + UrlEncode(FClientId) +
    '&client_secret=' + UrlEncode(FClientSecret);
  Basic := BasicAuthorization;
  try
    Response := FTransport(FEndpoint, Form, Basic);
  except
    Exit;
  end;
  if Response.Status <> 200 then Exit;
  Result := ParsePrincipal(Response.Body, NowUnix, Principal);
end;

constructor TRevocationClient.Create(Transport: TServiceTransport;
  const Endpoint, ClientId, ClientSecret: string);
begin
  FTransport := Transport;
  FEndpoint := Endpoint;
  FClientId := ClientId;
  FClientSecret := ClientSecret;
end;

function TRevocationClient.BasicAuthorization: string;
begin
  if FClientId = '' then
    Exit('');
  Result := 'Basic ' + Base64Text(FClientId + ':' + FClientSecret);
end;

procedure TRevocationClient.Revoke(const Token: string);
var
  Form, Basic: string;
  Response: TServiceResponse;
begin
  if Token = '' then
    raise TServiceAuthError.Create('revocation token is required');
  Form := 'token=' + UrlEncode(Token) + '&token_type_hint=access_token' +
    '&client_id=' + UrlEncode(FClientId) + '&client_secret=' +
    UrlEncode(FClientSecret);
  Basic := BasicAuthorization;
  try
    Response := FTransport(FEndpoint, Form, Basic);
  except
    raise TServiceAuthError.Create('token revocation failed');
  end;
  if Response.Status <> 200 then
    raise TServiceAuthError.Create('token revocation failed');
end;

end.
