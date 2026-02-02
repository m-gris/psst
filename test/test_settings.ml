(** Tests for Settings module (pure functions) *)

let sample_settings_json = {|
{
  "enabledPlugins": {
    "dev-browser@dev-browser-marketplace": true
  },
  "hooks": {
    "PreToolUse": [
      {
        "hooks": [
          {"command": "other-tool pre", "type": "command"}
        ],
        "matcher": "Bash"
      }
    ],
    "PostToolUse": [],
    "Stop": [
      {
        "hooks": [
          {"command": "notify-done", "type": "command"}
        ],
        "matcher": ""
      }
    ]
  }
}
|}

let test_parse_empty () =
  let json = Yojson.Safe.from_string "{}" in
  match Psst.Settings.of_json json with
  | Ok settings ->
    Alcotest.(check int) "no pre hooks" 0
      (List.length settings.hooks.pre_tool_use);
    Alcotest.(check int) "no post hooks" 0
      (List.length settings.hooks.post_tool_use)
  | Error msg -> Alcotest.fail msg

let test_parse_sample () =
  let json = Yojson.Safe.from_string sample_settings_json in
  match Psst.Settings.of_json json with
  | Ok settings ->
    Alcotest.(check int) "one pre hook" 1
      (List.length settings.hooks.pre_tool_use);
    Alcotest.(check int) "no post hooks" 0
      (List.length settings.hooks.post_tool_use);
    Alcotest.(check int) "one unknown hook type" 1
      (List.length settings.hooks.other);
    Alcotest.(check int) "one other top-level key" 1
      (List.length settings.other)
  | Error msg -> Alcotest.fail msg

let test_roundtrip () =
  let json = Yojson.Safe.from_string sample_settings_json in
  match Psst.Settings.of_json json with
  | Error msg -> Alcotest.fail msg
  | Ok settings ->
    let json' = Psst.Settings.to_json settings in
    match Psst.Settings.of_json json' with
    | Error msg -> Alcotest.fail ("roundtrip failed: " ^ msg)
    | Ok settings' ->
      Alcotest.(check int) "pre hooks preserved" 1
        (List.length settings'.hooks.pre_tool_use);
      Alcotest.(check int) "other hooks preserved" 1
        (List.length settings'.hooks.other)

let test_add_psst_hooks () =
  let settings = Psst.Settings.empty in
  let settings' = Psst.Settings.add_psst_hooks settings in
  Alcotest.(check bool) "has pre hook" true
    (Psst.Settings.has_pre_hook settings');
  Alcotest.(check bool) "has post hook" true
    (Psst.Settings.has_post_hook settings')

let test_add_hooks_preserves_existing () =
  let json = Yojson.Safe.from_string sample_settings_json in
  match Psst.Settings.of_json json with
  | Error msg -> Alcotest.fail msg
  | Ok settings ->
    let settings' = Psst.Settings.add_psst_hooks settings in
    (* Should have original hook + psst hook *)
    Alcotest.(check int) "two pre hooks" 2
      (List.length settings'.hooks.pre_tool_use);
    (* psst hook should be first *)
    let first = List.hd settings'.hooks.pre_tool_use in
    Alcotest.(check bool) "psst hook first" true
      (Psst.Settings.is_psst_hook first)

let test_add_hooks_idempotent () =
  let settings = Psst.Settings.empty in
  let settings' = Psst.Settings.add_psst_hooks settings in
  let settings'' = Psst.Settings.add_psst_hooks settings' in
  Alcotest.(check int) "one pre hook" 1
    (List.length settings''.hooks.pre_tool_use);
  Alcotest.(check int) "one post hook" 1
    (List.length settings''.hooks.post_tool_use)

let test_remove_psst_hooks () =
  let settings = Psst.Settings.empty in
  let settings' = Psst.Settings.add_psst_hooks settings in
  let settings'' = Psst.Settings.remove_psst_hooks settings' in
  Alcotest.(check bool) "no pre hook" false
    (Psst.Settings.has_pre_hook settings'');
  Alcotest.(check bool) "no post hook" false
    (Psst.Settings.has_post_hook settings'')

let test_remove_preserves_other_hooks () =
  let json = Yojson.Safe.from_string sample_settings_json in
  match Psst.Settings.of_json json with
  | Error msg -> Alcotest.fail msg
  | Ok settings ->
    let settings' = Psst.Settings.add_psst_hooks settings in
    let settings'' = Psst.Settings.remove_psst_hooks settings' in
    (* Should still have the original non-psst hook *)
    Alcotest.(check int) "one pre hook remains" 1
      (List.length settings''.hooks.pre_tool_use);
    let remaining = List.hd settings''.hooks.pre_tool_use in
    Alcotest.(check bool) "not a psst hook" false
      (Psst.Settings.is_psst_hook remaining)

let test_is_psst_hook () =
  Alcotest.(check bool) "psst pre hook detected" true
    (Psst.Settings.is_psst_hook Psst.Settings.psst_pre_hook);
  Alcotest.(check bool) "psst post hook detected" true
    (Psst.Settings.is_psst_hook Psst.Settings.psst_post_hook);
  let other_hook : Psst.Settings.hook_entry = {
    matcher = "Bash";
    hooks = [{ command = "other-tool"; type_ = "command" }];
  } in
  Alcotest.(check bool) "other hook not detected" false
    (Psst.Settings.is_psst_hook other_hook)

let () =
  Alcotest.run "settings" [
    "parse", [
      Alcotest.test_case "empty" `Quick test_parse_empty;
      Alcotest.test_case "sample" `Quick test_parse_sample;
      Alcotest.test_case "roundtrip" `Quick test_roundtrip;
    ];
    "add_hooks", [
      Alcotest.test_case "adds hooks" `Quick test_add_psst_hooks;
      Alcotest.test_case "preserves existing" `Quick test_add_hooks_preserves_existing;
      Alcotest.test_case "idempotent" `Quick test_add_hooks_idempotent;
    ];
    "remove_hooks", [
      Alcotest.test_case "removes hooks" `Quick test_remove_psst_hooks;
      Alcotest.test_case "preserves other" `Quick test_remove_preserves_other_hooks;
    ];
    "is_psst_hook", [
      Alcotest.test_case "detection" `Quick test_is_psst_hook;
    ];
  ]
