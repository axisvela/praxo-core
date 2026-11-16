#use "praxo_core.ml"

type principal = { subject : string; tenant : string; expires : int }

exception Auth_error of string

type transport =
  string -> (string * string) list -> string option -> (int * string, string) result

type introspection_authenticator = {
  transport : transport;
  endpoint : string;
  client_id : string;
  client_secret : string;
  tenant_claim : string;
}

type revocation_client = {
  revoke_transport : transport;
  revoke_endpoint : string;
  revoke_client_id : string;
  revoke_client_secret : string;
}

let introspection_authenticator
    ?(client_id = "") ?(client_secret = "") ?(tenant_claim = "tenant")
    ~transport ~endpoint () =
  { transport;
    endpoint;
    client_id;
    client_secret;
    tenant_claim = if tenant_claim = "" then "tenant" else tenant_claim }

let revocation_client
    ?(client_id = "") ?(client_secret = "")
    ~transport ~endpoint () =
  { revoke_transport = transport;
    revoke_endpoint = endpoint;
    revoke_client_id = client_id;
    revoke_client_secret = client_secret }

let base64_encode text =
  let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/" in
  let length = String.length text in
  let buffer = Buffer.create (((length + 2) / 3) * 4) in
  let byte index = Char.code text.[index] in
  let add value = Buffer.add_char buffer alphabet.[value] in
  let rec loop index =
    if index + 2 < length then begin
      let value = (byte index lsl 16) lor (byte (index + 1) lsl 8) lor byte (index + 2) in
      add (value lsr 18);
      add ((value lsr 12) land 63);
      add ((value lsr 6) land 63);
      add (value land 63);
      loop (index + 3)
    end else if index + 1 < length then begin
      let value = (byte index lsl 16) lor (byte (index + 1) lsl 8) in
      add (value lsr 18);
      add ((value lsr 12) land 63);
      add ((value lsr 6) land 63);
      Buffer.add_char buffer '='
    end else if index < length then begin
      let value = byte index lsl 16 in
      add (value lsr 18);
      add ((value lsr 12) land 63);
      Buffer.add_char buffer '=';
      Buffer.add_char buffer '='
    end
  in
  loop 0;
  Buffer.contents buffer

let basic_auth client_id client_secret =
  if client_id = "" then None
  else Some ("Basic " ^ base64_encode (client_id ^ ":" ^ client_secret))

let member key = function
  | Object fields -> List.assoc_opt key fields
  | _ -> None

let nonempty_string = function
  | Some (String value) when value <> "" -> Some value
  | _ -> None

let integer_value = function
  | Some (Number value)
    when Float.is_integer value
      && value >= float_of_int min_int
      && value <= float_of_int max_int ->
      Some (int_of_float value)
  | _ -> None

let authenticate authenticator authorization now =
  match authorization with
  | None -> None
  | Some value when not (starts_with "Bearer " value) -> None
  | Some value ->
      let token = String.trim (String.sub value 7 (String.length value - 7)) in
      if token = "" then None
      else
        let form =
          [ ("token", token);
            ("client_id", authenticator.client_id);
            ("client_secret", authenticator.client_secret) ] in
        match authenticator.transport authenticator.endpoint form
                (basic_auth authenticator.client_id authenticator.client_secret) with
        | Error _ -> None
        | Ok (status, _) when status <> 200 -> None
        | Ok (_, body) ->
            (try
               match parse_json body with
               | Object _ as payload ->
                   (match member "active" payload with
                    | Some (Bool true) ->
                        (match nonempty_string (member "sub" payload) with
                         | None -> None
                         | Some subject ->
                             (match nonempty_string
                                      (member authenticator.tenant_claim payload) with
                              | None -> None
                              | Some tenant ->
                                  (match integer_value (member "exp" payload) with
                                   | Some expires when expires > now ->
                                       Some { subject; tenant; expires }
                                   | _ -> None)))
                    | _ -> None)
               | _ -> None
             with Json_error _ -> None)

let revoke client token =
  if token = "" then Error "revocation token is required"
  else
    let form =
      [ ("token", token);
        ("token_type_hint", "access_token");
        ("client_id", client.revoke_client_id);
        ("client_secret", client.revoke_client_secret) ] in
    match client.revoke_transport client.revoke_endpoint form
            (basic_auth client.revoke_client_id client.revoke_client_secret) with
    | Ok (200, _) -> Ok ()
    | _ -> Error "token revocation failed"
