(** Recipe discovery via just --dump --dump-format=json.

    We shell out to just and parse the JSON output. *)

type t = {
  name: string;
  body: string;       (** The command(s), joined with && *)
  doc: string option; (** Comment/documentation *)
}

val find_justfile : cwd:string -> string option
(** Walk up directories looking for justfile/Justfile *)

val load : cwd:string -> t list
(** Load recipes from justfile in or above cwd.
    Shells out to just --dump --dump-format=json *)

val find : name:string -> t list -> t option
(** Lookup recipe by name *)

val body : t -> string
val name : t -> string
val doc : t -> string option
