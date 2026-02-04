(** Adversarial tests: commands that must NOT match.

    These tests verify specificity — that unrelated commands
    don't trigger false positive matches. *)

let recipe n b : Psst.Recipe.t =
  { name = n; body = b; doc = None }

(* Helper to assert no match *)
let assert_no_match ~command ~recipes =
  let result = Psst.Match.best_match ~command ~threshold:0.7 recipes in
  match result with
  | Psst.Match.NoMatch -> ()
  | Psst.Match.Match { recipe; similarity } ->
    Alcotest.failf "Expected NoMatch but got Match { recipe=%s; similarity=%f }"
      (Psst.Recipe.name recipe) similarity

(* BUG 1: Jaccard is order-agnostic, so "test dune" matches "dune test" *)
let test_reversed_order_no_match () =
  let recipes = [recipe "test" "dune test"] in
  assert_no_match ~command:"test dune" ~recipes

let test_reversed_order_build () =
  let recipes = [recipe "build" "dune build"] in
  assert_no_match ~command:"build dune" ~recipes

(* BUG 2: Prefix containment too greedy - "dune exec foo" matches "dune exec psst -- ..." *)
let test_prefix_containment_no_match () =
  let recipes = [recipe "run" "dune exec psst -- {{ARGS}}"] in
  assert_no_match ~command:"dune exec other-binary" ~recipes

let test_prefix_partial_no_match () =
  let recipes = [recipe "run" "dune exec psst -- {{ARGS}}"] in
  assert_no_match ~command:"dune exec" ~recipes

(* Different tools sharing tokens should NOT match *)
let test_docker_build_no_match () =
  let recipes = [recipe "build" "dune build"] in
  assert_no_match ~command:"docker build ." ~recipes

let test_npm_test_no_match () =
  let recipes = [recipe "test" "dune test"] in
  assert_no_match ~command:"npm test" ~recipes

let test_cargo_build_no_match () =
  let recipes = [recipe "build" "dune build"] in
  assert_no_match ~command:"cargo build" ~recipes

let test_make_clean_no_match () =
  let recipes = [recipe "clean" "dune clean"] in
  assert_no_match ~command:"make clean" ~recipes

let () =
  Alcotest.run "match_negative" [
    "reversed_order", [
      Alcotest.test_case "test dune vs dune test" `Quick test_reversed_order_no_match;
      Alcotest.test_case "build dune vs dune build" `Quick test_reversed_order_build;
    ];
    "prefix_containment", [
      Alcotest.test_case "dune exec other vs run recipe" `Quick test_prefix_containment_no_match;
      Alcotest.test_case "dune exec alone vs run recipe" `Quick test_prefix_partial_no_match;
    ];
    "different_tool", [
      Alcotest.test_case "docker build vs dune build" `Quick test_docker_build_no_match;
      Alcotest.test_case "npm test vs dune test" `Quick test_npm_test_no_match;
      Alcotest.test_case "cargo build vs dune build" `Quick test_cargo_build_no_match;
      Alcotest.test_case "make clean vs dune clean" `Quick test_make_clean_no_match;
    ];
  ]
