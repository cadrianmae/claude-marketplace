[![Version](https://img.shields.io/badge/version-1.1.1-blue.svg)](https://github.com/cadrianmae/claude-marketplace)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)

# gencast Plugin for Claude Code

Auto-invoke gencast to generate conversational podcasts from documents. Always uses `--minimal` flag for clean context management.

## Features

- **Auto-invocation** - Claude automatically suggests podcast generation when you mention "podcast", "audio", or "dialogue"
- **Full CLI support** - All gencast options available: styles, audiences, voices, planning
- **Minimal output** - Always uses `--minimal` flag to reduce context bloat
- **Smart workflows** - Validates inputs, checks installation, provides clear progress updates
- **Reference docs** - Voice options and style/audience combinations documented

## Installation

The gencast CLI tool is required:

```bash
pip install gencast
```

## Quick Start

### Auto-invocation

Just mention podcast generation in your conversation:

```
"Can you convert this lecture.md to a podcast?"
```

Claude will automatically use gencast with appropriate options.

### Explicit Commands

**Generate podcast:**
```bash
/gencast:podcast lecture.md
```

**With custom style and audience:**
```bash
/gencast:podcast api_docs.md --style interview --audience technical
```

**Generate planning document only:**
```bash
/gencast:plan research_paper.md
```

## Styles

- `educational` (default) - Structured learning format
- `interview` - Q&A conversational style
- `casual` - Relaxed, friendly discussion
- `debate` - Contrasting perspectives

## Audiences

- `general` (default) - Broad accessibility
- `technical` - Assumes domain knowledge
- `academic` - Scholarly approach
- `beginner` - Introductory level

## Voices

6 voices available (alloy, echo, fable, onyx, nova, shimmer):

**Defaults:**
- HOST1: nova (bright, energetic)
- HOST2: echo (warm, friendly)

**Custom voices:**
```bash
/gencast:podcast doc.md --host1-voice onyx --host2-voice alloy
```

## Examples

### Educational Podcast (Default)

```bash
/gencast:podcast lecture_notes.md
```

### Technical Interview

```bash
/gencast:podcast api_guide.md --style interview --audience technical
```

### Beginner-Friendly Casual

```bash
/gencast:podcast intro.md --style casual --audience beginner
```

### Academic Debate

```bash
/gencast:podcast paper.md --style debate --audience academic --with-planning
```

### Multi-Chapter Course

```bash
/gencast:podcast ch1.md ch2.md ch3.md -o course.mp3
```

## Options

| Option | Description | Values |
|--------|-------------|--------|
| `--style` | Podcast style | educational, interview, casual, debate |
| `--audience` | Target audience | general, technical, academic, beginner |
| `--with-planning` | Generate comprehensive plan first | flag |
| `--save-dialogue` | Save dialogue script to text file | flag |
| `--save-plan` | Save planning document to text file | flag |
| `-o, --output` | Output file path | path (default: podcast.mp3) |
| `--host1-voice` | Voice for HOST1 | alloy, echo, fable, onyx, nova, shimmer |
| `--host2-voice` | Voice for HOST2 | alloy, echo, fable, onyx, nova, shimmer |

## Commands

### /gencast:podcast

Generate podcast with full control over options.

```bash
/gencast:podcast <input-files...> [options]
```

### /gencast:plan

Generate planning document only (no audio).

```bash
/gencast:plan <input-file>
```

## Input Formats

Supported formats:
- Markdown (.md)
- Text (.txt)
- PDF (.pdf) - Requires `MISTRAL_API_KEY` environment variable

## Output

With `--minimal` flag, gencast shows:
- Milestone: Planning (if --with-planning)
- Milestone: Generating dialogue
- Milestone: Synthesizing audio
- Final: Output path and duration

## Advanced Usage

### With Planning and Dialogue Saving

```bash
/gencast:podcast complex_doc.md --with-planning --save-dialogue --save-plan
```

Creates:
- `podcast.mp3` - Audio file
- `podcast_dialogue.txt` - Dialogue script
- `podcast_plan.txt` - Planning document

### Review Plan Before Audio

```bash
/gencast:plan document.md
# Review document_plan.txt
/gencast:podcast document.md --with-planning
```

### Custom Voice Pairing

```bash
/gencast:podcast story.md --host1-voice fable --host2-voice shimmer --style casual
```

## Reference Documentation

- `skills/gencast/references/voices.md` - Voice options and pairings
- `skills/gencast/references/styles.md` - Style/audience combinations

## Tips

1. **Always uses --minimal** - Context-friendly output
2. **Default works well** - educational + general suits most content
3. **Match style to content** - interview for Q&A, debate for analysis
4. **Use planning for complex docs** - Ensures comprehensive coverage
5. **Save dialogue for review** - Check script before re-generating

## Requirements

- gencast CLI (`pip install gencast`)
- For PDFs: `MISTRAL_API_KEY` environment variable

## License

MIT
