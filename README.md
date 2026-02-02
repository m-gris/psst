# psst

Recipe nudge tool for Claude Code hooks.

When Claude reaches for a raw command that has a recipe equivalent, psst nudges with the alternative.

## Install

```bash
# From source
git clone https://github.com/marcbowes/psst
cd psst
opam switch create . ocaml-base-compiler.5.2.0
opam install . --deps-only
dune build
dune install
```

## Configure Claude Code Hooks

Add to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "psst-pre-tool-hook"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "psst-post-tool-hook"
          }
        ]
      }
    ]
  }
}
```

## Usage

Once configured, psst will:

1. **Nudge** — When Claude tries to run a command that matches a justfile recipe, psst blocks and suggests the recipe
2. **Observe** — When Claude runs commands, psst records whether it followed the nudge or used the raw command
3. **Learn** — Feedback is stored for analysis

### CLI Commands

```bash
# Whitelist a pattern (stop nudging for it)
psst dismiss 'dune build'

# Show whitelist and stats
psst status

# Show event history
psst history
```

## How It Works

psst uses event sourcing:

- **NudgeIssued** — When a command matches a recipe
- **RecipeChosen** — When Claude uses `just <recipe>` after a nudge
- **RawChosen** — When Claude ignores the nudge
- **PatternDismissed** — When you whitelist a pattern

Events are stored in `~/.psst/events.db` (SQLite).

## Architecture

- **Pure core** — State derivation, matching, rendering are all pure functions
- **Effects at edges** — SQLite, hook I/O
- **Event sourced** — State is derived from immutable event log
