program authentication_test;

{$mode objfpc}{$H+}

uses
  SysUtils, authentication;

type
  TScriptedTransport = class
  public
    Status: Integer;
    Body: string;
    Unavailable: Boolean;
    Calls: Integer;
    LastUrl: string;
    LastForm: string;
    LastAuthorization: string;
    constructor Create(AStatus: Integer; const ABody: string);
    function PostForm(const Url, Form: string;
      const Authorization: string): TServiceResponse;
  end;

constructor TScriptedTransport.Create(AStatus: Integer; const ABody: string);
begin
  Status := AStatus;
  Body := ABody;
  Unavailable := False;
  Calls := 0;
  LastUrl := '';
  LastForm := '';
  LastAuthorization := '';
end;

function TScriptedTransport.PostForm(const Url, Form: string;
  const Authorization: string): TServiceResponse;
begin
  Inc(Calls);
  LastUrl := Url;
  LastForm := Form;
  LastAuthorization := Authorization;
  if Unavailable then
    raise TServiceAuthError.Create('identity provider unavailable');
  Result.Status := Status;
  Result.Body := Body;
end;

const
  NowUnix: Int64 = 1700000000;
  Endpoint = 'https://id.example.com/introspect';
  ActiveBody = '{"active":true,"sub":"user-1","tenant":"tenant-a","exp":1700000060}';

procedure Check(Condition: Boolean; const LabelText: string);
begin
  if not Condition then
  begin
    WriteLn(StdErr, 'FAIL: ', LabelText);
    Halt(1);
  end;
end;

procedure ExpectRejected(const LabelText, Authorization, Body: string;
  AStatus: Integer);
var
  Transport: TScriptedTransport;
  Auth: TIntrospectionAuthenticator;
  Principal: TServicePrincipal;
begin
  Transport := TScriptedTransport.Create(AStatus, Body);
  try
    Auth := TIntrospectionAuthenticator.Create(@Transport.PostForm, Endpoint, '', '');
    try
      Check(not Auth.Authenticate(Authorization, NowUnix, Principal), LabelText);
    finally
      Auth.Free;
    end;
  finally
    Transport.Free;
  end;
end;

var
  Transport: TScriptedTransport;
  Auth: TIntrospectionAuthenticator;
  Client: TRevocationClient;
  Principal: TServicePrincipal;
  Raised: Boolean;

begin
  Transport := TScriptedTransport.Create(200, ActiveBody);
  try
    Auth := TIntrospectionAuthenticator.Create(@Transport.PostForm, Endpoint,
      'svc', 'secret');
    try
      Check(Auth.Authenticate('Bearer opaque-token', NowUnix, Principal),
        'active token accepted');
      Check(Principal.Subject = 'user-1', 'subject');
      Check(Principal.Tenant = 'tenant-a', 'tenant');
      Check(Principal.Expires = NowUnix + 60, 'expires');
      Check(Transport.Calls = 1, 'one introspection call');
      Check(Transport.LastUrl = Endpoint, 'endpoint');
      Check(Pos('token=opaque-token', Transport.LastForm) > 0, 'token field');
      Check(Pos('client_id=svc', Transport.LastForm) > 0, 'client id field');
      Check(Pos('client_secret=secret', Transport.LastForm) > 0,
        'client secret field');
      Check(Transport.LastAuthorization = 'Basic c3ZjOnNlY3JldA==',
        'basic authorization');
    finally
      Auth.Free;
    end;
  finally
    Transport.Free;
  end;

  Transport := TScriptedTransport.Create(200, ActiveBody);
  try
    Auth := TIntrospectionAuthenticator.Create(@Transport.PostForm, Endpoint,
      'svc', 'secret');
    try
      Check(not Auth.Authenticate('', NowUnix, Principal),
        'missing authorization');
      Check(not Auth.Authenticate('Basic opaque-token', NowUnix, Principal),
        'wrong scheme');
      Check(not Auth.Authenticate('Bearer', NowUnix, Principal),
        'missing token');
      Check(not Auth.Authenticate('Bearer   ', NowUnix, Principal),
        'empty token');
      Check(Transport.Calls = 0, 'local rejection avoids transport');
    finally
      Auth.Free;
    end;
  finally
    Transport.Free;
  end;

  ExpectRejected('inactive token', 'Bearer token-1',
    '{"active":false,"sub":"user-1","tenant":"tenant-a","exp":1700000060}', 200);
  ExpectRejected('missing sub', 'Bearer token-1',
    '{"active":true,"tenant":"tenant-a","exp":1700000060}', 200);
  ExpectRejected('empty sub', 'Bearer token-1',
    '{"active":true,"sub":"","tenant":"tenant-a","exp":1700000060}', 200);
  ExpectRejected('missing tenant', 'Bearer token-1',
    '{"active":true,"sub":"user-1","exp":1700000060}', 200);
  ExpectRejected('empty tenant', 'Bearer token-1',
    '{"active":true,"sub":"user-1","tenant":"","exp":1700000060}', 200);
  ExpectRejected('expired token', 'Bearer token-1',
    '{"active":true,"sub":"user-1","tenant":"tenant-a","exp":1700000000}', 200);
  ExpectRejected('missing expiration', 'Bearer token-1',
    '{"active":true,"sub":"user-1","tenant":"tenant-a"}', 200);
  ExpectRejected('fractional expiration', 'Bearer token-1',
    '{"active":true,"sub":"user-1","tenant":"tenant-a","exp":1700000060.5}', 200);
  ExpectRejected('malformed json', 'Bearer token-1', 'not-json', 200);
  ExpectRejected('non-200', 'Bearer token-1', ActiveBody, 500);

  Transport := TScriptedTransport.Create(200, ActiveBody);
  Transport.Unavailable := True;
  try
    Auth := TIntrospectionAuthenticator.Create(@Transport.PostForm, Endpoint, '', '');
    try
      Check(not Auth.Authenticate('Bearer token-1', NowUnix, Principal),
        'transport error');
    finally
      Auth.Free;
    end;
  finally
    Transport.Free;
  end;

  Transport := TScriptedTransport.Create(200,
    '{"active":true,"sub":"user-1","org":"org-a","exp":1700000060}');
  try
    Auth := TIntrospectionAuthenticator.Create(@Transport.PostForm, Endpoint, '',
      '', 'org');
    try
      Check(Auth.Authenticate('Bearer token-1', NowUnix, Principal),
        'custom tenant claim accepted');
      Check(Principal.Tenant = 'org-a', 'custom tenant value');
      Check(Transport.LastAuthorization = '',
        'no basic authorization without client id');
    finally
      Auth.Free;
    end;
  finally
    Transport.Free;
  end;

  Transport := TScriptedTransport.Create(200, '');
  try
    Client := TRevocationClient.Create(@Transport.PostForm,
      'https://id.example.com/revoke', 'svc', 'secret');
    try
      Client.Revoke('token-1');
      Check(Transport.Calls = 1, 'one revocation call');
      Check(Pos('token=token-1', Transport.LastForm) > 0,
        'revocation token field');
      Check(Pos('token_type_hint=access_token', Transport.LastForm) > 0,
        'revocation hint field');
      Check(Transport.LastAuthorization = 'Basic c3ZjOnNlY3JldA==',
        'revocation basic authorization');
    finally
      Client.Free;
    end;
  finally
    Transport.Free;
  end;

  Transport := TScriptedTransport.Create(400, '');
  try
    Client := TRevocationClient.Create(@Transport.PostForm,
      'https://id.example.com/revoke', '', '');
    try
      Raised := False;
      try
        Client.Revoke('token-1');
      except
        on E: TServiceAuthError do Raised := True;
      end;
      Check(Raised, 'revocation non-200');
    finally
      Client.Free;
    end;
  finally
    Transport.Free;
  end;

  Transport := TScriptedTransport.Create(200, '');
  Transport.Unavailable := True;
  try
    Client := TRevocationClient.Create(@Transport.PostForm,
      'https://id.example.com/revoke', '', '');
    try
      Raised := False;
      try
        Client.Revoke('token-1');
      except
        on E: TServiceAuthError do Raised := True;
      end;
      Check(Raised, 'revocation transport error');
    finally
      Client.Free;
    end;
  finally
    Transport.Free;
  end;

  Transport := TScriptedTransport.Create(200, '');
  try
    Client := TRevocationClient.Create(@Transport.PostForm,
      'https://id.example.com/revoke', '', '');
    try
      Raised := False;
      try
        Client.Revoke('');
      except
        on E: TServiceAuthError do Raised := True;
      end;
      Check(Raised, 'empty revocation token');
      Check(Transport.Calls = 0, 'empty revocation avoids transport');
    finally
      Client.Free;
    end;
  finally
    Transport.Free;
  end;

  WriteLn('Delphi service auth tests passed');
end.
