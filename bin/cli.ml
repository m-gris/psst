(** psst CLI entry point.

    Usage:
      psst dismiss <pattern>  - Whitelist a pattern
      psst status             - Show current state
      psst history            - Show event log *)

let usage = {|psst — Recipe nudge tool for Claude Code

Usage:
  psst dismiss <pattern>   Whitelist a command pattern
  psst status              Show whitelist and stats
  psst history             Show recent events

Options:
  --help                   Show this help|}

let dismiss pattern reason =
  let db_path = Psst.Store.default_path () in
  Psst.Store.init ~path:db_path;
  let event = Psst.Event.PatternDismissed {
    pattern;
    reason;
    session_id = "cli";
    ts = Psst.Event.now ();
  } in
  Psst.Store.append ~path:db_path event;
  Printf.printf "Whitelisted: %s\n" pattern

let status () =
  let db_path = Psst.Store.default_path () in
  if not (Sys.file_exists db_path) then begin
    print_endline "No psst database found. No nudges issued yet.";
    exit 0
  end;
  let events = Psst.Store.read_all ~path:db_path in
  let state = Psst.State.derive events in

  print_endline "=== Whitelist ===";
  if Psst.State.StringSet.is_empty state.whitelist then
    print_endline "(none)"
  else
    Psst.State.StringSet.iter (fun p ->
      Printf.printf "  %s\n" p
    ) state.whitelist;

  print_endline "";
  print_endline "=== Pattern Stats ===";
  if state.stats = [] then
    print_endline "(no feedback recorded)"
  else
    List.iter (fun (s : Psst.State.pattern_stats) ->
      Printf.printf "  %s: recipe=%d raw=%d (last: %s)\n"
        s.pattern s.recipe_count s.raw_count s.last_seen
    ) state.stats;

  print_endline "";
  print_endline "=== Pending Nudges ===";
  if state.pending_nudges = [] then
    print_endline "(none)"
  else
    List.iter (fun e ->
      match e with
      | Psst.Event.NudgeIssued { pattern; recipe; session_id; _ } ->
        Printf.printf "  [%s] %s -> %s\n" session_id pattern recipe
      | _ -> ()
    ) state.pending_nudges

let history () =
  let db_path = Psst.Store.default_path () in
  if not (Sys.file_exists db_path) then begin
    print_endline "No psst database found.";
    exit 0
  end;
  let events = Psst.Store.read_all ~path:db_path in
  List.iter (fun e ->
    let ts = Psst.Event.timestamp e in
    let typ = Psst.Event.event_type e in
    let session = Psst.Event.session_id e in
    Printf.printf "[%s] %s (%s)\n" ts typ session
  ) events

let () =
  match Array.to_list Sys.argv with
  | _ :: "dismiss" :: pattern :: rest ->
    let reason = match rest with
      | r :: _ -> Some r
      | [] -> None
    in
    dismiss pattern reason
  | _ :: "status" :: _ ->
    status ()
  | _ :: "history" :: _ ->
    history ()
  | _ :: "--help" :: _ | _ :: "-h" :: _ ->
    print_endline usage
  | _ ->
    print_endline usage;
    exit 1
