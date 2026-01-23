# Testing Guide

Standardized testing procedures for Claude Code marketplace plugins.

## Overview

This guide documents testing workflows for validating plugin functionality, migrations, and new features. Use context handoff for coordinated testing across parent/child sessions.

## Test Environment Setup

### Standard Test Directories

| Directory | Purpose | Git Status |
|-----------|---------|------------|
| `~/.claude` | Non-git testing, fallback validation | Not a git repo |
| `/tmp/claudetest` | Full workflow testing with git | Git repo (temporary) |

### Initialize Test Environment

```bash
# Create test directory with git repo
mkdir -p /tmp/claudetest
cd /tmp/claudetest
git init
git config user.name "Test User"
git config user.email "test@example.com"

# Create test file and initial commit
echo "test content" > test-feature.js
git add test-feature.js
git commit -m "Initial test commit"
```

## Testing Workflow Pattern

### Phase 1: Parent Session Preparation

**Location**: Any directory (typically `~/.claude` or project root)

**Steps**:
1. Verify current working directory: `pwd`
2. Create context for child session test
3. Send context to child: `/context:send child <test-name>`

**Example**:
```bash
cd ~/.claude
/context:send child plugin-testing
```

**Context should include**:
- Current situation (what's being tested)
- Work completed (features/changes implemented)
- Files modified
- Next actions for child session (specific tests to run)
- Git state

### Phase 2: Child Session Testing

**Location**: `/tmp/claudetest` (or appropriate test directory)

**Steps**:
1. Receive parent context: `/context:receive parent <test-name>`
2. Execute test procedures (see Test Procedures below)
3. Document results in session file
4. Send results back to parent: `/context:send parent <test-name>-complete`

**Example**:
```bash
cd /tmp/claudetest
/context:receive parent plugin-testing
# Run tests...
/context:send parent plugin-testing-complete
```

### Phase 3: Parent Session Validation

**Location**: Return to parent session directory

**Steps**:
1. Receive child context: `/context:receive child <test-name>-complete`
2. Review test results
3. Document findings
4. Proceed with release or bug fixes

**Example**:
```bash
/context:receive child plugin-testing-complete
# Review results and proceed
```

## Test Procedures

### Session Management Plugin Testing

**Prerequisites**: Git repository with at least one commit

**Test Sequence**:

1. **Test `/session:start`**
   ```bash
   /session:start test-session-name
   ```
   **Verify**:
   - Session file created at `.claude/sessions/YYYY-MM-DD-HHMM-test-session-name.md`
   - Dynamic context injection present (git branch, status, time, memory)
   - `.current-session` file updated with session filename

2. **Test `/session:current`**
   ```bash
   /session:current
   ```
   **Verify**:
   - Shows active session name
   - Displays current time
   - Shows git status
   - Shows TODO count (if TODO.md exists)

3. **Make Changes**
   ```bash
   echo "new feature" >> test-feature.js
   git add test-feature.js
   ```

4. **Test `/session:update`**
   ```bash
   /session:update "Added new feature implementation"
   ```
   **Verify**:
   - Update appended to session file
   - Timestamp recorded
   - Git snapshot captured
   - TODO progress tracked

5. **Test `/session:list`**
   ```bash
   /session:list
   ```
   **Verify**:
   - All session files listed
   - Active session highlighted
   - Sorted by most recent first

6. **Test `/session:resume`**
   ```bash
   /session:start another-test
   /session:resume [previous-session-filename]
   ```
   **Verify**:
   - `.current-session` updated to resumed session
   - Session context displayed

7. **Test `/session:end`**
   ```bash
   /session:end
   ```
   **Verify**:
   - Comprehensive summary appended to session file
   - Git summary included (files changed, commits)
   - TODO summary included
   - `.current-session` file cleared (empty, not deleted)

### Context Handoff Plugin Testing

**Prerequisites**: `/tmp/claude-ctx/` directory (created automatically)

**Test Sequence**:

1. **Test `/context:send child`**
   ```bash
   /context:send child test-task
   ```
   **Verify**:
   - File created: `/tmp/claude-ctx/ctx-parent-to-child-test-task.md`
   - Dynamic context auto-captured (timestamp, git state, working dir)
   - Context directory status shown ("Exists" or "Does not exist - will create")

2. **Test `/context:send parent`**
   ```bash
   /context:send parent
   ```
   **Verify**:
   - File created: `/tmp/claude-ctx/ctx-child-to-parent-[inferred].md`
   - Subject inferred from conversation context
   - Direction validation enforced

3. **Test `/context:send sibling`**
   ```bash
   /context:send sibling parallel-work
   ```
   **Verify**:
   - File created: `/tmp/claude-ctx/ctx-sibling-to-sibling-parallel-work.md`
   - Sibling direction properly handled

4. **Test Direction Validation**
   ```bash
   /context:send missing-direction-arg
   ```
   **Verify**:
   - Error message shown requiring parent|child|sibling

5. **Test `/context:receive parent`**
   ```bash
   /context:receive parent test-task
   ```
   **Verify**:
   - Context file read and displayed
   - Original timestamp from sender shown
   - Received timestamp recorded

6. **Test `/context:receive child`**
   ```bash
   /context:receive child
   ```
   **Verify**:
   - Wildcard match finds most recent child-to-parent file
   - Sorted by newest first

7. **Test Custom Path**
   ```bash
   /context:send child custom-test ~/Documents/context/
   /context:receive parent custom-test ~/Documents/context/
   ```
   **Verify**:
   - Files created/read from custom path
   - Path validation works

### Non-Git Directory Testing

**Purpose**: Verify graceful fallbacks when git is unavailable

**Location**: `~/.claude` (non-git directory)

**Test Sequence**:

1. **Test Session Commands**
   ```bash
   cd ~/.claude
   /session:start non-git-test
   ```
   **Verify**:
   - Dynamic injection shows "Not in git repo" fallbacks
   - Session still created successfully
   - No errors or crashes

2. **Test Context Commands**
   ```bash
   /context:send child non-git-context
   ```
   **Verify**:
   - Git state shows graceful fallback messages
   - Context file created successfully

### Dynamic Context Injection Validation

**Check in all commands/skills**:

**Session Management**:
- `/session:start`: Git branch, status, last commit, time, week number, active session, memory files
- `/session:current`: Current time, active session, files modified, TODO status
- `/session:update`: Timestamp, active session, git snapshot, TODO progress
- `/session:end`: End time, active session, final git status, TODO summary
- `/session:resume`: Current time, active session, available sessions count

**Context Handoff**:
- `/context:send`: Timestamp, working directory, git branch, git status, last commit, directory check
- `/context:receive`: Received timestamp, directory check

**Verification Steps**:
1. Run each command
2. Verify all dynamic fields populated or show fallback
3. Confirm no placeholder values (no `!`command`` strings in output)
4. Check token usage is reasonable (<500 tokens per invocation)

### Invocation Control Testing

**Purpose**: Verify `disable-model-invocation: true` behavior

**User-Only Skills** (should NOT auto-execute):
- `/session:end`
- `/session:update`
- `/context:send`
- `/context:receive`
- `/session:help`

**Claude-Invocable Skills** (CAN auto-execute):
- `/session:start`
- `/session:current`
- `/session:list`
- `/session:resume`

**Test Method**:
1. In conversation, mention relevant concepts without explicit command
2. Verify Claude does NOT auto-invoke user-only skills
3. Verify Claude CAN suggest/use Claude-invocable skills when appropriate

### Backward Compatibility Testing

**Purpose**: Verify commands/ still work when skills/ exist

**Test Sequence**:

1. **Verify Both Paths Exist**
   ```bash
   ls ~/.claude/marketplaces/cadrianmae-claude-marketplace/plugins/session-management/commands/
   ls ~/.claude/marketplaces/cadrianmae-claude-marketplace/plugins/session-management/skills/
   ```

2. **Test Skill Takes Precedence**
   ```bash
   /session:start precedence-test
   ```
   **Verify**: Skill version executed (check for skill-specific features)

3. **Test Commands Still Work** (temporarily move skills/)
   ```bash
   mv plugins/session-management/skills plugins/session-management/skills.bak
   /session:start command-fallback-test
   mv plugins/session-management/skills.bak plugins/session-management/skills
   ```
   **Verify**: Command version works when skills unavailable

## Test Results Documentation

### Session File Template

Document test results in session file (`.claude/sessions/*.md`):

```markdown
# Test Session: [Test Name]

**Started**: YYYY-MM-DD HH:MM
**Plugin**: [plugin-name]
**Version**: [version]

## Test Plan

- [ ] Test 1 description
- [ ] Test 2 description
- [ ] Test 3 description

## Test Results

| Test | Status | Notes |
|------|--------|-------|
| Test 1 | ✅ | Working as expected |
| Test 2 | ⚠️ | Minor issue: [description] |
| Test 3 | ❌ | Failed: [error details] |

## Issues Found

1. **Issue Title**: Description, reproduction steps, expected vs actual
2. **Issue Title**: Description, reproduction steps, expected vs actual

## Bugs to Fix

- [ ] Bug 1: Description with file/line reference
- [ ] Bug 2: Description with file/line reference

## Next Steps

1. Fix identified issues
2. Re-test affected functionality
3. Document fixes in changelog
```

### Context File Template

When sending test results to parent:

```markdown
# Context: Child → Parent

**Direction**: Child to Parent
**Timestamp**: YYYY-MM-DD HH:MM:SS
**Working Directory**: /tmp/claudetest
**Git Branch**: main

---

## Current Situation

[What was tested and current status]

## Work Completed

✅ **Tests Passed**:
- Test 1: Description
- Test 2: Description

⚠️ **Tests with Warnings**:
- Test 3: Description + note

❌ **Tests Failed**:
- Test 4: Description + error

## Test Results Summary

| Feature | Status | Notes |
|---------|--------|-------|
| Feature 1 | ✅ | Working correctly |
| Feature 2 | ❌ | Bug found: [description] |

## Files Modified

- .claude/sessions/[session-file].md - Test log
- Other test files

## Issues Found

[Numbered list of bugs with details]

## Next Actions

1. Fix issues
2. Re-test
3. Update documentation

## Git State

- Branch: main
- Commits: [if any test commits made]
```

## Common Test Scenarios

### New Plugin Testing

1. Create test environment
2. Send context to child: `/context:send child new-plugin-test`
3. In child: Install/enable plugin
4. Test all commands/skills
5. Document results
6. Send context back: `/context:send parent new-plugin-test-complete`

### Migration Testing

1. Backup current state: `git stash push -m "pre-migration-test"`
2. Send context to child with migration details
3. In child: Test old and new versions side-by-side
4. Verify backward compatibility
5. Document breaking changes
6. Send results back to parent

### Version Bump Testing

1. Document current version behavior
2. Apply version bump changes
3. Test all affected features
4. Verify dynamic context injection preserved
5. Check for regressions
6. Document changes for changelog

## Checklist: Pre-Release Testing

Before releasing any plugin version:

- [ ] All commands/skills tested individually
- [ ] Dynamic context injection verified
- [ ] Non-git directory fallbacks tested
- [ ] Invocation control validated (if applicable)
- [ ] Backward compatibility confirmed
- [ ] Context handoff workflow tested
- [ ] Edge cases tested (empty repos, missing files, etc.)
- [ ] Documentation updated
- [ ] Changelog updated with test results
- [ ] No errors or warnings in normal usage

## Troubleshooting

### Common Issues

**Issue**: Dynamic injection shows `!`command`` strings
**Cause**: Command preprocessing not running
**Fix**: Verify plugin.json configuration, reload plugins

**Issue**: Context files not found
**Cause**: Wrong directory or missing `/tmp/claude-ctx/`
**Fix**: Check directory path, verify context directory exists

**Issue**: Session file not created
**Cause**: Missing `.claude/sessions/` directory
**Fix**: Create directory: `mkdir -p .claude/sessions`

**Issue**: Git commands fail
**Cause**: Not in git repository
**Fix**: Initialize git or test fallback behavior

## Notes

- Always test in clean environment (fresh `/tmp/claudetest`)
- Use context handoff for coordinated parent/child testing
- Document ALL issues, even minor ones
- Test both happy path and error conditions
- Verify dynamic context injection in every test
- Keep test sessions for future reference

---

**Last Updated**: 2026-01-23
**Version**: 1.0
