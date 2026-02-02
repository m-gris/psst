(** Event types for the event-sourced feedback loop.

    Events are immutable facts. State is derived by folding over events. *)

type timestamp = string  (** ISO 8601 format *)

type event =
  | NudgeIssued of {
      pattern: string;
      recipe: string;
      recipe_body: string;
      session_id: string;
      ts: timestamp;
    }
  | RecipeChosen of {
      recipe: string;
      after_nudge: string option;
      session_id: string;
      ts: timestamp;
    }
  | RawChosen of {
      command: string;
      after_nudge: string option;
      session_id: string;
      ts: timestamp;
    }
  | PatternDismissed of {
      pattern: string;
      reason: string option;
      session_id: string;
      ts: timestamp;
    }

let now () : timestamp =
  let open Unix in
  let t = gettimeofday () in
  let tm = gmtime t in
  Printf.sprintf "%04d-%02d-%02dT%02d:%02d:%02dZ"
    (tm.tm_year + 1900) (tm.tm_mon + 1) tm.tm_mday
    tm.tm_hour tm.tm_min tm.tm_sec

let event_type = function
  | NudgeIssued _ -> "NudgeIssued"
  | RecipeChosen _ -> "RecipeChosen"
  | RawChosen _ -> "RawChosen"
  | PatternDismissed _ -> "PatternDismissed"

let session_id = function
  | NudgeIssued { session_id; _ } -> session_id
  | RecipeChosen { session_id; _ } -> session_id
  | RawChosen { session_id; _ } -> session_id
  | PatternDismissed { session_id; _ } -> session_id

let timestamp = function
  | NudgeIssued { ts; _ } -> ts
  | RecipeChosen { ts; _ } -> ts
  | RawChosen { ts; _ } -> ts
  | PatternDismissed { ts; _ } -> ts

let to_yojson : event -> Yojson.Safe.t = function
  | NudgeIssued { pattern; recipe; recipe_body; session_id; ts } ->
    `Assoc [
      ("type", `String "NudgeIssued");
      ("pattern", `String pattern);
      ("recipe", `String recipe);
      ("recipe_body", `String recipe_body);
      ("session_id", `String session_id);
      ("ts", `String ts);
    ]
  | RecipeChosen { recipe; after_nudge; session_id; ts } ->
    `Assoc [
      ("type", `String "RecipeChosen");
      ("recipe", `String recipe);
      ("after_nudge", match after_nudge with Some s -> `String s | None -> `Null);
      ("session_id", `String session_id);
      ("ts", `String ts);
    ]
  | RawChosen { command; after_nudge; session_id; ts } ->
    `Assoc [
      ("type", `String "RawChosen");
      ("command", `String command);
      ("after_nudge", match after_nudge with Some s -> `String s | None -> `Null);
      ("session_id", `String session_id);
      ("ts", `String ts);
    ]
  | PatternDismissed { pattern; reason; session_id; ts } ->
    `Assoc [
      ("type", `String "PatternDismissed");
      ("pattern", `String pattern);
      ("reason", match reason with Some s -> `String s | None -> `Null);
      ("session_id", `String session_id);
      ("ts", `String ts);
    ]

let get_string key assoc =
  match List.assoc_opt key assoc with
  | Some (`String s) -> s
  | _ -> failwith (Printf.sprintf "Missing or invalid string field: %s" key)

let get_string_opt key assoc =
  match List.assoc_opt key assoc with
  | Some (`String s) -> Some s
  | Some `Null -> None
  | None -> None
  | _ -> failwith (Printf.sprintf "Invalid optional string field: %s" key)

let of_yojson : Yojson.Safe.t -> event = function
  | `Assoc assoc ->
    let event_type = get_string "type" assoc in
    let session_id = get_string "session_id" assoc in
    let ts = get_string "ts" assoc in
    (match event_type with
     | "NudgeIssued" ->
       NudgeIssued {
         pattern = get_string "pattern" assoc;
         recipe = get_string "recipe" assoc;
         recipe_body = get_string "recipe_body" assoc;
         session_id;
         ts;
       }
     | "RecipeChosen" ->
       RecipeChosen {
         recipe = get_string "recipe" assoc;
         after_nudge = get_string_opt "after_nudge" assoc;
         session_id;
         ts;
       }
     | "RawChosen" ->
       RawChosen {
         command = get_string "command" assoc;
         after_nudge = get_string_opt "after_nudge" assoc;
         session_id;
         ts;
       }
     | "PatternDismissed" ->
       PatternDismissed {
         pattern = get_string "pattern" assoc;
         reason = get_string_opt "reason" assoc;
         session_id;
         ts;
       }
     | t -> failwith (Printf.sprintf "Unknown event type: %s" t))
  | _ -> failwith "Event must be a JSON object"
