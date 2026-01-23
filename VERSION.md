# Versioning

This document explains the versioning scheme for the Claude Code Marketplace.

## Two Version Systems

### 1. Marketplace Versions (Git Tags)

**Format**: `vMAJOR.MINOR.PATCH` (e.g., v1.3.0, v1.4.0)

**What they represent**: Release snapshots of the entire marketplace collection

**Examples**:
- `v1.2.0` - Marketplace release with dynamic context injection
- `v1.3.0` - Marketplace release with commands-to-skills migration
- `v1.4.0` - Future marketplace release

**Purpose**:
- Mark significant milestones in marketplace development
- Provide stable snapshots users can reference
- Track overall marketplace evolution

**Who manages**: Marketplace maintainers

### 2. Plugin Versions (plugin.json)

**Format**: `"version": "MAJOR.MINOR.PATCH"` in plugin.json

**What they represent**: Individual plugin releases following semantic versioning

**Examples**:
```json
// session-management/plugin.json
{
  "name": "session",
  "version": "1.3.0"
}

// datetime/plugin.json
{
  "name": "datetime",
  "version": "2.1.0"
}
```

**Purpose**:
- Track individual plugin development
- Signal breaking changes to plugin users
- Independent plugin evolution

**Who manages**: Plugin authors/contributors

## Current State

### Marketplace Releases

| Tag | Date | Description |
|-----|------|-------------|
| v1.3.0 | 2026-01-23 | Commands to skills migration |
| v1.2.0 | 2026-01-23 | Dynamic context injection |

### Plugin Versions (as of v1.3.0)

| Plugin | Version | Status |
|--------|---------|--------|
| session-management | 1.3.0 | Skills migrated |
| context-handoff | 1.3.0 | Skills migrated |
| datetime | (varies) | Commands only |
| code-pointer | (varies) | Commands only |
| semantic-search | (varies) | Commands only |
| pandoc | (varies) | Commands only |
| ref-tracker | (varies) | Commands only |

## Version Independence

**Key Principle**: Marketplace tags ≠ Plugin versions

A marketplace release can include plugins at any version:

**Example: Marketplace v1.4.0 could contain**:
- session-management v1.3.0 (unchanged from v1.3.0)
- context-handoff v1.3.0 (unchanged from v1.3.0)
- datetime v2.2.0 (updated from 2.1.0)
- new-plugin v1.0.0 (newly added)

This allows:
- Independent plugin development cycles
- Targeted updates to specific plugins
- Marketplace snapshots at any point
- Flexible release scheduling

## When to Update Versions

### Update Marketplace Version (Git Tag)

Create new marketplace release when:
- Multiple plugins updated
- Significant marketplace-wide changes
- Major documentation updates
- Breaking changes across plugins
- New plugin additions
- Coordinated feature releases

**Process**:
1. Update affected plugin versions in their plugin.json files
2. Update CHANGELOG.md
3. Commit all changes
4. Create annotated tag: `git tag -a vX.Y.Z -m "Release description"`
5. Push: `git push origin main && git push origin vX.Y.Z`

### Update Plugin Version (plugin.json)

Update individual plugin version when:
- New features added to plugin
- Bug fixes in plugin
- Breaking changes in plugin
- Skills/commands added/removed

**Process**:
1. Update version in plugin.json
2. Update plugin CHANGELOG.md (if exists)
3. Commit changes
4. Marketplace tag created separately (at maintainer's discretion)

## Semantic Versioning Rules

Both marketplace and plugin versions follow [Semantic Versioning](https://semver.org/):

**MAJOR.MINOR.PATCH**

- **MAJOR**: Breaking changes, incompatible API changes
- **MINOR**: New features, backward compatible
- **PATCH**: Bug fixes, backward compatible

**Examples**:

| Change | Marketplace | Plugin |
|--------|-------------|--------|
| Add new plugin | MINOR | N/A |
| Remove plugin | MAJOR | N/A |
| Update docs | PATCH | N/A |
| Add new skill | N/A | MINOR |
| Breaking skill change | N/A | MAJOR |
| Bug fix in skill | N/A | PATCH |
| Coordinated breaking changes | MAJOR | MAJOR (affected plugins) |

## Contributing Guidelines

### For Plugin Contributors

When contributing to an existing plugin:

1. Update plugin version in plugin.json
2. Follow semantic versioning for the plugin
3. Document changes in plugin CHANGELOG.md
4. Test thoroughly (see TESTING.md)
5. Submit PR with version change

**Don't**:
- Create marketplace tags (maintainer responsibility)
- Update other plugin versions
- Change marketplace-level files without discussion

### For Marketplace Maintainers

When creating marketplace releases:

1. Review all pending plugin updates
2. Decide on marketplace version bump
3. Update VERSION.md (this file)
4. Update CHANGELOG.md
5. Create annotated git tag
6. Push tag to remote

**Consider**:
- Coordinating plugin updates
- Documenting plugin version changes
- Testing cross-plugin compatibility
- Communicating breaking changes

## Release History

### v1.3.0 (2026-01-23) - Skills Migration

**Marketplace Changes**:
- Commands → Skills migration infrastructure
- Added TESTING.md
- Added CONTRIBUTING.md
- Added VERSION.md

**Plugin Updates**:
- session-management: 1.2.0 → 1.3.0
- context-handoff: 1.2.0 → 1.3.0

**Details**:
- 9 new SKILL.md files created
- Invocation control added
- All dynamic context injection preserved
- Backward compatible

### v1.2.0 (2026-01-23) - Dynamic Context Injection

**Marketplace Changes**:
- Dynamic context injection framework

**Plugin Updates**:
- session-management: 1.1.0 → 1.2.0
- context-handoff: 1.1.0 → 1.2.0

**Details**:
- Added `!`command`` syntax
- Live git status, timestamps, memory
- Graceful fallbacks for non-git repos
- Bug fix: session:resume path resolution

## FAQ

**Q: Why separate marketplace and plugin versions?**
A: Allows independent plugin development while maintaining stable marketplace snapshots.

**Q: Can plugin versions exceed marketplace versions?**
A: Yes! A plugin at v2.5.0 can exist in marketplace v1.4.0.

**Q: Should plugin versions match across releases?**
A: No. Each plugin evolves independently based on its own changes.

**Q: How do I know what plugin versions are in a marketplace release?**
A: Check the plugin.json files at the tagged commit, or see VERSION.md release notes.

**Q: What if I only update one plugin?**
A: Update plugin version, commit. Marketplace tag created when maintainer deems appropriate.

**Q: Can I create a marketplace tag?**
A: Only marketplace maintainers create tags. Contributors update plugin versions.

---

**Last Updated**: 2026-01-23
**Current Marketplace Version**: v1.3.0
**Maintained By**: Mae Capacite
