(** PostToolUse hook entry point.

    Observes executed commands, correlates with pending nudges. *)

let () =
  try
    let input = Psst.Hook_io.parse_post_tool_input () in

    if input.tool_name <> "Bash" then exit 0;

    let command = match Psst.Hook_io.extract_command input.tool_input with
      | Some cmd -> cmd
      | None -> exit 0
    in

    let db_path = Psst.Store.default_path () in
    if not (Sys.file_exists db_path) then exit 0;

    let events = Psst.Store.read_session ~path:db_path ~session_id:input.session_id in
    let state = Psst.State.derive events in
    let pending = state.pending_nudges in

    match Psst.Correlate.correlate ~command ~session_id:input.session_id pending with
    | Psst.Correlate.NoNudgePending -> ()
    | Psst.Correlate.FollowedNudge { nudge_event = _; recipe } ->
      let pattern = Psst.Match.normalize command in
      let event = Psst.Event.RecipeChosen {
        recipe;
        after_nudge = Some pattern;
        session_id = input.session_id;
        ts = Psst.Event.now ();
      } in
      Psst.Store.append ~path:db_path event
    | Psst.Correlate.IgnoredNudge { nudge_event = _; pattern } ->
      let event = Psst.Event.RawChosen {
        command;
        after_nudge = Some pattern;
        session_id = input.session_id;
        ts = Psst.Event.now ();
      } in
      Psst.Store.append ~path:db_path event
  with
  | _ -> ()
