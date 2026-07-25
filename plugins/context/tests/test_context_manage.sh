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

echo "---"; [ "$FAILED" -eq 0 ] && echo "ALL PASS" || { echo "FAILURES"; exit 1; }
