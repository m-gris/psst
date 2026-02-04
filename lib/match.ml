(** Command matching: find best recipe for a given command.

    All functions here are pure. *)

type result =
  | NoMatch
  | Match of { recipe: Recipe.t; similarity: float }

let normalize cmd =
  let cmd = String.trim cmd in
  (* Strip leading @ (just's quiet modifier) *)
  let cmd = if String.length cmd > 0 && cmd.[0] = '@'
    then String.trim (String.sub cmd 1 (String.length cmd - 1))
    else cmd in
  (* Strip opam exec -- prefix *)
  let cmd =
    let prefix = "opam exec -- " in
    let plen = String.length prefix in
    if String.length cmd >= plen && String.sub cmd 0 plen = prefix
    then String.trim (String.sub cmd plen (String.length cmd - plen))
    else cmd in
  (* Strip eval $(opam env) && prefix *)
  let boilerplate = [
    "eval $(opam env) &&";
    "eval $(opam env)&&";
    "eval \"$(opam env)\" &&";
    "eval \"$(opam env)\"&&";
  ] in
  let cmd = List.fold_left (fun c pat ->
    let pat_len = String.length pat in
    if String.length c >= pat_len &&
       String.sub c 0 pat_len = pat
    then String.trim (String.sub c pat_len (String.length c - pat_len))
    else c
  ) cmd boilerplate in
  let buf = Buffer.create (String.length cmd) in
  let prev_space = ref false in
  String.iter (fun c ->
    if c = ' ' || c = '\t' || c = '\n' then begin
      if not !prev_space then Buffer.add_char buf ' ';
      prev_space := true
    end else begin
      Buffer.add_char buf c;
      prev_space := false
    end
  ) cmd;
  Buffer.contents buf

let tokenize s =
  String.split_on_char ' ' s
  |> List.filter (fun t -> String.length t > 0)

let jaccard_similarity a b =
  let set_a = List.sort_uniq String.compare (tokenize a) in
  let set_b = List.sort_uniq String.compare (tokenize b) in
  let intersection = List.filter (fun x -> List.mem x set_b) set_a in
  let union_size =
    List.length set_a + List.length set_b - List.length intersection
  in
  if union_size = 0 then 0.0
  else float_of_int (List.length intersection) /. float_of_int union_size

let containment cmd recipe_body =
  let norm_cmd = normalize cmd in
  let norm_body = normalize recipe_body in
  if String.length norm_cmd = 0 || String.length norm_body = 0 then 0.0
  else if norm_cmd = norm_body then 1.0
  else if String.length norm_body <= String.length norm_cmd &&
          String.sub norm_cmd 0 (String.length norm_body) = norm_body
  then 0.95
  else if String.length norm_cmd <= String.length norm_body &&
          String.sub norm_body 0 (String.length norm_cmd) = norm_cmd
  then
    (* Command is prefix of recipe body. Require significant coverage
       to avoid "dune exec" matching "dune exec psst -- ..." *)
    let cmd_tokens = List.length (tokenize norm_cmd) in
    let body_tokens = List.length (tokenize norm_body) in
    if body_tokens > 0 && float_of_int cmd_tokens /. float_of_int body_tokens >= 0.5
    then 0.9
    else 0.0  (* Too short a prefix *)
  else 0.0

let first_token s =
  match tokenize (normalize s) with
  | [] -> ""
  | t :: _ -> t

let similarity cmd recipe_body =
  let c = containment cmd recipe_body in
  if c > 0.0 then c
  else
    (* Jaccard fallback: require first tokens to match.
       This prevents "test dune" from matching "dune test". *)
    let cmd_first = first_token cmd in
    let body_first = first_token recipe_body in
    if cmd_first <> body_first then 0.0
    else jaccard_similarity (normalize cmd) (normalize recipe_body)

let best_match ~command ~threshold recipes =
  let candidates = List.filter_map (fun recipe ->
    let sim = similarity command (Recipe.body recipe) in
    if sim >= threshold then Some (recipe, sim)
    else None
  ) recipes in
  match List.sort (fun (_, s1) (_, s2) -> compare s2 s1) candidates with
  | (recipe, sim) :: _ -> Match { recipe; similarity = sim }
  | [] -> NoMatch
