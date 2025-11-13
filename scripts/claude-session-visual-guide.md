# claude-session Visual Architecture Guide

## System Architecture

```mermaid
graph TB
    subgraph "User Interface"
        USER[User Commands]
    end

    subgraph "claude-session Script"
        MAIN[Main Entry Point]
        DISCOVER[discover_sessions]
        METADATA[Metadata Manager]
        PICKER[Enhanced Picker]
        DISPLAY[Display Functions]
    end

    subgraph "Read-Only Layer"
        CLAUDE_DIR[~/.claude/projects/]
        JSONL[*.jsonl files]
    end

    subgraph "Read-Write Layer"
        PROJECT_DIR[Project Directory]
        SESSIONS_JSON[.claude/sessions.json]
    end

    USER --> MAIN
    MAIN --> DISCOVER
    MAIN --> METADATA
    MAIN --> PICKER
    MAIN --> DISPLAY

    DISCOVER --> JSONL
    DISCOVER --> SESSIONS_JSON

    METADATA --> SESSIONS_JSON

    PICKER --> DISCOVER
    PICKER --> METADATA

    DISPLAY --> DISCOVER
    DISPLAY --> METADATA

    JSONL -.read only.-> DISCOVER
    SESSIONS_JSON <-.read/write.-> METADATA

    style JSONL fill:#e1f5ff
    style SESSIONS_JSON fill:#fff4e1
    style DISCOVER fill:#e8f5e9
    style METADATA fill:#fff9c4
```

## Directory Structure

```mermaid
graph LR
    subgraph "Project: /home/user/my-project"
        A[my-project/]
        B[.claude/]
        C[sessions.json]
        D[src/]
        E[README.md]

        A --> B
        A --> D
        A --> E
        B --> C
    end

    subgraph "Claude Storage: ~/.claude/projects/"
        F[-home-user-my-project/]
        G[uuid-1.jsonl]
        H[uuid-2.jsonl]
        I[uuid-3.jsonl]
        J[agent-xyz.jsonl]

        F --> G
        F --> H
        F --> I
        F --> J
    end

    C -.metadata.-> G
    C -.metadata.-> H
    C -.metadata.-> I

    style C fill:#fff4e1
    style G fill:#e1f5ff
    style H fill:#e1f5ff
    style I fill:#e1f5ff
    style J fill:#ffebee,stroke-dasharray: 5 5
```

## Path Encoding Flow

```mermaid
flowchart LR
    A["/home/user/my-project"] --> B{encode_path}
    B --> C["Strip leading /"]
    C --> D["home/user/my-project"]
    D --> E["Replace / with -"]
    E --> F["home-user-my-project"]
    F --> G["Add leading -"]
    G --> H["-home-user-my-project"]

    H --> I["~/.claude/projects/<br/>-home-user-my-project/"]

    style A fill:#e3f2fd
    style H fill:#c8e6c9
    style I fill:#fff9c4
```

## Session Discovery Process

```mermaid
sequenceDiagram
    actor User
    participant CLI as claude-session
    participant Encoder as encode_path()
    participant Python as Python Script
    participant JSONL as .jsonl files
    participant Meta as sessions.json

    User->>CLI: claude-session list
    CLI->>Encoder: Get current directory
    Encoder-->>CLI: -home-user-project

    CLI->>Python: discover_sessions()
    Python->>JSONL: Scan *.jsonl files

    loop For each .jsonl file
        JSONL-->>Python: Read events
        Python->>Python: Parse first user message
        Python->>Python: Extract session_id, timestamp
    end

    Python-->>CLI: JSON array of sessions

    loop For each session
        CLI->>Meta: get_metadata(session_id)
        Meta-->>CLI: tags, notes, summary
    end

    CLI->>CLI: Merge data
    CLI->>User: Display formatted list

    Note over JSONL: Read-only access
    Note over Meta: Read-write access
```

## Session File (.jsonl) Structure

```mermaid
graph TB
    subgraph "uuid-abc123.jsonl"
        L1["Line 1: {type: 'user', sessionId: 'abc123',<br/>message: {content: 'First message...'}}"]
        L2["Line 2: {type: 'assistant', ...}"]
        L3["Line 3: {type: 'user', ...}"]
        L4["Line 4: {type: 'queue-operation', ...}"]
        L5["Line N: {type: 'file-history-snapshot', ...}"]
    end

    L1 --> EXTRACT["Extract:<br/>• sessionId<br/>• timestamp<br/>• first message (summary)"]

    style L1 fill:#c8e6c9
    style EXTRACT fill:#fff9c4
```

## Metadata Management Flow

```mermaid
flowchart TD
    START[User: claude-session tag abc123 bug urgent]

    PARSE[Parse Arguments]
    PARSE_OUT["session_id = 'abc123'<br/>tags = ['bug', 'urgent']"]

    CHECK{sessions.json<br/>exists?}

    CREATE[Create sessions.json<br/>with empty object]

    READ[Read current metadata]

    CURRENT["Current data:<br/>{<br/>  'abc123': {<br/>    tags: ['frontend']<br/>  }<br/>}"]

    APPEND[Use jq to append tags]

    JQ["jq '.abc123.tags += [\"bug\", \"urgent\"]'<br/>jq '.abc123.last_updated = now'"]

    WRITE[Write updated JSON]

    FINAL["Final data:<br/>{<br/>  'abc123': {<br/>    tags: ['frontend', 'bug', 'urgent'],<br/>    last_updated: '2025-11-13T18:00:00Z'<br/>  }<br/>}"]

    CONFIRM[✓ Added tags to session abc123]

    START --> PARSE
    PARSE --> PARSE_OUT
    PARSE_OUT --> CHECK
    CHECK -->|No| CREATE
    CHECK -->|Yes| READ
    CREATE --> READ
    READ --> CURRENT
    CURRENT --> APPEND
    APPEND --> JQ
    JQ --> WRITE
    WRITE --> FINAL
    FINAL --> CONFIRM

    style START fill:#e3f2fd
    style PARSE_OUT fill:#fff9c4
    style CURRENT fill:#ffe0b2
    style JQ fill:#c8e6c9
    style FINAL fill:#dcedc8
    style CONFIRM fill:#c5e1a5
```

## Enhanced fzf Picker Flow

```mermaid
sequenceDiagram
    actor User
    participant CLI as claude-session
    participant Discover as discover_sessions()
    participant Builder as Build fzf Input
    participant FZF as fzf Interactive Menu
    participant Claude as claude --resume

    User->>CLI: claude-session -r
    CLI->>Discover: Get all sessions
    Discover-->>CLI: [session1, session2, ...]

    CLI->>Builder: For each session

    loop Build display lines
        Builder->>Builder: Get metadata (tags, summary)
        Builder->>Builder: Format: date | summary | [tags]
        Builder->>Builder: Combine with session_id
    end

    Builder-->>CLI: "id|date|summary|tags"

    CLI->>FZF: Launch picker

    Note over FZF: User sees:<br/>2025-11-13 17:40 | Testing script | [dev]<br/>2025-11-13 14:45 | Marketplace | [plugin]<br/>...

    User->>FZF: Select session ↓↑ Enter
    FZF-->>CLI: Selected line

    CLI->>CLI: Extract session_id (cut -d'|' -f1)
    CLI->>CLI: Update last_resumed timestamp
    CLI->>Claude: claude --resume session_id
    Claude-->>User: Resume session
```

## Command Flow Comparison

```mermaid
graph TB
    subgraph "claude-session list"
        L1[Encode path] --> L2[Discover sessions]
        L2 --> L3[Get metadata]
        L3 --> L4[Format output]
        L4 --> L5[Display colored list]
    end

    subgraph "claude-session stats"
        S1[Discover sessions] --> S2[Count total]
        S2 --> S3[Count with metadata]
        S3 --> S4[Extract all tags]
        S4 --> S5[Count tag occurrences]
        S5 --> S6[Find most recent]
        S6 --> S7[Display report]
    end

    subgraph "claude-session tag"
        T1[Parse arguments] --> T2[Validate session ID]
        T2 --> T3[Init sessions.json]
        T3 --> T4[Append tags with jq]
        T4 --> T5[Update timestamp]
        T5 --> T6[Confirm success]
    end

    style L1 fill:#e3f2fd
    style S1 fill:#f3e5f5
    style T1 fill:#fff3e0
```

## Data Layer Architecture

```mermaid
graph TB
    subgraph "Application Layer"
        APP[claude-session script]
    end

    subgraph "Read-Only Layer: Claude's Native Storage"
        RO_DIR[~/.claude/projects/<encoded-path>/]
        RO_FILES[*.jsonl files]
        RO_DATA["Data:<br/>• session_id<br/>• timestamp<br/>• cwd<br/>• full conversation<br/>• first message"]
    end

    subgraph "Read-Write Layer: Project Metadata"
        RW_DIR[project/.claude/]
        RW_FILE[sessions.json]
        RW_DATA["Data:<br/>• custom summary<br/>• tags[]<br/>• notes[]<br/>• created_at<br/>• last_updated"]
    end

    APP -->|Read Only| RO_FILES
    APP -->|Read/Write| RW_FILE

    RO_DIR --> RO_FILES
    RO_FILES --> RO_DATA

    RW_DIR --> RW_FILE
    RW_FILE --> RW_DATA

    style RO_FILES fill:#e1f5ff,stroke:#01579b,stroke-width:2px
    style RO_DATA fill:#e1f5ff
    style RW_FILE fill:#fff4e1,stroke:#e65100,stroke-width:2px
    style RW_DATA fill:#fff4e1
    style APP fill:#c8e6c9
```

## Python Heredoc Pattern

```mermaid
flowchart LR
    subgraph "Bash Function"
        A[discover_sessions]
        B["sessions_dir=$(...encode_path...)"]
        C["python3 - '$sessions_dir' << 'EOF'"]
    end

    subgraph "Python Script (Embedded)"
        D["import json, glob, sys"]
        E["sessions_dir = sys.argv[1]"]
        F["for jsonl in glob(...):<br/>  parse_file()<br/>  extract_metadata()"]
        G["print(json.dumps(sessions))"]
    end

    subgraph "Back to Bash"
        H["sessions=$(discover_sessions)"]
        I["echo $sessions | jq ..."]
    end

    A --> B
    B --> C
    C -.stdin.-> D
    D --> E
    E --> F
    F --> G
    G -.stdout.-> H
    H --> I

    style C fill:#fff9c4
    style E fill:#c8e6c9
    style G fill:#c8e6c9
    style H fill:#fff9c4
```

## Complete Workflow: Resume Session

```mermaid
flowchart TD
    START([User: claude-session -r])

    ENCODE[Encode current directory path]
    FIND_DIR[Find Claude sessions directory]

    CHECK_DIR{Directory<br/>exists?}
    NO_SESSIONS[Return empty array]

    SCAN[Scan *.jsonl files]

    PYTHON_START[Launch Python script]

    LOOP{More<br/>files?}

    PARSE[Parse .jsonl file]
    EXTRACT["Extract:<br/>• session_id<br/>• timestamp<br/>• first user message"]

    ADD[Add to sessions array]

    SORT[Sort by timestamp DESC]

    PYTHON_OUT[Output JSON to stdout]

    BASH_RECEIVE[Bash receives JSON]

    BUILD_FZF[Build fzf input with metadata]

    LOOP_META{For each<br/>session}

    GET_META[Get metadata from sessions.json]
    FORMAT["Format line:<br/>id|date|summary|tags"]

    LAUNCH_FZF[Launch fzf picker]

    USER_SELECT{User<br/>selects?}

    CANCEL[Exit]

    EXTRACT_ID[Extract session_id from line]

    UPDATE_META[Update last_resumed timestamp]

    RESUME[claude --resume session_id]

    END([Session resumed])

    START --> ENCODE
    ENCODE --> FIND_DIR
    FIND_DIR --> CHECK_DIR

    CHECK_DIR -->|No| NO_SESSIONS
    CHECK_DIR -->|Yes| SCAN

    SCAN --> PYTHON_START
    PYTHON_START --> LOOP

    LOOP -->|Yes| PARSE
    PARSE --> EXTRACT
    EXTRACT --> ADD
    ADD --> LOOP

    LOOP -->|No| SORT
    SORT --> PYTHON_OUT
    PYTHON_OUT --> BASH_RECEIVE

    BASH_RECEIVE --> BUILD_FZF
    BUILD_FZF --> LOOP_META

    LOOP_META -->|Yes| GET_META
    GET_META --> FORMAT
    FORMAT --> LOOP_META

    LOOP_META -->|No| LAUNCH_FZF

    LAUNCH_FZF --> USER_SELECT

    USER_SELECT -->|Cancel| CANCEL
    USER_SELECT -->|Select| EXTRACT_ID

    EXTRACT_ID --> UPDATE_META
    UPDATE_META --> RESUME
    RESUME --> END

    style START fill:#e8f5e9
    style PYTHON_START fill:#fff9c4
    style LAUNCH_FZF fill:#e1f5ff
    style RESUME fill:#c8e6c9
    style END fill:#a5d6a7
```

## Metadata Schema

```mermaid
classDiagram
    class SessionMetadata {
        +string session_id
        +string created_at (ISO 8601, from first event)
        +string modified_at (ISO 8601, from last event)
        +string last_updated (ISO 8601, metadata changes)
        +string summary (custom or AI-generated)
        +array~string~ tags
        +array~string~ notes
        +string last_resumed (optional)
    }

    class CloudeSession {
        +string sessionId
        +string timestamp (first event)
        +string last_modified (last event)
        +string cwd
        +array~Event~ events
        +string default_summary
    }

    class sessions_json {
        +map~string,SessionMetadata~ sessions
    }

    SessionMetadata "0..1" --o "1" CloudeSession : references
    sessions_json "1" *-- "*" SessionMetadata : contains
```

**Key Fields:**
- `created_at`: From first event timestamp in .jsonl (never changes)
- `modified_at`: From last event timestamp in .jsonl (session activity)
- `last_updated`: When metadata was last manually updated (tags, notes, etc)
- `summary`: Custom text or AI-generated summary (via Haiku)

## AI Summary Generation Flow

```mermaid
sequenceDiagram
    participant User
    participant Script as claude-session
    participant Check as is_session_recently_modified()
    participant Haiku as Claude Haiku
    participant JSONL as Session .jsonl
    participant Meta as sessions.json

    User->>Script: summary --generate [ID]

    alt No ID provided
        Script->>Script: get_current_session_id()
        Note over Script: Uses most recent session
    end

    Script->>Check: Check if modified < 5 min ago

    alt Recently modified
        Check-->>Script: true
        Script-->>User: ⚠️ Warning: May be active session
    end

    Script->>Haiku: Resume session with prompt
    Note over Haiku: timeout 30s<br/>Prompt: "Output ONLY a single<br/>short sentence (max 15 words)"

    alt Session locked/timeout
        Haiku--xScript: timeout (124)
        Script-->>User: ERROR: Unable to resume. Try later.
    else Success
        Haiku-->>Script: Generated summary text
        Script->>Script: Filter preamble lines
        Note over Script: Remove "I'll", "Here", etc.
        Script->>Meta: Update summary field
        Script-->>User: ✓ Generated summary: [text]
    end

    style User fill:#e1f5ff
    style Script fill:#fff4e1
    style Haiku fill:#c8e6c9
    style Meta fill:#fff4e1
```

**Key Features:**
- **30-second timeout**: Prevents hanging on active sessions
- **Warning system**: Alerts if session modified in last 5 minutes
- **Preamble filtering**: Removes "I'll create...", "Here's...", etc.
- **Force flag**: `--force` to overwrite existing summaries
- **Content handling**: Gracefully handles list-type message content

## Timestamp Tracking & Auto-Sync

```mermaid
flowchart TB
    START[User runs command]

    SYNC[sync_recent_sessions<br/>Auto-syncs 3 most recent]

    DISCOVER[discover_sessions<br/>Reads all .jsonl files]

    PARSE["Parse each session:<br/>• First event → created_at<br/>• Last event → modified_at"]

    SORT["Sort by modified_at<br/>(most recent first)"]

    TOP3[Get top 3 sessions]

    UPDATE["Update sessions.json:<br/>• created_at from first event<br/>• modified_at from last event<br/>• Preserve existing metadata"]

    DISPLAY[Display to user with dates]

    START --> SYNC
    SYNC --> DISCOVER
    DISCOVER --> PARSE
    PARSE --> SORT
    SORT --> TOP3
    TOP3 --> UPDATE
    UPDATE --> DISPLAY

    style START fill:#e1f5ff
    style SYNC fill:#c8e6c9
    style DISCOVER fill:#fff4e1
    style DISPLAY fill:#a5d6a7
```

**Auto-Sync Triggers:**
- `get_metadata()` - Before reading any metadata
- `update_metadata()` - Before updating metadata
- `append_metadata()` - Before appending to arrays
- `cmd_list()` - When listing sessions
- `cmd_stats()` - When showing statistics

**Benefits:**
- Always accurate timestamps from session files
- No manual timestamp management needed
- Sessions ordered by last activity (most useful)

## Display Format: Created vs Modified

**List Output:**
```
a3c7d3cb-6f04-47bf-8f82-c8acc9a5cef8
  Created:  2025-11-13 14:45
  Modified: 2025-11-13 19:15
  Summary: Fixed fzf picker and added AI summaries
  Tags: enhancement debugging
```

**Picker Output (Same Day):**
```
2025-11-13 14:45→19:15 | Fixed fzf picker | [enhancement,debugging]
```

**Picker Output (Multi-Day):**
```
C:2025-11-12 10:00 M:2025-11-13 15:00 | Database schema design | [backend]
```

## Tag Statistics Generation

```mermaid
flowchart LR
    START[sessions.json]

    EXTRACT["jq '[.[].tags[]?]'"]

    FLAT["Flattened tags:<br/>['testing', 'bug', 'frontend',<br/>'testing', 'urgent', 'bug']"]

    UNIQUE["jq 'unique'<br/><br/>['bug', 'frontend', 'testing', 'urgent']"]

    COUNT["sort | uniq -c<br/><br/>2 bug<br/>1 frontend<br/>2 testing<br/>1 urgent"]

    SORT["sort -rn<br/><br/>2 testing<br/>2 bug<br/>1 urgent<br/>1 frontend"]

    DISPLAY[Display to user]

    START --> EXTRACT
    EXTRACT --> FLAT
    FLAT --> UNIQUE
    UNIQUE --> COUNT
    COUNT --> SORT
    SORT --> DISPLAY

    style START fill:#fff4e1
    style EXTRACT fill:#e1f5ff
    style COUNT fill:#c8e6c9
    style DISPLAY fill:#a5d6a7
```

## Key Design Principles

```mermaid
mindmap
    root((claude-session<br/>Design))
        Non-Invasive
            Never modify Claude files
            Read-only access to .jsonl
            Safe alongside native CLI
        Project-Specific
            Metadata per project
            No global state
            Git-friendly
        ADHD-Friendly
            Clear colored output
            Minimal decisions
            Immediate feedback
            Visual organization
        Flexible Commands
            Optional session IDs
            Current or specific session
            Clear error messages
        Extensible
            Add more metadata fields
            New commands easily
            Future enhancements ready
```

## Complete System Overview

```mermaid
graph TB
    subgraph "User Actions"
        U1[Start Session]
        U2[Resume Session]
        U3[Add Tags/Notes]
        U4[View List/Stats]
    end

    subgraph "claude-session Script"
        CMD[Command Parser]

        subgraph "Core Functions"
            ENC[encode_path]
            DISC[discover_sessions]
            META[Metadata CRUD]
            PICK[enhanced_picker]
        end

        subgraph "Display Functions"
            LIST[cmd_list]
            STATS[cmd_stats]
        end
    end

    subgraph "Data Sources"
        CLAUDE[(Claude Storage<br/>~/.claude/projects/)]
        PROJECT[(Project Metadata<br/>.claude/sessions.json)]
    end

    subgraph "External Tools"
        PYTHON[Python<br/>JSON parsing]
        JQ[jq<br/>JSON manipulation]
        FZF[fzf<br/>Interactive picker]
        CLI[claude CLI<br/>Native resume]
    end

    U1 --> CMD
    U2 --> CMD
    U3 --> CMD
    U4 --> CMD

    CMD --> ENC
    CMD --> DISC
    CMD --> META
    CMD --> PICK
    CMD --> LIST
    CMD --> STATS

    DISC --> PYTHON
    DISC --> CLAUDE

    META --> JQ
    META --> PROJECT

    PICK --> FZF
    PICK --> DISC

    LIST --> DISC
    LIST --> META

    STATS --> DISC
    STATS --> META

    U2 --> CLI

    style CLAUDE fill:#e1f5ff,stroke:#01579b,stroke-width:3px
    style PROJECT fill:#fff4e1,stroke:#e65100,stroke-width:3px
    style CMD fill:#c8e6c9
    style PICK fill:#b2dfdb
```

---

## Summary

The `claude-session` script works by:

1. **Discovery**: Scanning Claude's native `.jsonl` files (read-only) to find sessions
2. **Timestamp Tracking**: Extracting created/modified times from first/last events
3. **AI Summaries**: Using Claude Haiku to generate concise session descriptions
4. **Enhancement**: Adding project-specific metadata (tags, notes, summaries) in `.claude/sessions.json`
5. **Display**: Merging both data sources to show rich, organized session information
6. **Integration**: Working alongside Claude's native commands without modification

**New Features:**
- **AI-powered summaries** - Generate concise descriptions with `--generate` flag
- **Accurate timestamps** - Track both created and modified times from session events
- **Smart ordering** - Sessions sorted by last activity (most recent first)
- **Enhanced display** - Show both created/modified dates in list and picker
- **Activity warnings** - Alerts when trying to summarize recently active sessions
- **Robust handling** - Gracefully handles paths with dots and list-type content

All while following ADHD-friendly design principles and your coding preferences!
