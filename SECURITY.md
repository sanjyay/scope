# Security Policy — Scope

## Scope Search

Scope has one primary analysis path: **Scope Search**. A user explicitly draws a lasso; Scope captures only that region, masks pixels outside the lasso, then sends the image and a question to Codex for protected web search. The selected image, web queries, and web results may be processed by Codex.

Scope supports **Codex** as its verified backend:
- The entire `codex exec` process runs in a minimal-root `bubblewrap` filesystem. It can see required system runtime paths, the installed Codex runtime, the current Scope invocation directory, and the user Secret Service socket. It cannot see the host home, projects, host `/tmp`, `~/.codex`, or `auth.json`.
- ChatGPT authentication is loaded from the OS keyring. If keyring authentication or filesystem isolation cannot be established, protected Search aborts; there is no less-restricted fallback.
- Codex runs with web search enabled, `features.shell_tool=false`, `features.view_image=false`, `--ephemeral`, `--sandbox read-only`, `--ignore-user-config`, `--ignore-rules`, and `--skip-git-repo-check`. The initial Scope image supplied with `-i` remains available.
Unsupported agents fail closed; Scope does not guess at an unsafe command.

## Boundaries

- Screenshot content, links, QR codes, terminal text, web results, and answer text are untrusted data. Scope assumes prompt injection may succeed; OS-enforced filesystem visibility prevents protected Search from accessing arbitrary local files even in that case.
- Scope does not open a browser automatically. Sources open only after an explicit click, and only `http`/`https` URLs are accepted by the card.
- Search requests are ephemeral and read-only. Scope makes no autonomous system changes or commands from returned content.
- Temporary files are private: `$XDG_RUNTIME_DIR/scope/<session>/`, with `umask 077`, `0700` directories, and `0600` files. They are removed on Escape, close, failure, timeout/session end, and by a bounded TTL. Scope keeps no persistent history and does not use the clipboard.
- Escape invalidates the active generation and terminates only the current Scope helper and its dedicated backend process group. Scope never uses `pkill` or `killall` for Codex.

## Masking

Scope enforces fail-closed image masking:
- The screenshot is cropped strictly to the selection bounding box.
- A lasso polygon mask is applied.
- Pixels outside the lasso are excluded (transparent).
- If masking fails (e.g., malformed geometry or image-processing error), the search immediately aborts.
- The unmasked fallback image is never sent to the agent.

## Escalation

Scope maintains two clear boundaries:

**Protected Search:**
- Scope-owned and ephemeral
- Whole-process minimal-root filesystem; only Scope session inputs are user data visible to Codex
- Keyring-backed ChatGPT authentication and first-party web search remain available
- Model-controlled shell and arbitrary path-based image reading are disabled
- Fully cancellable without affecting other sessions

**Open Agent:**
- Explicit user escalation
- Launches a normal interactive Codex session
- User-owned after launch
- Scope does NOT disable Codex approvals or sandboxing
- Scope does NOT kill the interactive session later

Scope cannot prevent a user from selecting sensitive content or prevent an AI provider from retaining/processing content under that provider’s policies. Restriction flags depend on future agent CLI behavior. A malicious administrator with access to the user runtime directory is outside Scope’s protection model.

Report security issues privately to the project maintainer.
