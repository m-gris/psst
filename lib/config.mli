(** psst installation and configuration management.

    Handles init/doctor/uninstall commands for configuring
    Claude Code hooks. *)

(** {1 Doctor Checks} *)

type check = {
  name: string;
  passed: bool;
  message: string;
}
(** Result of a single diagnostic check *)

val check_pre_hook : Settings.t -> check
(** Check if psst pre-tool-use hook is configured *)

val check_post_hook : Settings.t -> check
(** Check if psst post-tool-use hook is configured *)

val check_just : unit -> check
(** Check if 'just' command is available *)

val check_settings_exist : unit -> check
(** Check if settings.json exists *)

val check_data_dir : unit -> check
(** Check if ~/.psst directory exists *)

val check_database : unit -> check
(** Check if events database exists *)

(** {1 CLI Commands} *)

val init : unit -> unit
(** Configure Claude Code hooks for psst.
    Creates settings.json if needed, adds hooks idempotently. *)

val doctor : unit -> bool
(** Run diagnostic checks. Returns [true] if all pass. *)

val uninstall : purge:bool -> unit
(** Remove psst hooks from Claude Code.
    If [purge] is true, also delete ~/.psst data directory. *)
