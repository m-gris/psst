(** Claude Code settings.json domain types and operations.

    Models the hooks section of ~/.claude/settings.json.
    Preserves unknown fields to avoid clobbering user configuration. *)

(** A single hook command entry *)
type hook_command = {
  command: string;
  type_: string;  (** "type" in JSON, renamed to avoid OCaml keyword *)
}

(** A hook entry: matcher pattern + list of commands *)
type hook_entry = {
  matcher: string;
  hooks: hook_command list;
}

(** All hook event types. Unknown types are preserved in [other]. *)
type hooks = {
  pre_tool_use: hook_entry list;
  post_tool_use: hook_entry list;
  other: (string * Yojson.Safe.t) list;
}

(** Top-level settings structure. Unknown keys preserved in [other]. *)
type t = {
  hooks: hooks;
  other: (string * Yojson.Safe.t) list;
}

(** {1 psst Hook Definitions} *)

val psst_pre_hook : hook_entry
(** The psst pre-tool-use hook for Bash commands *)

val psst_post_hook : hook_entry
(** The psst post-tool-use hook for Bash commands *)

(** {1 JSON Codec} *)

val of_json : Yojson.Safe.t -> (t, string) result
(** Parse settings.json into domain type. Returns [Error msg] on malformed input. *)

val to_json : t -> Yojson.Safe.t
(** Serialize back to JSON, preserving unknown fields *)

val empty : t
(** Empty settings (for creating a new file) *)

(** {1 Pure Transformations} *)

val add_psst_hooks : t -> t
(** Add psst hooks (idempotent - removes existing psst hooks first) *)

val remove_psst_hooks : t -> t
(** Remove all psst hooks *)

val has_pre_hook : t -> bool
(** Check if psst pre-tool-use hook is configured *)

val has_post_hook : t -> bool
(** Check if psst post-tool-use hook is configured *)

val is_psst_hook : hook_entry -> bool
(** Predicate: is this hook entry a psst hook? *)
