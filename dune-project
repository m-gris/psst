(lang dune 3.21)

(name psst)

(generate_opam_files true)

(source
 (github marcbowes/psst))

(authors "Marc Bowes")

(maintainers "Marc Bowes")

(license MIT)

(package
 (name psst)
 (synopsis "Recipe nudge tool for Claude Code hooks")
 (description
  "A collaborative feedback loop between Claude and project recipes. When Claude reaches for a raw command that has a recipe equivalent, psst nudges with the alternative.")
 (depends
  (ocaml (>= 5.2.0))
  (dune (>= 3.21))
  yojson
  sqlite3
  (alcotest :with-test)))
