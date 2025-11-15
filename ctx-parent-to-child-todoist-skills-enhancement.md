# Context: Parent → Child (Todoist Skills Enhancement)

**From Session:** Week 9 Coordination Planning (2025-11-10-0427-week-9.md)
**To Session:** Feature Development - Todoist Skills & Commands
**Handoff Time:** 2025-11-15 02:12 AM (Saturday)

---

## Current Situation

Mae wants to extend the existing Todoist MCP integration with custom skills and slash commands to improve:
1. Cache management
2. Task creation workflows
3. Task update patterns
4. Deletion operations
5. Error handling and recovery

**Current state:**
- Using `todoist` MCP server for basic operations
- Manual cache file at `.claude/.todoist-cache` (text-based)
- Frequent authentication timeouts requiring `/mcp` reconnection
- No high-level abstractions for common workflows

**Why this handoff:**
Need focused development session to design and implement Todoist skills/commands that wrap the MCP integration with better UX and caching.

---

## Current Todoist MCP Integration

### Available MCP Tools

**Tasks:**
- `mcp__todoist__add-tasks` - Create one or more tasks
- `mcp__todoist__update-tasks` - Update existing tasks
- `mcp__todoist__complete-tasks` - Mark tasks complete
- `mcp__todoist__delete-object` - Delete task/project/section/comment
- `mcp__todoist__find-tasks` - Search tasks by text/project/section/labels
- `mcp__todoist__find-tasks-by-date` - Get tasks by date range
- `mcp__todoist__find-completed-tasks` - Get completed tasks

**Projects & Organization:**
- `mcp__todoist__add-projects` - Create projects
- `mcp__todoist__update-projects` - Update projects
- `mcp__todoist__find-projects` - Search projects
- `mcp__todoist__add-sections` - Create sections
- `mcp__todoist__update-sections` - Update sections
- `mcp__todoist__find-sections` - Search sections

**Collaboration:**
- `mcp__todoist__add-comments` - Add comments
- `mcp__todoist__update-comments` - Update comments
- `mcp__todoist__find-comments` - Search comments
- `mcp__todoist__find-project-collaborators` - Get collaborators
- `mcp__todoist__manage-assignments` - Bulk assign/unassign/reassign

**Utilities:**
- `mcp__todoist__get-overview` - Get markdown overview of projects/tasks
- `mcp__todoist__user-info` - Get user details (timezone, goals, plan)
- `mcp__todoist__find-activity` - Audit log of changes
- `mcp__todoist__search` - Global search across tasks/projects
- `mcp__todoist__fetch` - Fetch full task/project by ID

### Current Cache Pattern

**File:** `.claude/.todoist-cache` (text-based markdown)

**Structure:**
```markdown
# Todoist Cache
Last updated: 2025-11-15 02:04:35

## Projects Cache
TTL: 7 days
- BSc Computer Science TU856: 6W9vFRmMgqwXmRxQ
  - Advanced Databases: 6fCMcr8wH9cgMQmj
  - Machine Learning: 6fCMfhphrHJ3Xxv9
  - ... (all module projects)

## Tasks Cache
TTL: 1 hour
- Weekend tasks listed with IDs
- Major deadlines with task IDs
- Self-study blocks with IDs
```

**Issues with current cache:**
1. Manual updates (error-prone)
2. No automatic expiry checking
3. Text parsing required (not structured)
4. No validation of cached IDs
5. No automatic refresh on MCP reconnect

---

## Pain Points to Address

### 1. Cache Management

**Current problems:**
- Cache is manually written markdown (`.claude/.todoist-cache`)
- No automatic TTL enforcement
- No cache invalidation on errors
- Stale data persists across sessions

**Desired improvements:**
- Auto-refresh cache when TTL expires
- Smart caching: projects (7 days), tasks (1 hour), sections (24 hours)
- Cache invalidation on 404 errors
- Structured cache (JSON?) for easier programmatic access
- Cache priming on MCP reconnect

### 2. Task Creation Workflows

**Current problems:**
- Must remember all parameter names
- No templates for common task types
- Verbose JSON syntax for bulk operations
- No validation before API call

**Desired improvements:**
- Quick-add commands: `/todoist:quick-add "Task name" project:FYP due:tomorrow p:p2`
- Task templates: academic assignment, self-study block, deadline task
- Batch creation from lists or markdown
- Pre-submission validation

### 3. Task Update Patterns

**Current problems:**
- Need to find task ID first (separate search)
- Update syntax verbose
- No partial matching for task names
- Multiple API calls for simple changes

**Desired improvements:**
- Update by task name: `/todoist:update "FYP Report" due:"Nov 23 at 11:59pm"`
- Fuzzy search if multiple matches
- Common update shortcuts (reschedule, change priority, add labels)
- Bulk updates with filters

### 4. Deletion Safety

**Current problems:**
- `delete-object` is immediate (no undo)
- Easy to delete wrong item
- No confirmation prompt
- Accidental deletions

**Desired improvements:**
- Confirmation before delete (unless `--force` flag)
- Complete task instead of delete (safer default)
- Bulk delete with preview
- Trash/archive instead of permanent delete

### 5. Error Handling

**Current problems:**
- MCP auth expires frequently (HTTP 404: No transport found)
- No automatic retry
- Error messages not actionable
- Silent failures possible

**Desired improvements:**
- Detect auth errors and prompt `/mcp` reconnect
- Automatic retry with exponential backoff
- Better error messages ("Run /mcp to reconnect")
- Graceful degradation (use cache if API fails)

---

## Proposed Skills & Commands

### Skill: `todoist-workflow`

**Purpose:** High-level Todoist operations with caching, templates, and error recovery

**Slash Commands:**

1. `/todoist:quick-add <task-spec>` - Smart task creation
   ```bash
   /todoist:quick-add "FYP Report draft" project:FYP due:tomorrow 8pm p:p2 duration:3h labels:Deep_Work
   ```

2. `/todoist:update <search-pattern> <changes>` - Update by name/pattern
   ```bash
   /todoist:update "FYP Report" due:"Nov 23 11:59pm"
   ```

3. `/todoist:reschedule <search-pattern> <new-date>` - Quick reschedule
   ```bash
   /todoist:reschedule "Image Processing A2" "next Monday 2pm"
   ```

4. `/todoist:cache refresh` - Force cache refresh
5. `/todoist:cache show` - Display cache contents
6. `/todoist:cache validate` - Check cache validity

7. `/todoist:template academic-assignment` - Create assignment task template
8. `/todoist:template self-study-block` - Create recurring study block

**Implementation needs:**
- Parse natural language task specs
- Fuzzy search for task names
- Cache layer with auto-refresh
- Error recovery with MCP reconnect prompts
- Template system for common task types

### Skill: `todoist-cache-manager`

**Purpose:** Automatic cache management with TTL enforcement

**Features:**
- Structured JSON cache (`.claude/.todoist-cache.json`)
- Automatic TTL checking
- Cache warming on skill load
- Invalidation on errors
- Background refresh for expired entries

**Cache structure:**
```json
{
  "metadata": {
    "last_updated": "2025-11-15T02:04:35Z",
    "user_id": "...",
    "timezone": "Europe/Dublin"
  },
  "projects": {
    "ttl": "2025-11-22T02:04:35Z",
    "data": {
      "6W9vFRmMgqwXmRxQ": {
        "name": "BSc Computer Science TU856",
        "parent": true,
        "children": [...]
      }
    }
  },
  "tasks": {
    "ttl": "2025-11-15T03:04:35Z",
    "weekend": [...],
    "upcoming_deadlines": [...]
  }
}
```

---

## Work Completed (Parent Session)

**Todoist integration usage this session:**
- ✅ Created 3 weekend tasks
- ✅ Updated 5 FYP tasks with corrected deadlines
- ✅ Manually updated `.claude/.todoist-cache` (text-based)
- ✅ Experienced 3 auth timeouts requiring `/mcp` reconnect
- ✅ Discovered datetime skill bug (need to use `date` directly, not slash commands)

**Pain points experienced:**
1. Auth timeouts disruptive (need auto-detect + prompt)
2. Manual cache updates error-prone (typos, formatting)
3. Verbose MCP tool syntax for simple operations
4. No validation before API calls (wrong dates passed through)

---

## Next Actions for Child Session

### Phase 1: Requirements & Design (~30-45 min)

1. **Review existing skills examples**
   - Check `~/.claude/skills/` for skill structure
   - Review datetime skill as reference (fixed bug)
   - Understand skill vs. slash command vs. MCP tool

2. **Design cache system**
   - JSON vs. text-based cache?
   - Where to store: `.claude/.todoist-cache.json`?
   - Cache structure (projects, tasks, sections)
   - TTL enforcement mechanism
   - Cache warming strategy

3. **Design command interfaces**
   - Which operations need commands vs. direct MCP?
   - Natural language parsing for quick-add?
   - Template system structure
   - Error recovery patterns

4. **Define scope for MVP**
   - What's essential vs. nice-to-have?
   - Can ship incrementally?
   - Dependencies on other tools/skills?

### Phase 2: Implementation Plan (~30-45 min)

5. **Create skill structure**
   - Skill directory: `~/.claude/skills/todoist-workflow/`
   - Command definitions
   - Helper scripts (Python? Bash?)
   - Integration with MCP tools

6. **Implement cache manager**
   - JSON cache file structure
   - TTL checking logic
   - Refresh mechanism
   - Error invalidation

7. **Implement priority commands**
   - Start with most painful: cache management
   - Then: quick-add or update-by-name
   - Error recovery helpers

8. **Testing strategy**
   - Test cache refresh
   - Test auth error recovery
   - Test quick-add parsing
   - Validate against real Todoist

### Phase 3: Documentation (~15-20 min)

9. **Write skill documentation**
   - Command usage examples
   - Cache file format
   - Troubleshooting guide
   - Integration with existing workflow

10. **Update project CLAUDE.md**
    - Document new commands
    - Cache file location and structure
    - Common patterns and recipes

---

## Key Questions to Answer

**Architecture:**
1. JSON cache or keep text-based markdown?
2. Single skill or separate cache-manager + workflow skills?
3. Python helper scripts or pure bash?
4. Where to store: project `.claude/` or user `~/.claude/skills/`?

**Functionality:**
5. Natural language parsing for dates (use datetime skill integration)?
6. Template system: static files or dynamic generation?
7. Fuzzy search: how fuzzy? (exact match → contains → levenshtein?)
8. Error recovery: automatic retry or just better prompts?

**User Experience:**
9. What's the minimum viable feature set?
10. How to handle migration from current text cache?
11. Should commands work offline with cache fallback?
12. Verbose output or quiet mode?

---

## Student Context (Mae - C21348423)

**Neurodivergent (ADHD & Autism):**
- Commands should be simple and predictable
- Clear error messages with explicit next steps
- Reduce cognitive load (fewer decisions, smart defaults)
- Validate inputs before API calls (prevent mistakes)

**Current workflow:**
- Uses Todoist heavily for academic task management
- Fibonacci effort system (effort1-34 where each = 0.5h)
- 5 module projects + parent BSc project
- Self-study blocks (18 recurring tasks through Dec 13)
- Weekend planning session pattern

**Common operations:**
- Create deadline tasks (assignments, reports, presentations)
- Update due dates when deadlines change
- Create recurring self-study blocks
- Search for tasks by module project
- Check cache for task IDs

---

## Success Criteria

**Child session should return with:**
1. ✅ Skill architecture decision (JSON cache? Separate skills?)
2. ✅ MVP feature scope defined
3. ✅ Implementation plan with time estimates
4. ✅ Prototype skill structure created (directories, basic commands)
5. ✅ Cache manager design (structure, TTL logic, refresh mechanism)
6. ✅ At least 1-2 working commands implemented
7. ✅ Testing approach defined
8. ✅ Documentation structure created

**Bonus if time permits:**
- Working cache refresh command
- Quick-add command with basic parsing
- Auth error detection helper
- Migration script for existing text cache

**Return context file:** `/tmp/claude-ctx/ctx-child-to-parent-todoist-skills-enhancement.md`

---

## Constraints & Preferences

**Must have:**
- Works with existing Todoist MCP integration (don't replace)
- Backwards compatible with current workflow
- Clear error messages
- Cache invalidation on errors

**Nice to have:**
- Natural language date parsing (integrate datetime skill)
- Fuzzy search for task names
- Task templates
- Batch operations
- Offline mode with cache

**Avoid:**
- Breaking existing Todoist MCP tools
- Complex configuration files
- Requiring external dependencies (keep it bash/python standard lib)
- Silent failures

---

## Related Context

**Files to reference:**
- Current cache: `.claude/.todoist-cache`
- Datetime skill: `~/.claude/skills/datetime-natural/` (bug fixed - use `date` command directly)
- Session management: `.claude/sessions/` (for session tracking patterns)
- Project CLAUDE.md: Has Todoist project IDs documented

**Similar patterns:**
- datetime skill: Wraps `date` command with better UX
- session-management plugin: Structured file-based state
- context-handoff skill: Template-based file generation

---

**Status:** Ready for feature development child session
**Next step:** Start child session with `/context:receive parent todoist-skills-enhancement`

