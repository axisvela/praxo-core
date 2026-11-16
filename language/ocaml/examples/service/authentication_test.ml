#use "authentication.ml"

type scripted = {
  mutable status : int;
  mutable body : string;
  mutable unavailable : bool;
  mutable calls : (string * (string * string) list * string option) list;
}

let make_scripted status body =
  { status; body; unavailable = false; calls = [] }

let scripted_transport script url form authorization =
  script.calls <- (url, form, authorization) :: script.calls;
  if script.unavailable then Error "identity provider unavailable"
  else Ok (script.status, script.body)

let body_of fields = encode_json (Object fields)

let expect condition message = if not condition then failwith message

let last_call script =
  match script.calls with
  | [] -> None
  | call :: _ -> Some call

let () =
  let now = 1700000000 in
  let active_body =
    body_of [ ("active", Bool true);
              ("sub", String "user-1");
              ("tenant", String "local");
              ("exp", Number (float_of_int (now + 60))) ] in

  let active = make_scripted 200 active_body in
  let authenticator =
    introspection_authenticator ~transport:(scripted_transport active)
      ~endpoint:"https://id.example.com/introspect" () in
  let principal = authenticate authenticator (Some "Bearer opaque-token") now in
  expect (principal = Some { subject = "user-1"; tenant = "local"; expires = now + 60 })
    "active token was rejected";
  (match last_call active with
   | Some (_, form, authorization) ->
       expect (List.assoc_opt "token" form = Some "opaque-token")
         "introspection did not post the token";
       expect (authorization = None) "empty client id must omit authorization"
   | None -> failwith "introspection did not reach the transport");

  let missing = make_scripted 200 active_body in
  let missing_auth =
    introspection_authenticator ~transport:(scripted_transport missing)
      ~endpoint:"https://id.example.com/introspect" () in
  expect (authenticate missing_auth None now = None)
    "missing authorization was accepted";
  expect (missing.calls = []) "missing authorization reached the transport";

  expect (authenticate authenticator (Some "Basic opaque-token") now = None)
    "wrong scheme was accepted";
  expect (authenticate authenticator (Some "bearer opaque-token") now = None)
    "lowercase scheme was accepted";
  expect (authenticate authenticator (Some "Bearer    ") now = None)
    "empty token was accepted";

  let inactive = make_scripted 200 (body_of [ ("active", Bool false) ]) in
  let inactive_auth =
    introspection_authenticator ~transport:(scripted_transport inactive)
      ~endpoint:"https://id.example.com/introspect" () in
  expect (authenticate inactive_auth (Some "Bearer opaque-token") now = None)
    "inactive token was accepted";

  let missing_subject =
    make_scripted 200
      (body_of [ ("active", Bool true);
                 ("tenant", String "local");
                 ("exp", Number (float_of_int (now + 60))) ]) in
  let missing_subject_auth =
    introspection_authenticator ~transport:(scripted_transport missing_subject)
      ~endpoint:"https://id.example.com/introspect" () in
  expect (authenticate missing_subject_auth (Some "Bearer opaque-token") now = None)
    "missing subject was accepted";

  let empty_subject =
    make_scripted 200
      (body_of [ ("active", Bool true);
                 ("sub", String "");
                 ("tenant", String "local");
                 ("exp", Number (float_of_int (now + 60))) ]) in
  let empty_subject_auth =
    introspection_authenticator ~transport:(scripted_transport empty_subject)
      ~endpoint:"https://id.example.com/introspect" () in
  expect (authenticate empty_subject_auth (Some "Bearer opaque-token") now = None)
    "empty subject was accepted";

  let missing_tenant =
    make_scripted 200
      (body_of [ ("active", Bool true);
                 ("sub", String "user-1");
                 ("exp", Number (float_of_int (now + 60))) ]) in
  let missing_tenant_auth =
    introspection_authenticator ~transport:(scripted_transport missing_tenant)
      ~endpoint:"https://id.example.com/introspect" () in
  expect (authenticate missing_tenant_auth (Some "Bearer opaque-token") now = None)
    "missing tenant was accepted";

  let empty_tenant =
    make_scripted 200
      (body_of [ ("active", Bool true);
                 ("sub", String "user-1");
                 ("tenant", String "");
                 ("exp", Number (float_of_int (now + 60))) ]) in
  let empty_tenant_auth =
    introspection_authenticator ~transport:(scripted_transport empty_tenant)
      ~endpoint:"https://id.example.com/introspect" () in
  expect (authenticate empty_tenant_auth (Some "Bearer opaque-token") now = None)
    "empty tenant was accepted";

  let expired =
    make_scripted 200
      (body_of [ ("active", Bool true);
                 ("sub", String "user-1");
                 ("tenant", String "local");
                 ("exp", Number (float_of_int now)) ]) in
  let expired_auth =
    introspection_authenticator ~transport:(scripted_transport expired)
      ~endpoint:"https://id.example.com/introspect" () in
  expect (authenticate expired_auth (Some "Bearer opaque-token") now = None)
    "expired token was accepted";

  let malformed = make_scripted 200 "{not-json" in
  let malformed_auth =
    introspection_authenticator ~transport:(scripted_transport malformed)
      ~endpoint:"https://id.example.com/introspect" () in
  expect (authenticate malformed_auth (Some "Bearer opaque-token") now = None)
    "malformed JSON was accepted";

  let non_200 = make_scripted 503 "{}" in
  let non_200_auth =
    introspection_authenticator ~transport:(scripted_transport non_200)
      ~endpoint:"https://id.example.com/introspect" () in
  expect (authenticate non_200_auth (Some "Bearer opaque-token") now = None)
    "non-200 response was accepted";

  let unavailable = make_scripted 200 "{}" in
  unavailable.unavailable <- true;
  let unavailable_auth =
    introspection_authenticator ~transport:(scripted_transport unavailable)
      ~endpoint:"https://id.example.com/introspect" () in
  expect (authenticate unavailable_auth (Some "Bearer opaque-token") now = None)
    "transport error was accepted";

  let custom =
    make_scripted 200
      (body_of [ ("active", Bool true);
                 ("sub", String "user-1");
                 ("org", String "acme");
                 ("exp", Number (float_of_int (now + 60))) ]) in
  let custom_auth =
    introspection_authenticator ~transport:(scripted_transport custom)
      ~endpoint:"https://id.example.com/introspect" ~tenant_claim:"org" () in
  expect
    (authenticate custom_auth (Some "Bearer opaque-token") now
     = Some { subject = "user-1"; tenant = "acme"; expires = now + 60 })
    "custom tenant claim failed";

  let default_only = make_scripted 200 active_body in
  let default_only_auth =
    introspection_authenticator ~transport:(scripted_transport default_only)
      ~endpoint:"https://id.example.com/introspect" ~tenant_claim:"org" () in
  expect (authenticate default_only_auth (Some "Bearer opaque-token") now = None)
    "custom tenant claim fallback was accepted";

  let confidential = make_scripted 200 active_body in
  let confidential_auth =
    introspection_authenticator ~transport:(scripted_transport confidential)
      ~endpoint:"https://id.example.com/introspect"
      ~client_id:"client" ~client_secret:"secret" () in
  ignore (authenticate confidential_auth (Some "Bearer opaque-token") now);
  (match last_call confidential with
   | Some (_, _, Some "Basic Y2xpZW50OnNlY3JldA==") -> ()
   | _ -> failwith "confidential client did not send basic auth");

  let revocation_transport = make_scripted 200 "{}" in
  let revocation =
    revocation_client ~transport:(scripted_transport revocation_transport)
      ~endpoint:"https://id.example.com/revoke" () in
  expect (revoke revocation "opaque-token" = Ok ()) "revocation failed";
  (match last_call revocation_transport with
   | Some (_, form, _) ->
       expect (List.assoc_opt "token" form = Some "opaque-token")
         "revocation did not post the token";
       expect (List.assoc_opt "token_type_hint" form = Some "access_token")
         "revocation did not send the access token hint"
   | None -> failwith "revocation did not reach the transport");

  let failed_revocation_transport = make_scripted 503 "{}" in
  let failed_revocation =
    revocation_client ~transport:(scripted_transport failed_revocation_transport)
      ~endpoint:"https://id.example.com/revoke" () in
  expect (revoke failed_revocation "opaque-token" = Error "token revocation failed")
    "revocation failure was accepted";

  let unavailable_revocation_transport = make_scripted 200 "{}" in
  unavailable_revocation_transport.unavailable <- true;
  let unavailable_revocation =
    revocation_client
      ~transport:(scripted_transport unavailable_revocation_transport)
      ~endpoint:"https://id.example.com/revoke" () in
  expect
    (revoke unavailable_revocation "opaque-token" = Error "token revocation failed")
    "revocation transport error was accepted";

  let empty_revocation_transport = make_scripted 200 "{}" in
  let empty_revocation =
    revocation_client ~transport:(scripted_transport empty_revocation_transport)
      ~endpoint:"https://id.example.com/revoke" () in
  expect
    (revoke empty_revocation "" = Error "revocation token is required")
    "empty revocation token was accepted";
  expect (empty_revocation_transport.calls = [])
    "empty revocation token reached the transport";

  print_endline "OCaml service auth tests passed"
