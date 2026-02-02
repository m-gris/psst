(** Integration tests for SQLite store - written BEFORE verifying implementation *)

let temp_db () =
  let dir = Filename.get_temp_dir_name () in
  Filename.concat dir (Printf.sprintf "psst_test_%d.db" (Random.int 100000))

let test_init_creates_db () =
  let path = temp_db () in
  Psst.Store.init ~path;
  Alcotest.(check bool) "db exists" true (Sys.file_exists path);
  Sys.remove path

let test_append_and_read_all () =
  let path = temp_db () in
  Psst.Store.init ~path;
  let event = Psst.Event.NudgeIssued {
    pattern = "dune build";
    recipe = "build";
    recipe_body = "opam exec -- dune build";
    session_id = "test-session";
    ts = "2024-01-01T00:00:00Z";
  } in
  Psst.Store.append ~path event;
  let events = Psst.Store.read_all ~path in
  Alcotest.(check int) "one event" 1 (List.length events);
  (match List.hd events with
   | Psst.Event.NudgeIssued { pattern; _ } ->
     Alcotest.(check string) "pattern matches" "dune build" pattern
   | _ -> Alcotest.fail "wrong event type");
  Sys.remove path

let test_read_session_filters () =
  let path = temp_db () in
  Psst.Store.init ~path;
  let e1 = Psst.Event.NudgeIssued {
    pattern = "cmd1"; recipe = "r1"; recipe_body = "b1";
    session_id = "session-A"; ts = "2024-01-01T00:00:00Z";
  } in
  let e2 = Psst.Event.NudgeIssued {
    pattern = "cmd2"; recipe = "r2"; recipe_body = "b2";
    session_id = "session-B"; ts = "2024-01-01T00:00:01Z";
  } in
  Psst.Store.append ~path e1;
  Psst.Store.append ~path e2;
  let events_a = Psst.Store.read_session ~path ~session_id:"session-A" in
  let events_b = Psst.Store.read_session ~path ~session_id:"session-B" in
  Alcotest.(check int) "session A has 1" 1 (List.length events_a);
  Alcotest.(check int) "session B has 1" 1 (List.length events_b);
  Sys.remove path

let test_read_since_filters () =
  let path = temp_db () in
  Psst.Store.init ~path;
  let e1 = Psst.Event.NudgeIssued {
    pattern = "old"; recipe = "r"; recipe_body = "b";
    session_id = "s"; ts = "2024-01-01T00:00:00Z";
  } in
  let e2 = Psst.Event.NudgeIssued {
    pattern = "new"; recipe = "r"; recipe_body = "b";
    session_id = "s"; ts = "2024-01-02T00:00:00Z";
  } in
  Psst.Store.append ~path e1;
  Psst.Store.append ~path e2;
  let events = Psst.Store.read_since ~path "2024-01-01T12:00:00Z" in
  Alcotest.(check int) "only new event" 1 (List.length events);
  (match List.hd events with
   | Psst.Event.NudgeIssued { pattern; _ } ->
     Alcotest.(check string) "new pattern" "new" pattern
   | _ -> Alcotest.fail "wrong event type");
  Sys.remove path

let () =
  Alcotest.run "store" [
    "sqlite", [
      Alcotest.test_case "init creates db" `Quick test_init_creates_db;
      Alcotest.test_case "append and read_all" `Quick test_append_and_read_all;
      Alcotest.test_case "read_session filters" `Quick test_read_session_filters;
      Alcotest.test_case "read_since filters" `Quick test_read_since_filters;
    ];
  ]
