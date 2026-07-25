# Context Handover Management Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the `context` plugin a `context-manage` script (lib.sh + bin) that owns handover naming, direction mapping, a persistent XDG-state location, TTL pruning, staleness/supersession, and send/receive — so the slash commands and skills are thin and handovers survive reboot.

**Architecture:** All handover logic lives in `plugins/context/scripts/lib.sh` (sourced shell functions). `plugins/context/bin/context-manage` is a thin dispatcher that self-locates, sources the lib, and routes subcommands. Skills/commands call `context-manage` by bare name (bin/ is auto-added to PATH). Storage is flat `ctx-<direction>-<subject>.md` files with a service-captured front-matter block.

**Tech Stack:** Bash, `git`/`date`/`stat` (service-side capture), a bash test harness. No external deps. Runtime-only shell (no Python).

## Global Constraints

- Handover dir name is **`claude-context`**. Default handover dir: `${XDG_STATE_HOME:-$HOME/.local/state}/claude-context`; config `dir=` overrides; fallback `/tmp/claude-context` (+ `[WARN]` to stderr) if unwritable.
- Config file: **`$HOME/.claude/.context-config`** (KV). Keys: `dir`, `ttl_days` (default **90**), `max_bytes` (default **28000**). Malformed integer -> default + `[WARN]`.
- Handover files: `ctx-<direction>-<subject>.md`, direction in `parent-to-child | child-to-parent | sibling-to-sibling`.
- Direction mapping: `send <target>` -> `{opposite(target)}-to-{target}`; `receive <source>` -> `{source}-to-{opposite(source)}`; `opposite`: child<->parent, sibling<->sibling.
- `send` requires a subject; `receive` subject is optional (newest match by mtime if omitted).
- `send` prepends a service-captured front-matter block, then the stdin body; prints the path; auto-prunes first.
- `receive` prints an `[INFO] <file>` line + any `[WARN] stale` to **stderr**, then cats the file to **stdout**; if the file exceeds `max_bytes`, print its path instead of cat-ing (+ `[WARN]`).
- Supersession: within a direction the newest is LIVE, older are SUPERSEDED (shown by `list`, never auto-deleted). `send` records `supersedes:` in front-matter.
- Staleness: front-matter records the git commit; `receive`/`list` flag when the repo's `HEAD` differs.
- Legacy `/tmp/claude-ctx` files: left untouched.
- Structure follows `plugins/CONVENTIONS.md`: logic in `bin/`-callable form via lib.sh + a `bin/` dispatcher; **never** use `${CLAUDE_PLUGIN_ROOT}` in the skills/commands (call `context-manage` by bare name).
- No emoji / non-ASCII in code; ASCII tags `[OK]`/`[WARN]`/`[INFO]`. en-GB.
- Version bump `plugins/context/.claude-plugin/plugin.json` 1.3.3 -> **1.4.0** (new feature, backward-compatible).

All paths below are relative to repo root. Run tests from `plugins/context/`.

---

### Task 1: Test harness + config/dir resolution

**Files:**
- Create: `plugins/context/scripts/lib.sh`
- Create: `plugins/context/tests/test_context_manage.sh`

**Interfaces:**
- Produces: `ctx_config_file` -> path string; `ctx_cfg_get <key> <default>` -> value; `ctx_ttl_days` -> int (default 90); `ctx_max_bytes` -> int (default 28000); `ctx_dir` -> resolved writable handover dir (creates it + README); `ctx_opposite <role>` -> parent|child|sibling (exit 1 on bad); `ctx_slug <text>` -> slug.

- [ ] **Step 1: Write the failing test harness + first cases**

Create `plugins/context/tests/test_context_manage.sh`:

```bash
#!/usr/bin/env bash
# Tests for the context plugin's lib.sh. Isolated env (temp HOME + XDG state).
set -u
DIR="$(cd "$(dirname "$0")/.." && pwd)"
. "$DIR/scripts/lib.sh"

FAILED=0
pass() { echo "[OK] $1"; }
fail() { echo "[FAIL] $1"; FAILED=1; }
assert_eq() { if [ "$1" = "$2" ]; then pass "$3"; else fail "$3 (got '$1' want '$2')"; fi; }
assert_contains() { case "$1" in *"$2"*) pass "$3";; *) fail "$3 (missing '$2' in '$1')";; esac; }

fresh_env() {
  TMP="$(mktemp -d)"
  export HOME="$TMP/home"; export XDG_STATE_HOME="$TMP/state"
  mkdir -p "$HOME/.claude"
}
cleanup() { [ -n "${TMP:-}" ] && rm -rf "$TMP"; }
trap cleanup EXIT

# --- config + dir ---
fresh_env
assert_eq "$(ctx_config_file)" "$HOME/.claude/.context-config" "config file path"
assert_eq "$(ctx_ttl_days)" "90" "ttl default 90"
assert_eq "$(ctx_max_bytes)" "28000" "max_bytes default"
d="$(ctx_dir)"
assert_eq "$d" "$XDG_STATE_HOME/claude-context" "dir = XDG state default"
[ -f "$d/README.md" ] && pass "README created" || fail "README created"
# config dir override
printf 'dir=%s/custom\n' "$TMP" > "$HOME/.claude/.context-config"
assert_eq "$(ctx_dir)" "$TMP/custom" "config dir= override"
# ttl override + malformed
printf 'ttl_days=30\n' > "$HOME/.claude/.context-config"
assert_eq "$(ctx_ttl_days)" "30" "ttl override"
printf 'ttl_days=abc\n' > "$HOME/.claude/.context-config"
assert_eq "$(ctx_ttl_days 2>/dev/null)" "90" "malformed ttl -> 90"
# opposite + slug
assert_eq "$(ctx_opposite child)" "parent" "opposite child"
assert_eq "$(ctx_opposite sibling)" "sibling" "opposite sibling"
assert_eq "$(ctx_slug 'Database Migration!')" "database-migration" "slug"

echo "---"; [ "$FAILED" -eq 0 ] && echo "ALL PASS" || { echo "FAILURES"; exit 1; }
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd plugins/context && bash tests/test_context_manage.sh`
Expected: FAIL — `lib.sh: No such file or directory` (or function-not-found once the file exists but is empty).

- [ ] **Step 3: Implement lib.sh (config + dir)**

Create `plugins/context/scripts/lib.sh`:

```bash
#!/bin/bash
# Shared library for the context plugin's handover management.
# Sourced by bin/context-manage and the test harness. No side effects at source.

ctx_config_file() { printf '%s' "$HOME/.claude/.context-config"; }

# ctx_cfg_get KEY DEFAULT
ctx_cfg_get() {
    local key="$1" def="$2" cfg val
    cfg="$(ctx_config_file)"
    [ -f "$cfg" ] || { printf '%s' "$def"; return; }
    val="$(grep -E "^${key}=" "$cfg" 2>/dev/null | tail -1 | cut -d= -f2-)"
    if [ -n "$val" ]; then printf '%s' "$val"; else printf '%s' "$def"; fi
}

ctx_ttl_days() {
    local v; v="$(ctx_cfg_get ttl_days 90)"
    case "$v" in ''|*[!0-9]*) echo "[WARN] invalid ttl_days '$v'; using 90" >&2; v=90 ;; esac
    printf '%s' "$v"
}

ctx_max_bytes() {
    local v; v="$(ctx_cfg_get max_bytes 28000)"
    case "$v" in ''|*[!0-9]*) echo "[WARN] invalid max_bytes '$v'; using 28000" >&2; v=28000 ;; esac
    printf '%s' "$v"
}

ctx_dir() {
    local d
    d="$(ctx_cfg_get dir "")"
    [ -n "$d" ] || d="${XDG_STATE_HOME:-$HOME/.local/state}/claude-context"
    if ! mkdir -p "$d" 2>/dev/null || [ ! -w "$d" ]; then
        echo "[WARN] handover dir '$d' not writable; using /tmp/claude-context" >&2
        d="/tmp/claude-context"; mkdir -p "$d"
    fi
    if [ ! -f "$d/README.md" ]; then
        printf '# Claude context handovers\n\nSession-to-session handoff files (ctx-<direction>-<subject>.md),\nmanaged by the context plugin. See /context:send and /context:receive.\n' > "$d/README.md"
    fi
    printf '%s' "$d"
}

ctx_opposite() {
    case "$1" in
        parent) printf 'child' ;;
        child)  printf 'parent' ;;
        sibling) printf 'sibling' ;;
        *) return 1 ;;
    esac
}

ctx_slug() {
    printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'
}
```

- [ ] **Step 4: Run to verify pass**

Run: `cd plugins/context && bash tests/test_context_manage.sh`
Expected: `ALL PASS`.

- [ ] **Step 5: Add a gitignore for the plugin's test scratch (none needed) + commit**

```bash
chmod +x plugins/context/tests/test_context_manage.sh
git add plugins/context/scripts/lib.sh plugins/context/tests/test_context_manage.sh
git commit -m "feat(context): lib.sh config + handover dir resolution"
```

---

### Task 2: Filename/direction mapping + front-matter capture

**Files:**
- Modify: `plugins/context/scripts/lib.sh` (add `ctx_filename`, `ctx_capture_meta`)
- Modify: `plugins/context/tests/test_context_manage.sh`

**Interfaces:**
- Consumes: `ctx_opposite`, `ctx_slug`.
- Produces: `ctx_filename <send|receive> <role> <subject>` -> `ctx-<direction>-<slug>.md` (exit 1 on bad role/mode); `ctx_capture_meta <from> <to> <subject> <supersedes>` -> prints a front-matter block to stdout.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_context_manage.sh` before the final summary block:

```bash
# --- filename mapping ---
assert_eq "$(ctx_filename send child migration)" "ctx-parent-to-child-migration.md" "send child -> parent-to-child"
assert_eq "$(ctx_filename send parent migration)" "ctx-child-to-parent-migration.md" "send parent -> child-to-parent"
assert_eq "$(ctx_filename send sibling foo)" "ctx-sibling-to-sibling-foo.md" "send sibling"
assert_eq "$(ctx_filename receive parent migration)" "ctx-parent-to-child-migration.md" "receive parent -> parent-to-child"
assert_eq "$(ctx_filename receive child migration)" "ctx-child-to-parent-migration.md" "receive child -> child-to-parent"
ctx_filename send bogus x >/dev/null 2>&1 && fail "bad role rejected" || pass "bad role rejected"

# --- capture meta ---
meta="$(ctx_capture_meta parent child migration none)"
assert_contains "$meta" "from: parent" "meta from"
assert_contains "$meta" "to: child" "meta to"
assert_contains "$meta" "subject: migration" "meta subject"
assert_contains "$meta" "supersedes: none" "meta supersedes"
assert_contains "$meta" "git_commit:" "meta git_commit present"
```

- [ ] **Step 2: Run to verify fail**

Run: `cd plugins/context && bash tests/test_context_manage.sh`
Expected: FAIL — `ctx_filename: command not found` (or the new asserts fail).

- [ ] **Step 3: Implement**

Append to `scripts/lib.sh`:

```bash
# ctx_filename MODE ROLE SUBJECT  (MODE = send|receive)
ctx_filename() {
    local mode="$1" role="$2" subj="$3" opp direction
    opp="$(ctx_opposite "$role")" || return 1
    case "$mode" in
        send)    direction="${opp}-to-${role}" ;;
        receive) direction="${role}-to-${opp}" ;;
        *) return 1 ;;
    esac
    printf 'ctx-%s-%s.md' "$direction" "$(ctx_slug "$subj")"
}

# ctx_capture_meta FROM TO SUBJECT SUPERSEDES  -> front-matter block on stdout
ctx_capture_meta() {
    local from="$1" to="$2" subj="$3" sup="$4" branch commit dirty
    branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
    commit="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
    if [ -n "$(git status --porcelain 2>/dev/null)" ]; then dirty=true; else dirty=false; fi
    printf -- '---\n'
    printf 'from: %s\n' "$from"
    printf 'to: %s\n' "$to"
    printf 'subject: %s\n' "$subj"
    printf 'created: %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf 'git_branch: %s\n' "$branch"
    printf 'git_commit: %s\n' "$commit"
    printf 'git_dirty: %s\n' "$dirty"
    printf 'cwd: %s\n' "$(pwd)"
    printf 'supersedes: %s\n' "$sup"
    printf -- '---\n\n'
}
```

- [ ] **Step 4: Run to verify pass**

Run: `cd plugins/context && bash tests/test_context_manage.sh`
Expected: `ALL PASS`.

- [ ] **Step 5: Commit**

```bash
git add plugins/context/scripts/lib.sh plugins/context/tests/test_context_manage.sh
git commit -m "feat(context): filename/direction mapping + front-matter capture"
```

---

### Task 3: send (write front-matter + body, supersession)

**Files:**
- Modify: `plugins/context/scripts/lib.sh` (add `ctx_send`; `ctx_prune` referenced — provide a temporary no-op if not yet present, replaced in Task 5)
- Modify: `plugins/context/tests/test_context_manage.sh`

**Interfaces:**
- Consumes: `ctx_dir`, `ctx_filename`, `ctx_capture_meta`, `ctx_opposite`.
- Produces: `ctx_send <target> <subject>` (body on stdin) -> writes `ctx_dir`/`ctx-<opp>-to-<target>-<slug>.md`, prints its path; exit 2 on missing/bad args. Records `supersedes:` = newest prior handover on the same direction (else `none`).

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_context_manage.sh`:

```bash
# --- send ---
fresh_env
p="$(printf 'hello body\n' | ctx_send child demo)"
assert_eq "$p" "$XDG_STATE_HOME/claude-context/ctx-parent-to-child-demo.md" "send returns path"
assert_contains "$(cat "$p")" "hello body" "send wrote body"
assert_contains "$(cat "$p")" "from: parent" "send wrote front-matter"
assert_contains "$(cat "$p")" "supersedes: none" "first send supersedes none"
ctx_send child 2>/dev/null; [ "$?" -eq 2 ] && pass "send missing subject -> exit 2" || fail "send missing subject -> exit 2"
# supersession: a second, different-subject handover on the same direction
sleep 1
p2="$(printf 'body2\n' | ctx_send child 'second topic')"
assert_contains "$(cat "$p2")" "supersedes: ctx-parent-to-child-demo.md" "second send records supersedes"
```

- [ ] **Step 2: Run to verify fail**

Run: `cd plugins/context && bash tests/test_context_manage.sh`
Expected: FAIL — `ctx_send: command not found`.

- [ ] **Step 3: Implement**

Append to `scripts/lib.sh` (the temporary `ctx_prune` stub is replaced by the real one in Task 5 — if Task 5 is done first, skip the stub):

```bash
# Temporary stub; real implementation lands in Task 5.
if ! declare -f ctx_prune >/dev/null; then ctx_prune() { return 0; }; fi

# ctx_send TARGET SUBJECT  (body on stdin)
ctx_send() {
    local target="$1" subj="${2:-}" dir opp fn path prior sup
    if [ -z "$target" ] || [ -z "$subj" ]; then
        echo "[WARN] usage: send <parent|child|sibling> <subject>" >&2; return 2
    fi
    opp="$(ctx_opposite "$target")" || { echo "[WARN] bad direction: $target" >&2; return 2; }
    dir="$(ctx_dir)"
    ctx_prune >/dev/null 2>&1 || true
    fn="$(ctx_filename send "$target" "$subj")" || { echo "[WARN] bad direction: $target" >&2; return 2; }
    path="$dir/$fn"
    prior="$(ls -t "$dir"/ctx-"${opp}"-to-"${target}"-*.md 2>/dev/null | grep -vxF "$path" | head -1)"
    sup="none"; [ -n "$prior" ] && sup="$(basename "$prior")"
    { ctx_capture_meta "$opp" "$target" "$subj" "$sup"; cat; } > "$path"
    printf '%s\n' "$path"
}
```

- [ ] **Step 4: Run to verify pass**

Run: `cd plugins/context && bash tests/test_context_manage.sh`
Expected: `ALL PASS`.

- [ ] **Step 5: Commit**

```bash
git add plugins/context/scripts/lib.sh plugins/context/tests/test_context_manage.sh
git commit -m "feat(context): ctx_send writes front-matter + body with supersession"
```

---

### Task 4: staleness + receive (cat content, newest, size guard)

**Files:**
- Modify: `plugins/context/scripts/lib.sh` (add `ctx_is_stale`, `ctx_stale_note`, `ctx_receive`)
- Modify: `plugins/context/tests/test_context_manage.sh`

**Interfaces:**
- Consumes: `ctx_dir`, `ctx_filename`, `ctx_opposite`, `ctx_max_bytes`.
- Produces: `ctx_is_stale <file>` -> exit 0 if the file's `git_commit` differs from current `HEAD` (exit 1 if same / not comparable); `ctx_stale_note <file>` -> prints a `[WARN] stale` to stderr when stale, always returns 0; `ctx_receive <source> [subject]` -> `[INFO] <file>` + stale note to stderr, cats the file to stdout (or prints the path + `[WARN]` if larger than `max_bytes`); exit 1 if no match, exit 2 on bad direction.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_context_manage.sh`:

```bash
# --- receive ---
fresh_env
printf 'the body\n' | ctx_send child demo >/dev/null
out="$(ctx_receive parent demo 2>/dev/null)"
assert_contains "$out" "the body" "receive cats content"
assert_contains "$out" "from: parent" "receive includes front-matter"
# newest when no subject
sleep 1; printf 'newer\n' | ctx_send child later >/dev/null
assert_contains "$(ctx_receive parent 2>/dev/null)" "newer" "receive newest when no subject"
# no match -> exit 1
ctx_receive parent nope >/dev/null 2>&1; [ "$?" -eq 1 ] && pass "receive no-match exit 1" || fail "receive no-match exit 1"
# bad direction -> exit 2
ctx_receive bogus >/dev/null 2>&1; [ "$?" -eq 2 ] && pass "receive bad dir exit 2" || fail "receive bad dir exit 2"
# size guard: force a tiny max_bytes so the file is 'too large'
printf 'max_bytes=10\n' > "$HOME/.claude/.context-config"
big="$(ctx_receive parent demo 2>/dev/null)"
assert_contains "$big" "ctx-parent-to-child-demo.md" "oversize receive prints path"
rm -f "$HOME/.claude/.context-config"
```

- [ ] **Step 2: Run to verify fail**

Run: `cd plugins/context && bash tests/test_context_manage.sh`
Expected: FAIL — `ctx_receive: command not found`.

- [ ] **Step 3: Implement**

Append to `scripts/lib.sh`:

```bash
# ctx_is_stale FILE -> exit 0 if handover's commit != current HEAD
ctx_is_stale() {
    local f="$1" stored head
    head="$(git rev-parse --short HEAD 2>/dev/null)" || return 1
    stored="$(grep -E '^git_commit:' "$f" 2>/dev/null | head -1 | awk '{print $2}')"
    [ -n "$stored" ] && [ "$stored" != unknown ] && [ "$stored" != "$head" ]
}

ctx_stale_note() {
    ctx_is_stale "$1" && echo "[WARN] stale: repo moved since handover" >&2
    return 0
}

# ctx_receive SOURCE [SUBJECT]
ctx_receive() {
    local source="$1" subj="${2:-}" dir opp file maxb sz
    opp="$(ctx_opposite "$source")" || { echo "[WARN] bad direction: $source" >&2; return 2; }
    dir="$(ctx_dir)"
    if [ -n "$subj" ]; then
        file="$dir/$(ctx_filename receive "$source" "$subj")"
        [ -f "$file" ] || { echo "[WARN] no handover: $(basename "$file")" >&2; return 1; }
    else
        file="$(ls -t "$dir"/ctx-"${source}"-to-"${opp}"-*.md 2>/dev/null | head -1)"
        [ -n "$file" ] || { echo "[WARN] no handover from $source" >&2; return 1; }
    fi
    echo "[INFO] $(basename "$file")" >&2
    ctx_stale_note "$file"
    maxb="$(ctx_max_bytes)"; sz="$(wc -c < "$file")"
    if [ "$sz" -gt "$maxb" ]; then
        echo "[WARN] handover too large to inline ($sz bytes); read it directly:" >&2
        printf '%s\n' "$file"
    else
        cat "$file"
    fi
}
```

- [ ] **Step 4: Run to verify pass**

Run: `cd plugins/context && bash tests/test_context_manage.sh`
Expected: `ALL PASS`.

- [ ] **Step 5: Commit**

```bash
git add plugins/context/scripts/lib.sh plugins/context/tests/test_context_manage.sh
git commit -m "feat(context): ctx_receive with staleness + size guard"
```

---

### Task 5: list / prune / clean

**Files:**
- Modify: `plugins/context/scripts/lib.sh` (add `ctx_list`, replace the `ctx_prune` stub with the real one, add `ctx_clean`)
- Modify: `plugins/context/tests/test_context_manage.sh`

**Interfaces:**
- Consumes: `ctx_dir`, `ctx_ttl_days`, `ctx_is_stale`.
- Produces: `ctx_list` -> one line per `ctx-*.md`: `<age>d <direction> <LIVE|SUPERSEDED> <subject>[ [stale]]`; `ctx_prune` -> deletes `ctx-*.md` older than `ttl_days`, prints removals, `[OK] nothing to prune` if none, always exit 0; `ctx_clean` -> deletes all `ctx-*.md` (keeps README), prints `[OK] removed N handover(s)`.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_context_manage.sh`:

```bash
# --- list ---
fresh_env
printf 'a\n' | ctx_send child first >/dev/null
sleep 1; printf 'b\n' | ctx_send child second >/dev/null
listing="$(ctx_list)"
assert_contains "$listing" "parent-to-child" "list shows direction"
assert_contains "$listing" "LIVE" "list shows LIVE"
assert_contains "$listing" "SUPERSEDED" "list shows SUPERSEDED"
# newest (second) is LIVE
assert_contains "$(echo "$listing" | grep second)" "LIVE" "newest is LIVE"
assert_contains "$(echo "$listing" | grep first)" "SUPERSEDED" "older is SUPERSEDED"

# --- prune ---
d="$(ctx_dir)"
old="$d/ctx-parent-to-child-old.md"; printf -- '---\n---\nold\n' > "$old"
touch -d '100 days ago' "$old"
ctx_prune | grep -q "pruned" && pass "prune removes old" || fail "prune removes old"
[ -f "$old" ] && fail "old file gone" || pass "old file gone"
[ -f "$d/README.md" ] && pass "prune keeps README" || fail "prune keeps README"

# --- clean ---
ctx_clean | grep -q "removed" && pass "clean reports" || fail "clean reports"
ls "$d"/ctx-*.md >/dev/null 2>&1 && fail "clean removed all ctx" || pass "clean removed all ctx"
[ -f "$d/README.md" ] && pass "clean keeps README" || fail "clean keeps README"
```

- [ ] **Step 2: Run to verify fail**

Run: `cd plugins/context && bash tests/test_context_manage.sh`
Expected: FAIL — `ctx_list: command not found` (and prune stub does nothing).

- [ ] **Step 3: Implement**

In `scripts/lib.sh`, **remove the Task 3 `ctx_prune` stub block** (the `if ! declare -f ctx_prune ...` line) and append:

```bash
# newest ctx-<direction>-*.md by mtime, or empty
_ctx_newest_for_direction() {
    ls -t "$1"/ctx-"$2"-*.md 2>/dev/null | head -1
}

ctx_list() {
    local dir f base rest direction subject mt now age newest live stale
    dir="$(ctx_dir)"; now="$(date +%s)"
    for f in "$dir"/ctx-*.md; do
        [ -f "$f" ] || continue
        base="$(basename "$f" .md)"; rest="${base#ctx-}"
        direction="$(printf '%s' "$rest" | grep -oE '^(parent-to-child|child-to-parent|sibling-to-sibling)')"
        [ -n "$direction" ] || continue
        subject="${rest#${direction}-}"
        mt="$(stat -c %Y "$f" 2>/dev/null || echo "$now")"
        age=$(( (now - mt) / 86400 ))
        newest="$(_ctx_newest_for_direction "$dir" "$direction")"
        if [ "$f" = "$newest" ]; then live="LIVE"; else live="SUPERSEDED"; fi
        stale=""; ctx_is_stale "$f" && stale=" [stale]"
        printf '%-4s %-18s %-11s %s%s\n' "${age}d" "$direction" "$live" "$subject" "$stale"
    done
}

ctx_prune() {
    local dir ttl f mt now age removed=0
    dir="$(ctx_dir)"; ttl="$(ctx_ttl_days)"; now="$(date +%s)"
    for f in "$dir"/ctx-*.md; do
        [ -f "$f" ] || continue
        mt="$(stat -c %Y "$f" 2>/dev/null || echo "$now")"
        age=$(( (now - mt) / 86400 ))
        if [ "$age" -gt "$ttl" ]; then
            rm -f "$f"; echo "[OK] pruned $(basename "$f") (${age}d)"; removed=$((removed + 1))
        fi
    done
    [ "$removed" -eq 0 ] && echo "[OK] nothing to prune"
    return 0
}

ctx_clean() {
    local dir f n=0
    dir="$(ctx_dir)"
    for f in "$dir"/ctx-*.md; do
        [ -f "$f" ] || continue
        rm -f "$f"; n=$((n + 1))
    done
    echo "[OK] removed $n handover(s)"
    return 0
}
```

- [ ] **Step 4: Run to verify pass**

Run: `cd plugins/context && bash tests/test_context_manage.sh`
Expected: `ALL PASS`.

- [ ] **Step 5: Commit**

```bash
git add plugins/context/scripts/lib.sh plugins/context/tests/test_context_manage.sh
git commit -m "feat(context): list (live/superseded/stale) + prune + clean"
```

---

### Task 6: bin/context-manage CLI dispatcher

**Files:**
- Create: `plugins/context/bin/context-manage`
- Modify: `plugins/context/tests/test_context_manage.sh` (CLI-level cases)

**Interfaces:**
- Consumes: all `ctx_*` functions from `lib.sh`.
- Produces: an executable that self-locates, sources `../scripts/lib.sh`, and dispatches `send|receive|list|prune|clean|path|help`. Unknown subcommand -> `[WARN]` + exit 2.

- [ ] **Step 1: Write the failing CLI tests**

Append to `tests/test_context_manage.sh`:

```bash
# --- CLI dispatcher ---
CM="$DIR/bin/context-manage"
fresh_env
printf 'clibody\n' | "$CM" send child clidemo >/dev/null
assert_contains "$("$CM" receive parent clidemo 2>/dev/null)" "clibody" "CLI send/receive round-trip"
assert_contains "$("$CM" path)" "claude-context" "CLI path"
assert_contains "$("$CM" list)" "parent-to-child" "CLI list"
"$CM" bogus >/dev/null 2>&1; [ "$?" -eq 2 ] && pass "CLI unknown -> exit 2" || fail "CLI unknown -> exit 2"
"$CM" help | grep -q "context-manage send" && pass "CLI help" || fail "CLI help"
```

- [ ] **Step 2: Run to verify fail**

Run: `cd plugins/context && bash tests/test_context_manage.sh`
Expected: FAIL — `context-manage: No such file or directory`.

- [ ] **Step 3: Implement**

Create `plugins/context/bin/context-manage`:

```bash
#!/bin/bash
# context-manage -- handover management for the context plugin.
# Called by bare name from the skills/commands (bin/ is auto-added to PATH).
# See plugins/CONVENTIONS.md: ${CLAUDE_PLUGIN_ROOT} is not available in skills,
# so scripts self-locate and are invoked by bare name.
set -u
HERE="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
. "$HERE/../scripts/lib.sh"

cmd="${1:-help}"; [ "$#" -gt 0 ] && shift
case "$cmd" in
    send)    ctx_send "${1:-}" "${2:-}" ;;
    receive) ctx_receive "${1:-}" "${2:-}" ;;
    list)    ctx_list ;;
    prune)   ctx_prune ;;
    clean)   ctx_clean ;;
    path)    printf '%s\n' "$(ctx_dir)" ;;
    help|-h|--help)
        cat <<'USAGE'
context-manage send <parent|child|sibling> <subject>    # stdin -> handover; prints path
context-manage receive <parent|child|sibling> [subject] # outputs handover content
context-manage list        # handoffs: age, direction, live/superseded, subject
context-manage prune       # remove handoffs older than ttl_days (default 90)
context-manage clean       # remove all handoffs
context-manage path        # print the handover directory
USAGE
        ;;
    *) echo "[WARN] unknown subcommand: $cmd (try: context-manage help)" >&2; exit 2 ;;
esac
```

- [ ] **Step 4: Make executable, run to verify pass**

Run:
```bash
chmod +x plugins/context/bin/context-manage
cd plugins/context && bash tests/test_context_manage.sh
```
Expected: `ALL PASS`.

- [ ] **Step 5: Commit**

```bash
git add plugins/context/bin/context-manage plugins/context/tests/test_context_manage.sh
git commit -m "feat(context): bin/context-manage CLI dispatcher"
```

---

### Task 7: Wire the slash commands + skills to context-manage

**Files:**
- Modify: `plugins/context/commands/send.md`
- Modify: `plugins/context/commands/receive.md`
- Modify: `plugins/context/skills/send/SKILL.md`
- Modify: `plugins/context/skills/receive/SKILL.md`

Acceptance is behavioural, verified by grep (no code test). Read each file first; preserve its structure and tone, change only the handover mechanics.

- [ ] **Step 1: Update `skills/send/SKILL.md`**

- Replace the auto-captured "Context Directory" line and the "create /tmp/claude-ctx + README" block with a single line using the script:
  `**Handover Dir**: !`context-manage path``
- In the workflow, replace steps that construct `/tmp/claude-ctx/ctx-{direction}-{subject}.md` and write with the Write tool by: assemble the handover body, then pipe it to the script. Show this exact pattern:

  ````markdown
  Assemble the handover body, then write it via the script (it names the file,
  captures git/cwd/time, prunes stale handovers, and prints the path):

  ```bash
  context-manage send <direction> "<subject>" <<'EOF'
  <handover body>
  EOF
  ```
  ````
- Keep direction validation wording (`parent|child|sibling`); note the subject is inferred if the user omits it. Remove every literal `/tmp/claude-ctx` reference and the `path` argument (the location is managed now). Update the `allowed-tools` if needed (Bash is required; Write no longer is).

- [ ] **Step 2: Update `skills/receive/SKILL.md`**

- Replace the "Context Directory" auto-capture + create block with `**Handover Dir**: !`context-manage path``.
- Replace the file-search + Read steps with a single call whose output is the handover content:

  ````markdown
  ```bash
  context-manage receive <direction> [subject]
  ```
  ````
  Note it prints the content directly (or a path with a `[WARN]` for oversized
  handovers, in which case read that path). Remove all `/tmp/claude-ctx` and the
  `path` argument.

- [ ] **Step 3: Update `commands/send.md` and `commands/receive.md`**

Apply the same two changes to the command markdown (they mirror the skills): drop
`/tmp/claude-ctx` and the inline create/README block, drop the `path` argument,
and route through `context-manage send`/`receive`. Keep the examples but rewrite
their paths as `context-manage`-mediated (no literal `/tmp/claude-ctx`).

- [ ] **Step 4: Verify no stale references remain**

Run:
```bash
cd plugins/context
grep -rn '/tmp/claude-ctx' commands/ skills/ && echo "STILL PRESENT" || echo "[OK] no /tmp/claude-ctx left"
grep -rln 'context-manage' commands/ skills/
```
Expected: `[OK] no /tmp/claude-ctx left`; all four files reference `context-manage`.

- [ ] **Step 5: Commit**

```bash
git add plugins/context/commands plugins/context/skills
git commit -m "feat(context): route send/receive through context-manage; drop /tmp/claude-ctx"
```

---

### Task 8: Docs + version bump

**Files:**
- Modify: `plugins/context/README.md`
- Modify: `plugins/context/CHANGELOG.md`
- Modify: `plugins/context/.claude-plugin/plugin.json`

- [ ] **Step 1: Update `README.md`**

Document: the persistent handover location (`~/.local/state/claude-context`), the
`~/.claude/.context-config` keys (`dir`, `ttl_days`, `max_bytes`), the 90-day
auto-prune on send, and the `context-manage` subcommands
(`send`/`receive`/`list`/`prune`/`clean`/`path`). Note handovers now survive
reboot (were `/tmp`), and that legacy `/tmp/claude-ctx` files are left in place.

- [ ] **Step 2: Add a `CHANGELOG.md` entry under `## [Unreleased]`**

```markdown
## [Unreleased]

### Added
- `context-manage` script (`bin/context-manage` + `scripts/lib.sh`) owning
  handover naming, direction mapping, listing, pruning, and send/receive.
- Persistent handover location under `$XDG_STATE_HOME/claude-context` (survives
  reboot; was `/tmp/claude-ctx`), configurable via `~/.claude/.context-config`.
- TTL auto-prune on send (default 90 days), `list` with LIVE/SUPERSEDED + stale
  markers, service-captured front-matter (git/cwd/time), and a size guard so
  oversized handovers are referenced by path rather than truncated.

### Changed
- `/context:send` and `/context:receive` now route through `context-manage`;
  the hardcoded `/tmp/claude-ctx` path and the `path` argument are removed.
```

- [ ] **Step 3: Bump the version**

In `plugins/context/.claude-plugin/plugin.json`, change `"version": "1.3.3"` to `"version": "1.4.0"`.

- [ ] **Step 4: Full verification**

Run:
```bash
cd plugins/context && bash tests/test_context_manage.sh
grep -q '1.4.0' .claude-plugin/plugin.json && echo "[OK] version bumped"
for f in bin/context-manage scripts/lib.sh tests/test_context_manage.sh; do test -x "$f" -o -f "$f" && echo "[OK] $f"; done
```
Expected: `ALL PASS`, `[OK] version bumped`, all files present.

- [ ] **Step 5: Commit**

```bash
git add plugins/context/README.md plugins/context/CHANGELOG.md plugins/context/.claude-plugin/plugin.json
git commit -m "docs(context): document context-manage + persistent handovers; bump to 1.4.0"
```

---

## Notes on ordering

Tasks 1-6 build `lib.sh` + the CLI bottom-up, each with passing bash tests; Task 3
uses a `ctx_prune` stub that Task 5 replaces (remove the stub block in Task 5).
Task 7 (markdown wiring) depends on the CLI existing (Task 6). Task 8 is docs +
version. Recommended order is 1 -> 8 in sequence.
