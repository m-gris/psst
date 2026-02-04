(** Sensitivity guards: commands that MUST match.

    These tests lock in true positives — if any fix causes these
    to fail, we've introduced a regression. *)

let recipe n b : Psst.Recipe.t =
  { name = n; body = b; doc = None }

(* Helper to assert a match exists *)
let assert_match ~command ~recipe_name ~recipes =
  let result = Psst.Match.best_match ~command ~threshold:0.7 recipes in
  match result with
  | Psst.Match.NoMatch ->
    Alcotest.failf "Expected Match for recipe=%s but got NoMatch" recipe_name
  | Psst.Match.Match { recipe; similarity = _ } ->
    Alcotest.(check string) "matched recipe" recipe_name (Psst.Recipe.name recipe)

(* Exact matches *)
let test_exact_build () =
  let recipes = [recipe "build" "dune build"] in
  assert_match ~command:"dune build" ~recipe_name:"build" ~recipes

let test_exact_test () =
  let recipes = [recipe "test" "dune test"] in
  assert_match ~command:"dune test" ~recipe_name:"test" ~recipes

(* With boilerplate *)
let test_opam_exec_prefix () =
  let recipes = [recipe "build" "dune build"] in
  assert_match ~command:"opam exec -- dune build" ~recipe_name:"build" ~recipes

let test_eval_opam_env () =
  let recipes = [recipe "build" "dune build"] in
  assert_match ~command:"eval $(opam env) && dune build" ~recipe_name:"build" ~recipes

(* Command with extra args should still match (prefix) *)
let test_extra_args () =
  let recipes = [recipe "build" "dune build"] in
  assert_match ~command:"dune build @check" ~recipe_name:"build" ~recipes

(* Multi-command recipes *)
let test_multi_command_exact () =
  let recipes = [recipe "retest" "dune clean && dune test"] in
  assert_match ~command:"dune clean && dune test" ~recipe_name:"retest" ~recipes

let () =
  Alcotest.run "match_positive" [
    "exact", [
      Alcotest.test_case "dune build" `Quick test_exact_build;
      Alcotest.test_case "dune test" `Quick test_exact_test;
    ];
    "boilerplate", [
      Alcotest.test_case "opam exec -- dune build" `Quick test_opam_exec_prefix;
      Alcotest.test_case "eval $(opam env) && dune build" `Quick test_eval_opam_env;
    ];
    "prefix", [
      Alcotest.test_case "dune build @check" `Quick test_extra_args;
    ];
    "multi_command", [
      Alcotest.test_case "dune clean && dune test" `Quick test_multi_command_exact;
    ];
  ]
