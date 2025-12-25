---
description: Sync feature-list.json with GitHub Issues
---

Synchronize feature-list.json with GitHub Issues:

Requires GitHub MCP to be configured.

1. Use GitHub MCP to list open issues with label "feature"

2. For each GitHub issue NOT in feature-list.json:
   - Add new entry with issueNumber linked

3. For each feature in feature-list.json with passes=true:
   - If linked GitHub issue is still open, close it

4. Report sync results
