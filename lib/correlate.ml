(** Event correlation for PostToolUse.

    Match executed commands to pending nudges. Pure functions. *)

type result =
  | FollowedNudge of { nudge_event: Event.event; recipe: string }
  | IgnoredNudge of { nudge_event: Event.event; pattern: string }
  | NoNudgePending

let extract_nudge_info = function
  | Event.NudgeIssued { pattern; recipe; _ } -> Some (pattern, recipe)
  | _ -> None

let correlate ~command ~session_id pending_nudges =
  let session_nudges = List.filter (fun e ->
    Event.session_id e = session_id
  ) pending_nudges in
  match session_nudges with
  | [] -> NoNudgePending
  | nudges ->
    let norm_cmd = Match.normalize command in
    let followed = List.find_opt (fun e ->
      match extract_nudge_info e with
      | Some (_, recipe) ->
        let is_just_recipe =
          String.length norm_cmd >= 5 &&
          String.sub norm_cmd 0 5 = "just " &&
          String.trim (String.sub norm_cmd 5 (String.length norm_cmd - 5)) = recipe
        in
        is_just_recipe
      | None -> false
    ) nudges in
    match followed with
    | Some nudge_event ->
      (match extract_nudge_info nudge_event with
       | Some (_, recipe) -> FollowedNudge { nudge_event; recipe }
       | None -> NoNudgePending)
    | None ->
      (match nudges with
       | nudge_event :: _ ->
         (match extract_nudge_info nudge_event with
          | Some (pattern, _) -> IgnoredNudge { nudge_event; pattern }
          | None -> NoNudgePending)
       | [] -> NoNudgePending)
