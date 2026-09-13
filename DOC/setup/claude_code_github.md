# Claude Code ↔ GitHub setup — repo access, Issues, Projects (v2)

Companion to [`claude_code_setup.md`](./claude_code_setup.md) (which covers Section B, the Claude Code GitHub Action for `@claude` mentions in PRs/issues). This document covers the **other** GitHub integration: giving a local Claude Code session — both the VSCode extension chat and its integrated terminal — read access to repo issues and the Projects (v2) board, via the bundled `github` plugin (MCP) and the `gh` CLI.

Environment this was verified against: WSL2 (Ubuntu) + VSCode Remote-WSL, repo `louaybks/spiresen-saga`. Checked live on 2026-09-13.

## A. Why there are two separate things to authenticate

| Path | Used by | Auth mechanism |
|---|---|---|
| `github` plugin (MCP, `plugin:github:github`) | Claude's native tool calls (e.g. "list issues") | HTTP header templated from an env var — see B |
| `gh` CLI | Claude's `Bash` tool calls (e.g. `gh issue list`) | Its own credential store, independent of env vars — see C |

These do not share credentials automatically. Both need to be set up, and both need to be visible to **every** process that might run them: the VSCode extension host (chat), the integrated terminal, and any Bash tool call Claude makes. In WSL, the reliable way to guarantee that is setting things at the WSL-session level rather than in a single shell's rc file (see D).

## B. The `github` MCP plugin

**What it is**: Anthropic's official `github` plugin (`github@claude-plugins-official`) proxies to GitHub's hosted MCP server. Its config (`~/.claude/plugins/marketplaces/claude-plugins-official/external_plugins/github/.mcp.json`) is fixed and not meant to be hand-edited:

```json
{
  "github": {
    "type": "http",
    "url": "https://api.githubcopilot.com/mcp/",
    "headers": {
      "Authorization": "Bearer ${GITHUB_PERSONAL_ACCESS_TOKEN}"
    }
  }
}
```

The only thing you control is the `GITHUB_PERSONAL_ACCESS_TOKEN` environment variable it substitutes in. If that variable is unset, the header resolves to `Bearer ` (empty), which surfaces in `/mcp` as:

```
Status:  ✗ failed
Issue:   Error POSTing to endpoint: bad request: Authorization header is badly formatted
```

**Fix**: set `GITHUB_PERSONAL_ACCESS_TOKEN` persistently (Section D), then in the terminal run `/mcp` → select `github` → **Reconnect**.

### B1. Token type — use a classic PAT, not fine-grained

This was the non-obvious part: **fine-grained personal access tokens do not expose a "Projects" permission at all**, in either their Repository permissions or Account/Organization permissions section. This is a known, long-standing gap in GitHub's fine-grained token model, not a misconfiguration — the Projects (v2) API only recognizes the classic-token `project` scope.

Since this setup's goal includes reading the Projects (v2) board, **generate a classic token**:

1. `https://github.com/settings/tokens` → **Generate new token (classic)**
2. Name: something identifiable, e.g. `ClaudeSaga`
3. Expiration: pick a reasonable window (e.g. 90 days) and set a rotation reminder — classic tokens can be set to "no expiration," but that's discouraged
4. Scopes:
   - `repo` (Contents, Issues, PRs — classic tokens don't offer read-only granularity per scope)
   - `read:project` (Projects v2 read access)
   - `read:org` — only if the project board is org-owned, not personal-account-owned

If you only need Issues/PR/Contents access and never touch Projects, a fine-grained token scoped to just this repo is the better least-privilege choice — see [`claude_code_setup.md`](./claude_code_setup.md) Section B for the fine-grained pattern used elsewhere in this project. Projects access is specifically what forces classic here.

## C. The `gh` CLI

Independent of the token above — `gh` needs its own login, and does not read `GITHUB_PERSONAL_ACCESS_TOKEN` by default.

```bash
gh auth login --with-token <<< "YOUR_PAT_HERE"
```

This stores the credential in `~/.config/gh/hosts.yml`, which persists across shells and terminal restarts without depending on any environment variable being exported.

Verify:

```bash
gh auth status
gh repo view --json nameWithOwner -q .nameWithOwner
gh issue list --limit 20
```

The same classic PAT from B1 works here too — one token, two places it needs to be registered.

## D. Persisting the token across VSCode chat, integrated terminal, and Bash tool calls

A plain `export GITHUB_PERSONAL_ACCESS_TOKEN=...` typed into one terminal only lives in that shell's process tree — it will not be visible to a newly opened terminal, the VSCode extension host, or Claude's own `Bash` tool calls, which is why this can appear to work once and then "disappear."

**Set it at the WSL-distro level, not in a single shell's rc file:**

```bash
# requires sudo — edits /etc/environment, applied to every new process in this WSL distro
echo 'GITHUB_PERSONAL_ACCESS_TOKEN=ghp_xxx...' | sudo tee -a /etc/environment
```

Then restart WSL itself, not just VSCode's window — `/etc/environment` is only read when a new WSL session starts:

```powershell
# from Windows PowerShell, not inside WSL
wsl --shutdown
```

Reopen VSCode after that. This restarts the Remote-WSL server process along with everything else, so the chat's extension host, a fresh integrated terminal, and Bash tool calls all inherit the variable consistently.

**Why a Reload Window is not enough**: VSCode's Remote-WSL "Reload Window" reuses the existing WSL server process, which already has the old (empty) environment cached. Only a full `wsl --shutdown` forces a new one to spawn and re-read `/etc/environment`.

## E. Verification checklist

| Check | Command | Expected |
|---|---|---|
| `gh` authenticated | `gh auth status` | Logged in as `<user>` |
| `gh` sees the repo | `gh repo view --json nameWithOwner -q .nameWithOwner` | `louaybks/spiresen-saga` |
| `gh` sees issues | `gh issue list --limit 20` | Lists open issues (or empty, not an auth error) |
| MCP plugin connected | `/mcp` in terminal | `github` shows connected, no auth error |
| Claude chat sees issues | Ask: "List open issues in louaybks/spiresen-saga" | Returns issue list via MCP tool call |
| Claude chat sees Projects | Ask: "Show me the Projects v2 board items for this repo" | Returns project items |

Run the `gh` checks first — they're the fastest signal, and a failure there usually means D wasn't actually applied (check with `env | grep GITHUB_PERSONAL_ACCESS_TOKEN` in a **newly opened** terminal).

## F. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `/mcp` shows "Authorization header is badly formatted" | `GITHUB_PERSONAL_ACCESS_TOKEN` unset in the process the extension host runs in | Section D, then `/mcp` → Reconnect |
| Fine-grained token has no "Projects" toggle anywhere | Known gap — fine-grained PATs don't support Projects v2 | Use a classic token (B1) |
| `gh issue list` says "please run gh auth login" | `gh` was never authenticated (separate from the MCP token) | Section C |
| Env var set but still failing after `export` in one terminal | Export only applies to that shell's process tree | Persist via `/etc/environment` (D), not a one-off `export` |
| Reload Window doesn't pick up the new env var | Remote-WSL reuses the cached server process | `wsl --shutdown` from PowerShell, then reopen VSCode |
| A Claude Code **chat session already open** still shows the plugin as failed after reconnecting in the terminal | That session's own MCP handshake is stale — terminal and chat are separate processes | Start a new chat session (or reload it) after D + Reconnect succeed |

## G. Security notes

- Never commit the PAT to the repo (rc files, `.env` committed by mistake, etc.) — `/etc/environment` and `~/.config/gh/hosts.yml` are both outside the repo tree by design.
- Prefer the least-privilege option that still meets the need: fine-grained + repo-scoped for pure Issues/PR/Contents work; classic only because Projects v2 forces it (B1).
- Set a token expiration and rotate rather than "no expiration" — matches the least-long-lived-credential posture already used for AWS in [`claude_code_setup.md`](./claude_code_setup.md) Section C1.
- If the project board or repo moves to an organization with SSO enforcement, the classic PAT will need **SSO authorization** enabled for that org (`github.com/settings/tokens` → token → "Configure SSO") on top of the scopes above.

## Open items

- Confirm whether the repo/project ends up org-owned — if so, revisit whether the org requires PAT approval (`personal-access-token-requests`) before the token becomes usable.
- Set a calendar reminder for the classic token's expiration date.
- Once GitHub ships Projects v2 support for fine-grained tokens (tracked as a long-standing gap, not yet resolved as of this writing), revisit narrowing from classic back to fine-grained.
