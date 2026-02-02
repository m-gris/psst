(** Event correlation for PostToolUse.

    Match executed commands to pending nudges. Pure functions. *)

type result =
  | FollowedNudge of { nudge_event: Event.event; recipe: string }
  | IgnoredNudge of { nudge_event: Event.event; pattern: string }
  | NoNudgePending

val correlate :
  command:string ->
  session_id:string ->
  Event.event list ->
  result
(** Match command against pending nudges for session *)
