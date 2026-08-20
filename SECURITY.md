# Security Policy — Scope

## Scope Search

Scope has one primary analysis path: **Scope Search**. A user explicitly draws a lasso; Scope captures only that region, masks pixels outside the lasso, then sends the image and a question to Codex for protected web search. The selected image, web queries, and web results may be processed by Codex.

Scope supports **Codex** as its verified backend:
- Codex runs `codex exec` with web search enabled, `--ephemeral`, `--sandbox read-only`, `--ignore-user-config`, `--ignore-rules`, and `--skip-git-repo-check`.
Unsupported agents fail closed; Scope does not guess at an unsafe command.

## Boundaries

- Screenshot content, links, QR codes, terminal text, web results, and answer text are untrusted data. Scope displays them only and never executes instructions found in them.
- Scope does not open a browser automatically. Sources open only after an explicit click, and only `http`/`https` URLs are accepted by the card.
- Search requests are ephemeral and read-only. Scope makes no autonomous system changes or commands from returned content.
- Temporary files are private: `$XDG_RUNTIME_DIR/scope/<session>/`, with `umask 077`, `0700` directories, and `0600` files. They are removed on Escape, close, failure, timeout/session end, and by a bounded TTL. Scope keeps no persistent history and does not use the clipboard.
- Escape invalidates the active generation and terminates only the current Scope helper and its dedicated backend process group. Scope never uses `pkill` or `killall` for Codex.

## Escalation

**Open Agent** is the explicit escalation boundary. Only after the user selects it does Scope open a normal interactive session of the detected backend (Codex), passing the selected image and concise Scope Search context. It is never opened automatically when a search completes.

## Remaining risks

Scope cannot prevent a user from selecting sensitive content or prevent an AI provider from retaining/processing content under that provider’s policies. Restriction flags depend on future agent CLI behavior. A malicious administrator with access to the user runtime directory is outside Scope’s protection model.

Report security issues privately to the project maintainer.
