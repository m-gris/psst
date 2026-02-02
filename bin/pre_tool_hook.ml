(** PreToolUse hook entry point.

    Reads hook input, checks for recipe match, issues nudge if found. *)

let threshold = 0.7

let () =
  try
    let input = Psst.Hook_io.parse_pre_tool_input () in

    if input.tool_name <> "Bash" then begin
      Psst.Hook_io.write_pre_tool_output Allow;
      exit 0
    end;

    let command = match Psst.Hook_io.extract_command input.tool_input with
      | Some cmd -> cmd
      | None ->
        Psst.Hook_io.write_pre_tool_output Allow;
        exit 0
    in

    let recipes = Psst.Recipe.load ~cwd:input.cwd in
    if recipes = [] then begin
      Psst.Hook_io.write_pre_tool_output Allow;
      exit 0
    end;

    let db_path = Psst.Store.default_path () in
    Psst.Store.init ~path:db_path;
    let events = Psst.Store.read_all ~path:db_path in
    let state = Psst.State.derive events in

    let pattern = Psst.Match.normalize command in
    if Psst.State.is_whitelisted state pattern then begin
      Psst.Hook_io.write_pre_tool_output Allow;
      exit 0
    end;

    match Psst.Match.best_match ~command ~threshold recipes with
    | Psst.Match.NoMatch ->
      Psst.Hook_io.write_pre_tool_output Allow
    | Psst.Match.Match { recipe; similarity = _ } ->
      let nudge_msg = Psst.Nudge.render ~recipe ~pattern in
      let event = Psst.Event.NudgeIssued {
        pattern;
        recipe = Psst.Recipe.name recipe;
        recipe_body = Psst.Recipe.body recipe;
        session_id = input.session_id;
        ts = Psst.Event.now ();
      } in
      Psst.Store.append ~path:db_path event;
      Psst.Hook_io.write_pre_tool_output (Deny { reason = nudge_msg })
  with
  | e ->
    Printf.eprintf "psst pre_tool_hook error: %s\n" (Printexc.to_string e);
    Psst.Hook_io.write_pre_tool_output Allow
