(** Nudge message rendering.

    All functions here are pure. *)

val render : recipe:Recipe.t -> pattern:string -> string
(** Format the full nudge message Claude sees *)

val render_short : recipe:Recipe.t -> string
(** Short form: `just <name>` — <doc> *)
