## Git Rules — STRICT
- ALWAYS use native git for ALL commits and pushes
- NEVER use mcp__github__ tools for committing or pushing
- Use mcp__github__ ONLY for: PRs, Issues, GitHub Actions
- Write commit messages to a temp file, then: `git commit -F <file>`
- NEVER use --no-gpg-sign flag

# Cycles strict rules
- yaml API specs always the authority
- always update AUDIT.md files when making changes to server, admin, client repos
- maintain at least 95% or higher test coverage for all code repos

# Running the Demo
- Setup: `python3 -m venv .venv && source .venv/bin/activate && pip install -r agent/requirements.txt`
- Run: `./demo.sh [unguarded|guarded|both]`
- Requires Docker Compose v2
