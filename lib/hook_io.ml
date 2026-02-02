(** Hook I/O for Claude Code protocol.

    Parse stdin, write to stdout. *)

type pre_tool_input = {
  tool_name: string;
  tool_input: Yojson.Safe.t;
  session_id: string;
  cwd: string;
}

type pre_tool_output =
  | Allow
  | Deny of { reason: string }

type post_tool_input = {
  tool_name: string;
  tool_input: Yojson.Safe.t;
  tool_response: Yojson.Safe.t;
  session_id: string;
  cwd: string;
}

let read_stdin () =
  let buf = Buffer.create 4096 in
  try
    while true do
      Buffer.add_channel buf stdin 1
    done;
    Buffer.contents buf
  with End_of_file ->
    Buffer.contents buf

let get_string key assoc =
  match List.assoc_opt key assoc with
  | Some (`String s) -> s
  | _ -> failwith (Printf.sprintf "Missing or invalid field: %s" key)

let get_json key assoc =
  match List.assoc_opt key assoc with
  | Some j -> j
  | None -> failwith (Printf.sprintf "Missing field: %s" key)

let parse_pre_tool_input () =
  let json = Yojson.Safe.from_string (read_stdin ()) in
  match json with
  | `Assoc assoc ->
    {
      tool_name = get_string "tool_name" assoc;
      tool_input = get_json "tool_input" assoc;
      session_id = get_string "session_id" assoc;
      cwd = get_string "cwd" assoc;
    }
  | _ -> failwith "Expected JSON object"

let parse_post_tool_input () =
  let json = Yojson.Safe.from_string (read_stdin ()) in
  match json with
  | `Assoc assoc ->
    {
      tool_name = get_string "tool_name" assoc;
      tool_input = get_json "tool_input" assoc;
      tool_response = get_json "tool_response" assoc;
      session_id = get_string "session_id" assoc;
      cwd = get_string "cwd" assoc;
    }
  | _ -> failwith "Expected JSON object"

let extract_command tool_input =
  match tool_input with
  | `Assoc assoc ->
    (match List.assoc_opt "command" assoc with
     | Some (`String cmd) -> Some cmd
     | _ -> None)
  | _ -> None

let write_pre_tool_output = function
  | Allow ->
    print_string {|{"continue":true}|}
  | Deny { reason } ->
    let json = `Assoc [
      ("continue", `Bool false);
      ("reason", `String reason);
    ] in
    print_string (Yojson.Safe.to_string json)
