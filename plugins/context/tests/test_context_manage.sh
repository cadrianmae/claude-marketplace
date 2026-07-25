#!/usr/bin/env bash
# Tests for the context plugin's bin/context-manage. Isolated env (temp HOME + XDG state).
set -u
DIR="$(cd "$(dirname "$0")/.." && pwd)"
. "$DIR/bin/context-manage"

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

# --- capture meta outside a git repo ---
meta_norepo="$(cd "$TMP" && ctx_capture_meta parent child x none)"
assert_contains "$meta_norepo" "git_dirty: unknown" "meta git_dirty unknown outside repo"

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

# --- CLI dispatcher ---
CM="$DIR/bin/context-manage"
fresh_env
printf 'clibody\n' | "$CM" send child clidemo >/dev/null
assert_contains "$("$CM" receive parent clidemo 2>/dev/null)" "clibody" "CLI send/receive round-trip"
assert_contains "$("$CM" path)" "claude-context" "CLI path"
assert_contains "$("$CM" list)" "parent-to-child" "CLI list"
"$CM" bogus >/dev/null 2>&1; [ "$?" -eq 2 ] && pass "CLI unknown -> exit 2" || fail "CLI unknown -> exit 2"
"$CM" help | grep -q "context-manage send" && pass "CLI help" || fail "CLI help"

echo "---"; [ "$FAILED" -eq 0 ] && echo "ALL PASS" || { echo "FAILURES"; exit 1; }
