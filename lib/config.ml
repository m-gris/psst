(** psst installation and configuration management. *)

type check = {
  name: string;
  passed: bool;
  message: string;
}

(* ================================================================== *)
(* Paths                                                               *)
(* ================================================================== *)

let settings_path () =
  let home = Sys.getenv "HOME" in
  Filename.concat home ".claude/settings.json"

let data_dir () =
  let home = Sys.getenv "HOME" in
  Filename.concat home ".psst"

let database_path () =
  Filename.concat (data_dir ()) "events.db"

(* ================================================================== *)
(* File I/O (impure shell)                                             *)
(* ================================================================== *)

let read_json_file path =
  if Sys.file_exists path then
    let ic = open_in path in
    let content = really_input_string ic (in_channel_length ic) in
    close_in ic;
    Some (Yojson.Safe.from_string content)
  else
    None

let write_json_file path json =
  let dir = Filename.dirname path in
  if not (Sys.file_exists dir) then
    Unix.mkdir dir 0o755;
  let oc = open_out path in
  output_string oc (Yojson.Safe.pretty_to_string ~std:true json);
  output_char oc '\n';
  close_out oc

(* ================================================================== *)
(* Doctor Checks                                                       *)
(* ================================================================== *)

let check_pre_hook settings =
  if Settings.has_pre_hook settings then
    { name = "PreToolUse hook"; passed = true; message = "psst pre hook configured" }
  else
    { name = "PreToolUse hook"; passed = false; message = "psst pre hook not found" }

let check_post_hook settings =
  if Settings.has_post_hook settings then
    { name = "PostToolUse hook"; passed = true; message = "psst post hook configured" }
  else
    { name = "PostToolUse hook"; passed = false; message = "psst post hook not found" }

let check_just () =
  let exit_code = Sys.command "which just > /dev/null 2>&1" in
  if exit_code = 0 then
    { name = "just"; passed = true; message = "just command found" }
  else
    { name = "just"; passed = false; message = "just command not found (optional)" }

let check_settings_exist () =
  let path = settings_path () in
  if Sys.file_exists path then
    { name = "settings.json"; passed = true; message = path }
  else
    { name = "settings.json"; passed = false; message = "not found at " ^ path }

let check_data_dir () =
  let path = data_dir () in
  if Sys.file_exists path then
    { name = "data directory"; passed = true; message = path }
  else
    { name = "data directory"; passed = true; message = "not created yet (OK)" }

let check_database () =
  let path = database_path () in
  if Sys.file_exists path then
    { name = "database"; passed = true; message = path }
  else
    { name = "database"; passed = true; message = "not created yet (OK)" }

(* ================================================================== *)
(* CLI Commands                                                        *)
(* ================================================================== *)

let print_check check =
  let icon = if check.passed then "\xe2\x9c\x93" else "\xe2\x9c\x97" in
  Printf.printf "  %s %s: %s\n" icon check.name check.message

let init () =
  let path = settings_path () in
  let json = read_json_file path |> Option.value ~default:(`Assoc []) in
  match Settings.of_json json with
  | Error msg ->
    Printf.eprintf "Error parsing %s: %s\n" path msg;
    exit 1
  | Ok settings ->
    let settings' = Settings.add_psst_hooks settings in
    let json' = Settings.to_json settings' in
    write_json_file path json';
    print_endline "psst hooks configured.";
    print_endline "";
    print_endline "Added to ~/.claude/settings.json:";
    print_endline "  - PreToolUse: psst pre (for Bash)";
    print_endline "  - PostToolUse: psst post (for Bash)"

let doctor () =
  print_endline "psst doctor";
  print_endline "";

  let path = settings_path () in
  let settings_check = check_settings_exist () in
  print_check settings_check;

  let hook_checks =
    if settings_check.passed then
      match read_json_file path with
      | None -> []
      | Some json ->
        match Settings.of_json json with
        | Error msg ->
          Printf.printf "  \xe2\x9c\x97 settings parse error: %s\n" msg;
          []
        | Ok settings ->
          [check_pre_hook settings; check_post_hook settings]
    else
      []
  in
  List.iter print_check hook_checks;

  let other_checks = [
    check_data_dir ();
    check_database ();
    check_just ();
  ] in
  List.iter print_check other_checks;

  let all_checks = settings_check :: hook_checks @ other_checks in
  let all_pass = List.for_all (fun c -> c.passed) all_checks in
  print_endline "";
  if all_pass then
    print_endline "All checks passed."
  else
    print_endline "Some checks failed. Run 'psst init' to configure hooks.";
  all_pass

let uninstall ~purge =
  let path = settings_path () in
  (match read_json_file path with
  | None ->
    print_endline "No settings.json found, nothing to remove."
  | Some json ->
    match Settings.of_json json with
    | Error msg ->
      Printf.eprintf "Error parsing %s: %s\n" path msg;
      exit 1
    | Ok settings ->
      let settings' = Settings.remove_psst_hooks settings in
      let json' = Settings.to_json settings' in
      write_json_file path json';
      print_endline "Removed psst hooks from settings.json.");

  if purge then begin
    let data = data_dir () in
    if Sys.file_exists data then begin
      let _ = Sys.command (Printf.sprintf "rm -rf %s" (Filename.quote data)) in
      Printf.printf "Deleted %s\n" data
    end else
      print_endline "No data directory to delete."
  end
