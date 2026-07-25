# Plugin conventions: invoking bundled scripts

How a plugin's markdown surfaces (hooks, slash commands, skills) should call the
plugin's own shell scripts. Read this before adding scripts to a new plugin or
reworking an old one, so we stop cargo-culting workarounds.

Verified against the official docs (July 2026):
[plugins-reference](https://code.claude.com/docs/en/plugins-reference.md),
[hooks](https://code.claude.com/docs/en/hooks.md).

## TL;DR decision tree

```
Does the logic need to be callable from a SLASH COMMAND (commands/*.md)
or a USER-invocable skill (disable-model-invocation: true)?
├── YES  -> put the executable in bin/  (auto-added to PATH, call by bare name)
│          shared functions -> scripts/lib.sh, sourced via self-locate idiom
│          (${CLAUDE_PLUGIN_ROOT} is BROKEN on these surfaces — do not use it)
│
└── NO — only hooks / MCP / LSP / monitors (JSON config surfaces)?
         -> reference scripts/ via "${CLAUDE_PLUGIN_ROOT}/scripts/x.sh"
            (the documented, substituted form on those surfaces)

A skills-only plugin (no slash commands, no hooks) may also use the
superpowers pattern: a relative `scripts/x.sh` path resolved against the
skill's announced base directory. bin/ is fine too and is more uniform.
```

## The `${CLAUDE_PLUGIN_ROOT}` substitution gap

`${CLAUDE_PLUGIN_ROOT}` is the plugin's root path. It resolves ONLY via harness
**text-substitution** of the markdown/JSON *before* execution, and only on the
JSON config surfaces:

- `hooks/hooks.json` command strings
- `.mcp.json`, `.lsp.json`, `monitors/monitors.json`

It is **NOT** available in:

- **slash commands** (`commands/*.md`)
- **ALL skills** — user-invocable AND agent-invocable (`SKILL.md`, regardless of
  `disable-model-invocation`)

Two independent facts make this certain:

1. **Not substituted in the markdown** on those surfaces — Anthropic issues
   [#9354](https://github.com/anthropics/claude-code/issues/9354) and
   [#44057](https://github.com/anthropics/claude-code/issues/44057), both OPEN
   (July 2026). The literal string `${CLAUDE_PLUGIN_ROOT}` reaches the shell.
2. **Not an environment variable either** — `echo "${CLAUDE_PLUGIN_ROOT}"` in the
   Bash tool prints empty (verified). So a skill's bash block referencing it gets
   nothing, and a path like `"${CLAUDE_PLUGIN_ROOT}/.."` collapses to `/..`.

The docs claim it works "anywhere in skill content"; that is wrong for the Bash
surface. Anthropic's own **superpowers** skills use relative `scripts/` paths and
never touch `${CLAUDE_PLUGIN_ROOT}` — treat that as the authoritative signal.

**Rule: never use `${CLAUDE_PLUGIN_ROOT}` in a slash command or any skill.** Only
use it in `hooks.json` / MCP / LSP / monitor JSON.

> **Known offender:** `plugins/cadrianmae-integration/skills/integration/SKILL.md`
> builds `MARKETPLACE_DIR="${CLAUDE_PLUGIN_ROOT}/.."`, which resolves to `/..`.
> That skill needs fixing (self-locate or a `bin/` entry) — file a bug.

## The three mechanisms

| Mechanism | Path form | Works on | Notes |
|---|---|---|---|
| **`bin/` on PATH** | bare name, e.g. `context-manage send ...` | Bash calls, hooks, skills, commands | Official: `bin/` is auto-added to PATH; files are "invokable as bare commands while the plugin is enabled". The one form that works everywhere. |
| **`${CLAUDE_PLUGIN_ROOT}/scripts/x.sh`** | absolute | hooks, MCP, LSP, monitors (JSON only) | Broken in slash commands AND all skills (not substituted; not an env var). |
| **relative `scripts/x.sh`** | relative to the skill's base dir | skills (Skill tool announces the base dir) | The superpowers pattern. No PATH use, no wrapper. Unproven for slash commands (no announced base dir). |

`bin/` = executables meant to be called by bare name. `scripts/` = helper scripts
referenced by path (from hooks/JSON) or sourced as libraries.

## Recommended structure

### Plugin whose logic is reachable from commands or user skills (most CLI plugins)

Put the executable in `bin/`, shared functions in `scripts/lib.sh`:

```
my-plugin/
  bin/
    my-plugin          # executable; subcommand dispatch; sources scripts/lib.sh
  scripts/
    lib.sh             # shared functions (sourced, not executed)
  skills/my-plugin/SKILL.md   # calls: my-plugin <subcommand> ...
  commands/*.md               # calls: my-plugin <subcommand> ...
```

- **Prefer ONE `bin/<plugin>` with subcommands** over many thin `bin/x` wrappers.
- The executable finds its library with the self-locate idiom (see below).
- Skills/commands call it by bare name: `my-plugin send child "subject"`.

### Plugin whose logic is only called by hooks

Keep the logic in `scripts/`, reference it from `hooks.json` with the substituted
variable:

```json
{ "type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}\"/scripts/on-event.sh" }
```

### Logic shared between hooks AND user skills/commands

Two options:

1. **bin/ everywhere** (preferred for new work): put the logic in `bin/`, and have
   the hook call it by **bare name** too (PATH is available to hook commands).
   One home, no duplication, no `${CLAUDE_PLUGIN_ROOT}`.
2. **The bridge wrapper** (existing plugins, still valid): logic in
   `scripts/x.sh`; the hook calls `"${CLAUDE_PLUGIN_ROOT}"/scripts/x.sh`; a thin
   `bin/x` wrapper `exec`s the same script so skills can call it by bare name.
   This is a **justified workaround**, not an anti-pattern — but a comment
   explaining it should cite #9354/#44057, not vague wording.

## Idioms

### Self-locate (standard, not a workaround)

A script invoked via PATH does not know its own directory, so to source a sibling
it resolves its own location. This is normal Unix, required whenever a
PATH-invoked script needs a bundled neighbour:

```bash
# in bin/my-plugin
HERE="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
. "$HERE/../scripts/lib.sh"
```

### Thin wrapper (only for the shared-with-hooks bridge)

```bash
#!/bin/bash
# bin/x — bridge so user skills can call `x` by bare name while hooks call
# ${CLAUDE_PLUGIN_ROOT}/scripts/x.sh. Needed because ${CLAUDE_PLUGIN_ROOT} is
# not substituted in user skills / slash commands
# (anthropics/claude-code#9354, #44057).
exec "$(dirname "$(readlink -f "$0")")/../scripts/x.sh" "$@"
```

Do NOT add a wrapper-per-command out of habit. If the logic is not shared with a
hook, put it directly in `bin/` and skip the `scripts/` copy entirely.

## What to fix over time

- **New plugins / reworks:** follow the recommended structure above. Prefer a
  single `bin/<plugin>` with subcommands + `scripts/lib.sh`.
- **Existing plugins (tts, cron, track, audio-feedback, nvr):** their many
  `bin/x -> scripts/x.sh` wrappers are justified where the script is also called
  by a hook; leave them working. When touched, consider collapsing to a single
  subcommand entry and updating the wrapper comment to cite the issues.
- **Never** use `${CLAUDE_PLUGIN_ROOT}` in a slash command or user skill until
  #9354 / #44057 are closed.

## References

- Plugins reference — file locations and environment variables:
  https://code.claude.com/docs/en/plugins-reference.md
- Hooks reference — path placeholders:
  https://code.claude.com/docs/en/hooks.md
- Issue #9354 — `${CLAUDE_PLUGIN_ROOT}` in command markdown:
  https://github.com/anthropics/claude-code/issues/9354
- Issue #44057 — `${CLAUDE_PLUGIN_ROOT}` not substituted in user-invocable skills:
  https://github.com/anthropics/claude-code/issues/44057
- Precedents in the wild: this marketplace's `bin/` wrappers (tts, cron, …);
  superpowers' relative `scripts/start-server.sh` from the skill base dir.
