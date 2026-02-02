(** Tests for psst core modules *)

let test_event_roundtrip () =
  let event = Psst.Event.NudgeIssued {
    pattern = "dune build";
    recipe = "build";
    recipe_body = "opam exec -- dune build";
    session_id = "test-session";
    ts = "2024-01-01T00:00:00Z";
  } in
  let json = Psst.Event.to_yojson event in
  let parsed = Psst.Event.of_yojson json in
  Alcotest.(check string) "roundtrip pattern"
    "dune build"
    (match parsed with
     | Psst.Event.NudgeIssued { pattern; _ } -> pattern
     | _ -> "wrong event type")

let test_normalize_strips_opam_env () =
  let cmd = "eval $(opam env) && dune build" in
  let norm = Psst.Match.normalize cmd in
  Alcotest.(check string) "strips opam env" "dune build" norm

let test_normalize_strips_opam_exec () =
  let cmd = "opam exec -- dune build" in
  let norm = Psst.Match.normalize cmd in
  Alcotest.(check string) "strips opam exec" "dune build" norm

let test_normalize_strips_at_prefix () =
  let cmd = "@opam exec -- dune build" in
  let norm = Psst.Match.normalize cmd in
  Alcotest.(check string) "strips @ and opam exec" "dune build" norm

let test_normalize_collapses_whitespace () =
  let cmd = "dune   build   @check" in
  let norm = Psst.Match.normalize cmd in
  Alcotest.(check string) "collapses whitespace" "dune build @check" norm

let test_similarity_exact () =
  let sim = Psst.Match.similarity "dune build" "dune build" in
  Alcotest.(check (float 0.01)) "exact match" 1.0 sim

let test_similarity_with_boilerplate () =
  let sim = Psst.Match.similarity
    "eval $(opam env) && dune build"
    "dune build" in
  Alcotest.(check bool) "high similarity" true (sim >= 0.9)

let test_jaccard () =
  let sim = Psst.Match.jaccard_similarity "a b c" "b c d" in
  Alcotest.(check (float 0.01)) "jaccard 2/4" 0.5 sim

let test_whitelist () =
  let events = [
    Psst.Event.PatternDismissed {
      pattern = "dune build";
      reason = None;
      session_id = "s1";
      ts = "2024-01-01T00:00:00Z";
    }
  ] in
  let wl = Psst.State.whitelist events in
  Alcotest.(check bool) "pattern in whitelist" true
    (Psst.State.StringSet.mem "dune build" wl)

let test_pending_nudges () =
  let events = [
    Psst.Event.NudgeIssued {
      pattern = "dune build";
      recipe = "build";
      recipe_body = "dune build";
      session_id = "s1";
      ts = "2024-01-01T00:00:00Z";
    }
  ] in
  let pending = Psst.State.pending_nudges events in
  Alcotest.(check int) "one pending" 1 (List.length pending)

let test_pending_nudges_resolved () =
  let events = [
    Psst.Event.NudgeIssued {
      pattern = "dune build";
      recipe = "build";
      recipe_body = "dune build";
      session_id = "s1";
      ts = "2024-01-01T00:00:00Z";
    };
    Psst.Event.RecipeChosen {
      recipe = "build";
      after_nudge = Some "dune build";
      session_id = "s1";
      ts = "2024-01-01T00:00:01Z";
    }
  ] in
  let pending = Psst.State.pending_nudges events in
  Alcotest.(check int) "none pending" 0 (List.length pending)

let test_correlate_followed () =
  let pending = [
    Psst.Event.NudgeIssued {
      pattern = "dune build";
      recipe = "build";
      recipe_body = "dune build";
      session_id = "s1";
      ts = "2024-01-01T00:00:00Z";
    }
  ] in
  match Psst.Correlate.correlate ~command:"just build" ~session_id:"s1" pending with
  | Psst.Correlate.FollowedNudge { recipe; _ } ->
    Alcotest.(check string) "followed build" "build" recipe
  | _ -> Alcotest.fail "expected FollowedNudge"

let test_correlate_ignored () =
  let pending = [
    Psst.Event.NudgeIssued {
      pattern = "dune build";
      recipe = "build";
      recipe_body = "dune build";
      session_id = "s1";
      ts = "2024-01-01T00:00:00Z";
    }
  ] in
  match Psst.Correlate.correlate ~command:"dune build" ~session_id:"s1" pending with
  | Psst.Correlate.IgnoredNudge { pattern; _ } ->
    Alcotest.(check string) "ignored pattern" "dune build" pattern
  | _ -> Alcotest.fail "expected IgnoredNudge"

let () =
  Alcotest.run "psst" [
    "event", [
      Alcotest.test_case "roundtrip" `Quick test_event_roundtrip;
    ];
    "match", [
      Alcotest.test_case "normalize strips opam env" `Quick test_normalize_strips_opam_env;
      Alcotest.test_case "normalize strips opam exec" `Quick test_normalize_strips_opam_exec;
      Alcotest.test_case "normalize strips @ prefix" `Quick test_normalize_strips_at_prefix;
      Alcotest.test_case "normalize collapses whitespace" `Quick test_normalize_collapses_whitespace;
      Alcotest.test_case "similarity exact" `Quick test_similarity_exact;
      Alcotest.test_case "similarity with boilerplate" `Quick test_similarity_with_boilerplate;
      Alcotest.test_case "jaccard" `Quick test_jaccard;
    ];
    "state", [
      Alcotest.test_case "whitelist" `Quick test_whitelist;
      Alcotest.test_case "pending nudges" `Quick test_pending_nudges;
      Alcotest.test_case "pending nudges resolved" `Quick test_pending_nudges_resolved;
    ];
    "correlate", [
      Alcotest.test_case "followed" `Quick test_correlate_followed;
      Alcotest.test_case "ignored" `Quick test_correlate_ignored;
    ];
  ]
