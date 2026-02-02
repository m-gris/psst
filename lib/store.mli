(** SQLite-backed event store.

    Append-only log of events. State is derived by reading and folding. *)

val default_path : unit -> string
(** Default path: ~/.psst/events.db *)

val init : path:string -> unit
(** Create tables if needed. Creates parent directory if missing. *)

val append : path:string -> Event.event -> unit
(** Append event to log *)

val read_all : path:string -> Event.event list
(** Read all events in chronological order *)

val read_since : path:string -> Event.timestamp -> Event.event list
(** Read events after timestamp *)

val read_session : path:string -> session_id:string -> Event.event list
(** Read events for a specific session *)
