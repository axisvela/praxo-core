open Praxo_types
open Praxo_json
let openai_bound text =
  if String.length text > 512 then String.sub text 0 512 else text

let openai_int key value =
  match field key value with Some (Number number) -> int_of_float number | _ -> 0

let provider_trim text =
  let rec trim value =
    let length = String.length value in
    if length > 0 && value.[length - 1] = '/' then trim (String.sub value 0 (length - 1))
    else value
  in
  trim text

