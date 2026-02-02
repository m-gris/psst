(** SQLite-backed event store.

    Append-only log of events. State is derived by reading and folding. *)

let default_path () =
  let home = Sys.getenv "HOME" in
  Filename.concat home ".psst/events.db"

let init ~path =
  let dir = Filename.dirname path in
  if not (Sys.file_exists dir) then
    Unix.mkdir dir 0o755;
  let db = Sqlite3.db_open path in
  let sql = {|
    CREATE TABLE IF NOT EXISTS events (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      ts TEXT NOT NULL,
      session_id TEXT NOT NULL,
      event_type TEXT NOT NULL,
      payload TEXT NOT NULL
    );
    CREATE INDEX IF NOT EXISTS idx_session ON events(session_id);
    CREATE INDEX IF NOT EXISTS idx_ts ON events(ts);
  |} in
  (match Sqlite3.exec db sql with
   | Sqlite3.Rc.OK -> ()
   | rc -> failwith (Printf.sprintf "Failed to init DB: %s" (Sqlite3.Rc.to_string rc)));
  ignore (Sqlite3.db_close db)

let append ~path event =
  let db = Sqlite3.db_open path in
  let stmt = Sqlite3.prepare db
    "INSERT INTO events (ts, session_id, event_type, payload) VALUES (?, ?, ?, ?)" in
  let ts = Event.timestamp event in
  let session_id = Event.session_id event in
  let event_type = Event.event_type event in
  let payload = Yojson.Safe.to_string (Event.to_yojson event) in
  ignore (Sqlite3.bind_text stmt 1 ts);
  ignore (Sqlite3.bind_text stmt 2 session_id);
  ignore (Sqlite3.bind_text stmt 3 event_type);
  ignore (Sqlite3.bind_text stmt 4 payload);
  (match Sqlite3.step stmt with
   | Sqlite3.Rc.DONE -> ()
   | rc -> failwith (Printf.sprintf "Failed to insert: %s" (Sqlite3.Rc.to_string rc)));
  ignore (Sqlite3.finalize stmt);
  ignore (Sqlite3.db_close db)

let read_events db sql =
  let stmt = Sqlite3.prepare db sql in
  let events = ref [] in
  while Sqlite3.step stmt = Sqlite3.Rc.ROW do
    let payload = Sqlite3.column_text stmt 0 in
    let json = Yojson.Safe.from_string payload in
    events := Event.of_yojson json :: !events
  done;
  ignore (Sqlite3.finalize stmt);
  List.rev !events

let read_all ~path =
  let db = Sqlite3.db_open path in
  let events = read_events db "SELECT payload FROM events ORDER BY id ASC" in
  ignore (Sqlite3.db_close db);
  events

let read_since ~path ts =
  let db = Sqlite3.db_open path in
  let stmt = Sqlite3.prepare db
    "SELECT payload FROM events WHERE ts > ? ORDER BY id ASC" in
  ignore (Sqlite3.bind_text stmt 1 ts);
  let events = ref [] in
  while Sqlite3.step stmt = Sqlite3.Rc.ROW do
    let payload = Sqlite3.column_text stmt 0 in
    let json = Yojson.Safe.from_string payload in
    events := Event.of_yojson json :: !events
  done;
  ignore (Sqlite3.finalize stmt);
  ignore (Sqlite3.db_close db);
  List.rev !events

let read_session ~path ~session_id =
  let db = Sqlite3.db_open path in
  let stmt = Sqlite3.prepare db
    "SELECT payload FROM events WHERE session_id = ? ORDER BY id ASC" in
  ignore (Sqlite3.bind_text stmt 1 session_id);
  let events = ref [] in
  while Sqlite3.step stmt = Sqlite3.Rc.ROW do
    let payload = Sqlite3.column_text stmt 0 in
    let json = Yojson.Safe.from_string payload in
    events := Event.of_yojson json :: !events
  done;
  ignore (Sqlite3.finalize stmt);
  ignore (Sqlite3.db_close db);
  List.rev !events
