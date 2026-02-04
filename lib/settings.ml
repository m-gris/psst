(** Claude Code settings.json domain types and operations. *)

type hook_command = {
  command: string;
  type_: string;
}

type hook_entry = {
  matcher: string;
  hooks: hook_command list;
}

type hooks = {
  pre_tool_use: hook_entry list;
  post_tool_use: hook_entry list;
  other: (string * Yojson.Safe.t) list;
}

type t = {
  hooks: hooks;
  other: (string * Yojson.Safe.t) list;
}

(* ================================================================== *)
(* psst Hook Definitions                                               *)
(* ================================================================== *)

let psst_pre_hook = {
  matcher = "Bash";
  hooks = [{ command = "psst-pre-tool-hook"; type_ = "command" }];
}

let psst_post_hook = {
  matcher = "Bash";
  hooks = [{ command = "psst-post-tool-hook"; type_ = "command" }];
}

(* ================================================================== *)
(* JSON Codec                                                          *)
(* ================================================================== *)

let hook_command_of_json json =
  let open Yojson.Safe.Util in
  let command = json |> member "command" |> to_string in
  let type_ = json |> member "type" |> to_string in
  { command; type_ }

let hook_command_to_json { command; type_ } =
  `Assoc [
    ("command", `String command);
    ("type", `String type_);
  ]

let hook_entry_of_json json =
  let open Yojson.Safe.Util in
  let matcher = json |> member "matcher" |> to_string in
  let hooks = json |> member "hooks" |> to_list |> List.map hook_command_of_json in
  { matcher; hooks }

let hook_entry_to_json { matcher; hooks } =
  `Assoc [
    ("hooks", `List (List.map hook_command_to_json hooks));
    ("matcher", `String matcher);
  ]

let hooks_of_json json =
  let open Yojson.Safe.Util in
  let assoc = json |> to_assoc in
  let pre_tool_use =
    try assoc |> List.assoc "PreToolUse" |> to_list |> List.map hook_entry_of_json
    with Not_found -> []
  in
  let post_tool_use =
    try assoc |> List.assoc "PostToolUse" |> to_list |> List.map hook_entry_of_json
    with Not_found -> []
  in
  let other =
    assoc
    |> List.filter (fun (k, _) -> k <> "PreToolUse" && k <> "PostToolUse")
  in
  { pre_tool_use; post_tool_use; other }

let hooks_to_json { pre_tool_use; post_tool_use; other } =
  let entries = other in
  let entries =
    if post_tool_use <> [] then
      ("PostToolUse", `List (List.map hook_entry_to_json post_tool_use)) :: entries
    else entries
  in
  let entries =
    if pre_tool_use <> [] then
      ("PreToolUse", `List (List.map hook_entry_to_json pre_tool_use)) :: entries
    else entries
  in
  `Assoc entries

let of_json json =
  try
    let open Yojson.Safe.Util in
    let assoc = json |> to_assoc in
    let hooks =
      try assoc |> List.assoc "hooks" |> hooks_of_json
      with Not_found -> { pre_tool_use = []; post_tool_use = []; other = [] }
    in
    let other =
      assoc
      |> List.filter (fun (k, _) -> k <> "hooks")
    in
    Ok { hooks; other }
  with
  | Yojson.Safe.Util.Type_error (msg, _) -> Error msg

let to_json { hooks; other } =
  let hooks_json = hooks_to_json hooks in
  `Assoc (("hooks", hooks_json) :: other)

let empty = {
  hooks = { pre_tool_use = []; post_tool_use = []; other = [] };
  other = [];
}

(* ================================================================== *)
(* Pure Transformations                                                *)
(* ================================================================== *)

let is_psst_hook (entry : hook_entry) =
  List.exists (fun cmd ->
    let c = cmd.command in
    String.length c >= 4 && String.sub c 0 4 = "psst"
  ) entry.hooks

let has_pre_hook settings =
  List.exists is_psst_hook settings.hooks.pre_tool_use

let has_post_hook settings =
  List.exists is_psst_hook settings.hooks.post_tool_use

let remove_psst_hooks settings =
  let hooks = settings.hooks in
  let pre_tool_use = List.filter (fun e -> not (is_psst_hook e)) hooks.pre_tool_use in
  let post_tool_use = List.filter (fun e -> not (is_psst_hook e)) hooks.post_tool_use in
  { settings with hooks = { hooks with pre_tool_use; post_tool_use } }

let add_psst_hooks settings =
  let settings = remove_psst_hooks settings in
  let hooks = settings.hooks in
  let pre_tool_use = psst_pre_hook :: hooks.pre_tool_use in
  let post_tool_use = psst_post_hook :: hooks.post_tool_use in
  { settings with hooks = { hooks with pre_tool_use; post_tool_use } }
