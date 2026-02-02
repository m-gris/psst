(** State derivation from events.

    All functions here are pure: events -> state. *)

module StringSet : Set.S with type elt = string

type pattern_stats = {
  pattern: string;
  recipe_count: int;
  raw_count: int;
  last_seen: Event.timestamp;
}

type t = {
  whitelist: StringSet.t;       (** Dismissed patterns *)
  pending_nudges: Event.event list;  (** NudgeIssued not yet resolved *)
  stats: pattern_stats list;    (** Feedback aggregates *)
}

val empty : t
(** Empty state *)

val whitelist : Event.event list -> StringSet.t
(** Extract whitelisted patterns from events *)

val pending_nudges : Event.event list -> Event.event list
(** Find NudgeIssued events without subsequent resolution *)

val pattern_stats : Event.event list -> pattern_stats list
(** Aggregate recipe/raw counts per pattern *)

val derive : Event.event list -> t
(** Derive full state from event list *)

val auto_whitelist_candidates : Event.event list -> threshold:int -> string list
(** Patterns with raw_count >= threshold *)

val is_whitelisted : t -> string -> bool
(** Check if pattern is in whitelist *)

val find_pending_nudge : t -> pattern:string -> session_id:string -> Event.event option
(** Find pending nudge for pattern in session *)
