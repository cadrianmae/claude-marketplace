# Versioning

This document explains the versioning scheme for the Claude Code Marketplace.

## Plugin-Only Versioning

This marketplace uses **plugin-specific versioning and releases only**. Each plugin maintains its own independent version number and git tags.

**No marketplace-wide version tags** are created. Plugins evolve independently.

## Tag Format

**Pattern**: `{plugin-name}-vMAJOR.MINOR.PATCH`

**Examples**:
- `session-v1.3.0` - Session management plugin v1.3.0
- `datetime-v2.1.0` - Datetime plugin v2.1.0
- `tool-docs-v1.0.1` - Tool docs plugin v1.0.1
- `feedback-v1.0.2` - Feedback plugin v1.0.2

## Semantic Versioning

All plugins follow [Semantic Versioning](https://semver.org/): `MAJOR.MINOR.PATCH`

- **MAJOR**: Breaking changes, incompatible API changes
- **MINOR**: New features, backward compatible
- **PATCH**: Bug fixes, backward compatible

**Examples**:

| Change | Version Bump |
|--------|--------------|
| Add new skill | MINOR |
| Breaking skill change | MAJOR |
| Bug fix in skill | PATCH |
| Documentation update | PATCH |
| Remove command/skill | MAJOR |
| Deprecate with backward compatibility | MINOR |

## Release Workflow

### 1. Update Plugin Version

Edit `plugins/{plugin}/.claude-plugin/plugin.json`:

```json
{
  "name": "plugin-name",
  "version": "1.2.0"
}
```

### 2. Update Changelog (Optional)

If the plugin has a `CHANGELOG.md`, document changes:

```markdown
## [1.2.0] - 2026-01-26

### Added
- New skill: `/skill-name` for doing X

### Fixed
- Bug where Y didn't work in Z scenario
```

### 3. Commit Changes

```bash
git add plugins/{plugin}/.claude-plugin/plugin.json
git commit -m "{plugin}: Release v1.2.0 - Brief description

- Change 1
- Change 2
- Change 3"
```

### 4. Create Git Tag

```bash
git tag -a {plugin}-v1.2.0 -m "Release {plugin} v1.2.0"
```

### 5. Push to GitHub

```bash
git push origin main
git push origin {plugin}-v1.2.0
```

### 6. Create GitHub Release (Optional)

```bash
# Using GitHub CLI
gh release create {plugin}-v1.2.0 \
  --title "{plugin} v1.2.0" \
  --notes "Release notes here"

# Or via GitHub web interface
```

## Current Plugin Versions

| Plugin | Version | Last Updated |
|--------|---------|--------------|
| cadrianmae-integration | 1.0.1 | 2026-01-26 |
| code-pointer | 1.0.0 | - |
| context | 1.3.0 | 2026-01-23 |
| datetime | 1.1.0 | - |
| feedback | 1.0.2 | 2026-01-26 |
| gencast | 1.0.0 | - |
| pandoc | 1.0.0 | - |
| semantic-search | 1.0.0 | - |
| session | 1.3.0 | 2026-01-23 |
| tool-docs | 1.0.1 | 2026-01-24 |
| track | 1.1.0 | - |

## Recent Releases

### cadrianmae-integration v1.0.1 (2026-01-26)
- Added README.md documentation
- Fixed plugin validation issues

### feedback v1.0.2 (2026-01-26)
- Added README.md documentation
- Fixed plugin validation issues

### tool-docs v1.0.1 (2026-01-24)
- Simplified agent prompt to fix WebFetch invocation
- Moved agent to user agents directory as workaround

### tool-docs v1.0.0 (2026-01-24)
- Initial release with pandoc-guide agent
- Comprehensive documentation specialist

### session v1.3.0 (2026-01-23)
- Commands → Skills migration
- Added 7 SKILL.md files with invocation control
- Preserved dynamic context injection
- Backward compatible (commands still work)

### context v1.3.0 (2026-01-23)
- Commands → Skills migration
- Added 2 SKILL.md files with invocation control
- Preserved dynamic context injection
- Backward compatible (commands still work)

## Migration Notes

### Historical Tags

This marketplace previously used marketplace-wide tags (`v1.2.0`, `v1.3.0`). These are now deprecated:

- `v1.3.0` (2026-01-23) - Last marketplace-wide release
- `v1.2.0` (2026-01-23) - Deprecated

**Going forward**: Only plugin-specific tags (`{plugin}-vX.X.X`) will be created.

## Contributing Guidelines

### For Contributors

When contributing to a plugin:

1. Update version in plugin's `plugin.json`
2. Follow semantic versioning rules
3. Document changes in plugin's CHANGELOG.md (if exists)
4. Test thoroughly (see TESTING.md)
5. Submit PR with version change
6. Maintainer will create git tag after merge

**Don't**:
- Create git tags yourself (maintainer handles this)
- Update other plugin versions
- Change marketplace-level files without discussion

### For Maintainers

When merging plugin updates:

1. Review version bump follows semantic versioning
2. Verify CHANGELOG.md updated (if exists)
3. Merge PR to main
4. Create plugin-specific tag: `git tag -a {plugin}-vX.X.X -m "Release {plugin} vX.X.X"`
5. Push tag: `git push origin {plugin}-vX.X.X`
6. Optionally create GitHub release with notes

## FAQ

**Q: Why plugin-only versioning?**
A: Allows independent plugin development without coordinating marketplace-wide releases.

**Q: How do I know what versions are compatible?**
A: Check individual plugin.json files. Plugins don't have cross-dependencies.

**Q: Can I install specific plugin versions?**
A: Yes, use git tags to checkout specific plugin versions if needed.

**Q: What happened to marketplace v1.x.x tags?**
A: Deprecated. The marketplace now uses plugin-specific tags only.

**Q: Do all plugins need to be released together?**
A: No. Each plugin releases independently when it has changes.

**Q: How do I see plugin release history?**
A: Use `git tag --list {plugin}-v*` to see all releases for a specific plugin.

**Q: Can plugins have different major versions?**
A: Yes! Plugin versions are independent. One plugin can be at v3.0.0 while another is at v1.2.0.

## Examples

### View All Releases

```bash
# All tags (all plugins)
git tag --list

# Specific plugin releases
git tag --list session-v*
git tag --list datetime-v*

# Recent releases
git tag --list --sort=-creatordate | head -10
```

### Checkout Specific Version

```bash
# Checkout specific plugin version
git checkout tags/session-v1.3.0

# Return to latest
git checkout main
```

### Release Multiple Plugins

If multiple plugins are updated in the same commit:

```bash
# Commit all changes
git add .
git commit -m "Multiple plugin updates

- session: v1.3.1 - Bug fix
- datetime: v2.0.0 - Breaking change
- feedback: v1.0.3 - Documentation"

git push origin main

# Create tags for each updated plugin
git tag -a session-v1.3.1 -m "Release session v1.3.1"
git tag -a datetime-v2.0.0 -m "Release datetime v2.0.0"
git tag -a feedback-v1.0.3 -m "Release feedback v1.0.3"

# Push all tags
git push origin --tags
```

---

**Last Updated**: 2026-01-26
**Maintained By**: Mae Capacite
