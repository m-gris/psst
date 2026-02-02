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
