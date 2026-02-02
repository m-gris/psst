(** Recipe discovery via just --dump --dump-format=json.

    We shell out to just and parse the JSON output.
    No custom parser needed! *)

type t = {
  name: string;
  body: string;
  doc: string option;
}

let find_justfile ~cwd =
  let rec walk dir =
    let candidate = Filename.concat dir "justfile" in
    if Sys.file_exists candidate then Some candidate
    else
      let candidate = Filename.concat dir "Justfile" in
      if Sys.file_exists candidate then Some candidate
      else
        let parent = Filename.dirname dir in
        if parent = dir then None
        else walk parent
  in
  walk cwd

let run_just ~cwd =
  let cmd = Printf.sprintf "cd %s && just --dump --dump-format=json 2>/dev/null"
    (Filename.quote cwd) in
  let ic = Unix.open_process_in cmd in
  let buf = Buffer.create 4096 in
  (try
    while true do
      Buffer.add_channel buf ic 1
    done
  with End_of_file -> ());
  let status = Unix.close_process_in ic in
  match status with
  | Unix.WEXITED 0 -> Some (Buffer.contents buf)
  | _ -> None

let flatten_body lines =
  String.concat " && " lines

let parse_recipes json_str =
  let json = Yojson.Safe.from_string json_str in
  match json with
  | `Assoc top ->
    (match List.assoc_opt "recipes" top with
     | Some (`Assoc recipes) ->
       List.filter_map (fun (name, recipe_json) ->
         match recipe_json with
         | `Assoc fields ->
           let body = match List.assoc_opt "body" fields with
             | Some (`List lines) ->
               let strs = List.filter_map (function
                 | `String s -> Some (String.trim s)
                 | _ -> None
               ) lines in
               flatten_body strs
             | _ -> ""
           in
           let doc = match List.assoc_opt "doc" fields with
             | Some (`String s) -> Some s
             | _ -> None
           in
           if body = "" then None
           else Some { name; body; doc }
         | _ -> None
       ) recipes
     | _ -> [])
  | _ -> []

let load ~cwd =
  match find_justfile ~cwd with
  | None -> []
  | Some _ ->
    match run_just ~cwd with
    | None -> []
    | Some json_str -> parse_recipes json_str

let find ~name recipes =
  List.find_opt (fun r -> r.name = name) recipes

let body r = r.body
let name r = r.name
let doc r = r.doc
