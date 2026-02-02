(** State derivation from events.

    All functions here are pure: events -> state. *)

module StringSet = Set.Make(String)

type pattern_stats = {
  pattern: string;
  recipe_count: int;
  raw_count: int;
  last_seen: Event.timestamp;
}

type t = {
  whitelist: StringSet.t;
  pending_nudges: Event.event list;
  stats: pattern_stats list;
}

let empty = {
  whitelist = StringSet.empty;
  pending_nudges = [];
  stats = [];
}

let whitelist events =
  List.fold_left (fun acc event ->
    match event with
    | Event.PatternDismissed { pattern; _ } -> StringSet.add pattern acc
    | _ -> acc
  ) StringSet.empty events

let pending_nudges events =
  let nudges = List.filter_map (function
    | Event.NudgeIssued { pattern; session_id; _ } as e ->
      Some (pattern, session_id, e)
    | _ -> None
  ) events in
  let resolved = List.filter_map (function
    | Event.RecipeChosen { after_nudge = Some p; session_id; _ } -> Some (p, session_id)
    | Event.RawChosen { after_nudge = Some p; session_id; _ } -> Some (p, session_id)
    | _ -> None
  ) events in
  List.filter_map (fun (pattern, session_id, event) ->
    if List.exists (fun (p, s) -> p = pattern && s = session_id) resolved
    then None
    else Some event
  ) nudges

let update_stats stats pattern is_recipe ts =
  let found = ref false in
  let updated = List.map (fun s ->
    if s.pattern = pattern then begin
      found := true;
      { s with
        recipe_count = if is_recipe then s.recipe_count + 1 else s.recipe_count;
        raw_count = if is_recipe then s.raw_count else s.raw_count + 1;
        last_seen = ts;
      }
    end else s
  ) stats in
  if !found then updated
  else { pattern; recipe_count = (if is_recipe then 1 else 0);
         raw_count = (if is_recipe then 0 else 1); last_seen = ts } :: updated

let pattern_stats events =
  List.fold_left (fun acc event ->
    match event with
    | Event.RecipeChosen { after_nudge = Some pattern; ts; _ } ->
      update_stats acc pattern true ts
    | Event.RawChosen { after_nudge = Some pattern; ts; _ } ->
      update_stats acc pattern false ts
    | _ -> acc
  ) [] events

let derive events = {
  whitelist = whitelist events;
  pending_nudges = pending_nudges events;
  stats = pattern_stats events;
}

let auto_whitelist_candidates events ~threshold =
  let stats = pattern_stats events in
  List.filter_map (fun s ->
    if s.raw_count >= threshold then Some s.pattern else None
  ) stats

let is_whitelisted state pattern =
  StringSet.mem pattern state.whitelist

let find_pending_nudge state ~pattern ~session_id =
  List.find_opt (function
    | Event.NudgeIssued { pattern = p; session_id = s; _ } ->
      p = pattern && s = session_id
    | _ -> false
  ) state.pending_nudges
