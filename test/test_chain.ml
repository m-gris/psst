(** Tests for chain matching *)

let recipe n b : Psst.Recipe.t =
  { name = n; body = b; doc = None }

let recipes = [
  recipe "list" "ls -la";
  recipe "greet" "echo hello";
  recipe "show-date" "date";
]

(* split_chain tests *)
let test_split_simple_and () =
  let segments = Psst.Match.split_chain "ls -la && echo hello" in
  Alcotest.(check int) "two segments" 2 (List.length segments);
  Alcotest.(check string) "first segment" "ls -la" (List.hd segments).segment;
  Alcotest.(check string) "second segment" "echo hello" (List.nth segments 1).segment

let test_split_triple_chain () =
  let segments = Psst.Match.split_chain "ls && echo hello && date" in
  Alcotest.(check int) "three segments" 3 (List.length segments)

let test_split_or_operator () =
  let segments = Psst.Match.split_chain "ls -la || echo fallback" in
  Alcotest.(check int) "two segments" 2 (List.length segments)

let test_split_semicolon () =
  let segments = Psst.Match.split_chain "ls -la; echo done" in
  Alcotest.(check int) "two segments" 2 (List.length segments)

let test_split_no_chain () =
  let segments = Psst.Match.split_chain "ls -la" in
  Alcotest.(check int) "one segment" 1 (List.length segments)

(* match_chain tests *)
let test_match_chain_both () =
  let result = Psst.Match.match_chain ~command:"ls -la && echo hello" ~threshold:0.7 recipes in
  Alcotest.(check bool) "is Some" true (Option.is_some result);
  let segments = Option.get result in
  Alcotest.(check int) "two segments" 2 (List.length segments);
  Alcotest.(check bool) "first matched" true (Option.is_some (List.hd segments).matched_recipe);
  Alcotest.(check bool) "second matched" true (Option.is_some (List.nth segments 1).matched_recipe)

let test_match_chain_partial () =
  let result = Psst.Match.match_chain ~command:"ls -la && pwd" ~threshold:0.7 recipes in
  Alcotest.(check bool) "is Some (partial match)" true (Option.is_some result);
  let segments = Option.get result in
  Alcotest.(check bool) "first matched" true (Option.is_some (List.hd segments).matched_recipe);
  Alcotest.(check bool) "second not matched" true (Option.is_none (List.nth segments 1).matched_recipe)

let test_match_chain_none () =
  let result = Psst.Match.match_chain ~command:"pwd && whoami" ~threshold:0.7 recipes in
  Alcotest.(check bool) "is None (no matches)" true (Option.is_none result)

let test_match_single_not_chain () =
  let result = Psst.Match.match_chain ~command:"ls -la" ~threshold:0.7 recipes in
  Alcotest.(check bool) "is None (not a chain)" true (Option.is_none result)

let () =
  Alcotest.run "chain" [
    "split_chain", [
      Alcotest.test_case "simple &&" `Quick test_split_simple_and;
      Alcotest.test_case "triple chain" `Quick test_split_triple_chain;
      Alcotest.test_case "|| operator" `Quick test_split_or_operator;
      Alcotest.test_case "; operator" `Quick test_split_semicolon;
      Alcotest.test_case "no chain" `Quick test_split_no_chain;
    ];
    "match_chain", [
      Alcotest.test_case "both match" `Quick test_match_chain_both;
      Alcotest.test_case "partial match" `Quick test_match_chain_partial;
      Alcotest.test_case "no matches" `Quick test_match_chain_none;
      Alcotest.test_case "single not chain" `Quick test_match_single_not_chain;
    ];
  ]
