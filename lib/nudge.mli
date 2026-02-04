(** Nudge message rendering.

    All functions here are pure. *)

val render : recipe:Recipe.t -> pattern:string -> string
(** Format the full nudge message Claude sees *)

val render_short : recipe:Recipe.t -> string
(** Short form: `just <name>` — <doc> *)

val render_chain : segments:Match.segment_match list -> pattern:string -> string
(** Render nudge for chain with multiple matches *)
