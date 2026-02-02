(** End-to-end hook tests *)

let temp_dir () =
  let dir = Filename.get_temp_dir_name () in
  let name = Printf.sprintf "psst_e2e_%d" (Random.int 100000) in
  let path = Filename.concat dir name in
  Unix.mkdir path 0o755;
  path

let write_file path content =
  let oc = open_out path in
  output_string oc content;
  close_out oc

let cleanup dir =
  let files = Sys.readdir dir in
  Array.iter (fun f -> Sys.remove (Filename.concat dir f)) files;
  Unix.rmdir dir

(** Test the full pre-tool flow with a real justfile *)
let test_pre_tool_matches_recipe () =
  let dir = temp_dir () in
  let justfile = Filename.concat dir "justfile" in
  write_file justfile {|# Build the project
build:
    dune build
|};
  let recipes = Psst.Recipe.load ~cwd:dir in
  Alcotest.(check int) "found 1 recipe" 1 (List.length recipes);
  let recipe = List.hd recipes in
  Alcotest.(check string) "recipe name" "build" (Psst.Recipe.name recipe);
  Alcotest.(check string) "recipe body" "dune build" (Psst.Recipe.body recipe);

  (* Test matching *)
  let result = Psst.Match.best_match ~command:"dune build" ~threshold:0.7 recipes in
  (match result with
   | Psst.Match.Match { recipe; similarity } ->
     Alcotest.(check string) "matched build" "build" (Psst.Recipe.name recipe);
     Alcotest.(check bool) "high similarity" true (similarity >= 0.9)
   | Psst.Match.NoMatch ->
     Alcotest.fail "expected match");

  cleanup dir

(** Test that whitelisted patterns don't trigger nudge *)
let test_whitelist_skips_nudge () =
  let events = [
    Psst.Event.PatternDismissed {
      pattern = "dune build";
      reason = Some "I know what I'm doing";
      session_id = "s1";
      ts = "2024-01-01T00:00:00Z";
    }
  ] in
  let state = Psst.State.derive events in
  Alcotest.(check bool) "whitelisted" true
    (Psst.State.is_whitelisted state "dune build")

(** Test the full feedback loop *)
let test_feedback_loop () =
  (* 1. Nudge issued *)
  let e1 = Psst.Event.NudgeIssued {
    pattern = "dune build";
    recipe = "build";
    recipe_body = "dune build";
    session_id = "s1";
    ts = "2024-01-01T00:00:00Z";
  } in
  let state1 = Psst.State.derive [e1] in
  Alcotest.(check int) "1 pending" 1 (List.length state1.pending_nudges);

  (* 2. User runs just build *)
  let corr = Psst.Correlate.correlate
    ~command:"just build"
    ~session_id:"s1"
    [e1] in
  (match corr with
   | Psst.Correlate.FollowedNudge { recipe; _ } ->
     Alcotest.(check string) "followed" "build" recipe
   | _ -> Alcotest.fail "expected FollowedNudge");

  (* 3. After RecipeChosen, no more pending *)
  let e2 = Psst.Event.RecipeChosen {
    recipe = "build";
    after_nudge = Some "dune build";
    session_id = "s1";
    ts = "2024-01-01T00:00:01Z";
  } in
  let state2 = Psst.State.derive [e1; e2] in
  Alcotest.(check int) "0 pending" 0 (List.length state2.pending_nudges);

  (* 4. Stats updated *)
  Alcotest.(check int) "1 stat" 1 (List.length state2.stats);
  let stat = List.hd state2.stats in
  Alcotest.(check int) "recipe_count=1" 1 stat.recipe_count;
  Alcotest.(check int) "raw_count=0" 0 stat.raw_count

let () =
  Alcotest.run "hook_e2e" [
    "pre_tool", [
      Alcotest.test_case "matches recipe" `Quick test_pre_tool_matches_recipe;
      Alcotest.test_case "whitelist skips nudge" `Quick test_whitelist_skips_nudge;
    ];
    "feedback", [
      Alcotest.test_case "full loop" `Quick test_feedback_loop;
    ];
  ]
