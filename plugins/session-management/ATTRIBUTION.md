# Attribution

## Claude Sessions Commands

**Original Author:** Ian Nuttall
**Original Repository:** https://github.com/iannuttall/claude-sessions
**License:** MIT License
**License File:** https://github.com/iannuttall/claude-sessions/blob/main/LICENSE

### Original Work

This plugin is adapted from the `claude-sessions` project by Ian Nuttall, which provides a session management system for Claude Code development workflows. The original project tracks development sessions using markdown files and maintains session state.

### Modifications by Mae Capacite

The following modifications have been made to adapt the commands for user-level installation and improved namespace consistency:

1. **Command namespace changes:**
   - Changed `/project:session-*` to `/session-*` for user-level commands
   - Updated all command references in help text and examples

2. **New functionality:**
   - Added `session-resume.md` command for resuming previous sessions
   - Enhanced session-help with resume command documentation

3. **Integration improvements:**
   - Packaged as Claude Code plugin with proper manifest
   - Organized into plugin directory structure
   - Maintained as git subtree for upstream synchronization

### License Compliance

This adaptation maintains full MIT License compliance by:
- Including original LICENSE file in `upstream/` directory
- Providing clear attribution to original author
- Documenting all modifications made
- Maintaining copyright notices

### Upstream Repository

The original code is preserved in the `upstream/` directory via git subtree, allowing for:
- Clear separation between original and adapted code
- Ability to sync with upstream changes
- Transparent modification tracking

Thank you to Ian Nuttall for creating and sharing the original claude-sessions project under the permissive MIT License.
