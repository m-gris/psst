(** Nudge message rendering.

    All functions here are pure. *)

let render ~recipe ~pattern =
  let name = Recipe.name recipe in
  let body = Recipe.body recipe in
  let doc_line = match Recipe.doc recipe with
    | Some d -> Printf.sprintf "# %s\n" d
    | None -> ""
  in
  Printf.sprintf {|psst: Recipe `%s` matches your command.

┌────────────────────────────────────────┐
│ just %s
│ %s│ %s
└────────────────────────────────────────┘

Run `just %s` directly, or `psst dismiss '%s'` to whitelist.|}
    name name doc_line body name pattern

let render_short ~recipe =
  let name = Recipe.name recipe in
  match Recipe.doc recipe with
  | Some d -> Printf.sprintf "`just %s` — %s" name d
  | None -> Printf.sprintf "`just %s`" name

let render_chain ~segments ~pattern =
  (* Build the suggested command: replace matched segments with recipes *)
  let suggested = segments |> List.map (fun (seg : Match.segment_match) ->
    let replacement = match seg.matched_recipe with
      | Some r -> "just " ^ Recipe.name r
      | None -> seg.segment
    in
    match seg.operator with
    | Some op -> replacement ^ " " ^ op
    | None -> replacement
  ) |> String.concat " " in

  (* Build the mapping lines *)
  let mappings = segments |> List.filter_map (fun (seg : Match.segment_match) ->
    match seg.matched_recipe with
    | Some r -> Some (Printf.sprintf "│   %s  →  just %s" seg.segment (Recipe.name r))
    | None -> None
  ) |> String.concat "\n" in

  let match_count = List.length (List.filter (fun s -> s.Match.matched_recipe <> None) segments) in

  Printf.sprintf {|psst: %d recipe(s) match your command.

┌────────────────────────────────────────┐
│ %s
│
%s
└────────────────────────────────────────┘

Run the suggested command, or `psst dismiss '%s'` to whitelist.|}
    match_count suggested mappings pattern
