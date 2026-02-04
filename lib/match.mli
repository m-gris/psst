(** Command matching: find best recipe for a given command.

    All functions here are pure. *)

type result =
  | NoMatch
  | Match of { recipe: Recipe.t; similarity: float }

val normalize : string -> string
(** Collapse whitespace, strip boilerplate like 'eval $(opam env) &&' *)

val tokenize : string -> string list
(** Split on whitespace *)

val jaccard_similarity : string -> string -> float
(** Token-based Jaccard similarity (0.0 - 1.0) *)

val containment : string -> string -> float
(** Check if command contains recipe body or vice versa *)

val similarity : string -> string -> float
(** Combined similarity score *)

val best_match : command:string -> threshold:float -> Recipe.t list -> result
(** Find best matching recipe above threshold *)

(** Chain matching for commands with &&, ||, ; *)

type segment_match = {
  segment: string;
  operator: string option;
  matched_recipe: Recipe.t option;
}

val split_chain : string -> segment_match list
(** Split command by chain operators *)

val match_chain : command:string -> threshold:float -> Recipe.t list -> segment_match list option
(** Match each segment of a chain. Returns None if not a chain or no matches. *)
