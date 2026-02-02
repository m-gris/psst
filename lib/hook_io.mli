(** Hook I/O for Claude Code protocol.

    Parse stdin, write to stdout. *)

type pre_tool_input = {
  tool_name: string;
  tool_input: Yojson.Safe.t;
  session_id: string;
  cwd: string;
}

type pre_tool_output =
  | Allow
  | Deny of { reason: string }

type post_tool_input = {
  tool_name: string;
  tool_input: Yojson.Safe.t;
  tool_response: Yojson.Safe.t;
  session_id: string;
  cwd: string;
}

val parse_pre_tool_input : unit -> pre_tool_input
(** Parse PreToolUse hook input from stdin *)

val parse_post_tool_input : unit -> post_tool_input
(** Parse PostToolUse hook input from stdin *)

val extract_command : Yojson.Safe.t -> string option
(** Extract command from Bash tool_input *)

val write_pre_tool_output : pre_tool_output -> unit
(** Write hook response to stdout *)
