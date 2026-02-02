(** Event types for the event-sourced feedback loop.

    Events are immutable facts. State is derived by folding over events. *)

type timestamp = string
(** ISO 8601 format timestamp *)

type event =
  | NudgeIssued of {
      pattern: string;      (** Command that triggered nudge *)
      recipe: string;       (** Suggested recipe name *)
      recipe_body: string;  (** What the recipe does *)
      session_id: string;
      ts: timestamp;
    }
  | RecipeChosen of {
      recipe: string;
      after_nudge: string option;  (** Pattern that was nudged, if any *)
      session_id: string;
      ts: timestamp;
    }
  | RawChosen of {
      command: string;
      after_nudge: string option;  (** Pattern that was nudged, if any *)
      session_id: string;
      ts: timestamp;
    }
  | PatternDismissed of {
      pattern: string;
      reason: string option;
      session_id: string;
      ts: timestamp;
    }

val now : unit -> timestamp
(** Current time as ISO 8601 string *)

val event_type : event -> string
(** Extract event type name *)

val session_id : event -> string
(** Extract session_id from any event *)

val timestamp : event -> timestamp
(** Extract timestamp from any event *)

val to_yojson : event -> Yojson.Safe.t
(** Serialize event to JSON *)

val of_yojson : Yojson.Safe.t -> event
(** Deserialize event from JSON. Raises on invalid input. *)
