# Scope

Scope is a visual context tool for Omarchy. Select anything on your screen and get a web-grounded explanation, solution, or research result from Codex—then hand it directly to the agent when you need to go deeper.
Press `SUPER + SHIFT + Q`, draw around anything on your screen, and Scope captures only the selected region, uses Codex to analyze it, searches the web when useful, and shows a concise answer with sources directly on your desktop.


<!-- DEMO: Replace this section with the final Scope demo GIF/video before submission. -->
<!-- SCREENSHOT: Add Scope lasso-selection screenshot here. -->
<!-- SCREENSHOT: Add inline result card with sources here. -->

## What it does

- Freehand lasso selection with selected-region-only capture.
- Protected Codex visual search with web access enabled.
- Concise result card with inline answer text and clickable sources.
- Markdown links in answers are rendered as clickable links when safe.
- Follow-up questions reuse the same selected image for another protected search.
- Open Agent hands the selected image and concise context to interactive Codex.
- Escape cancels the active Scope session and returns the overlay to an idle, reusable state.
- Scope follows the active Omarchy theme through the shell's `Color` and `Style` tokens.
- Temporary files live in private runtime storage and are cleaned automatically.

## Why Scope exists

Without Scope, the workflow usually looks like this:

`see something -> screenshot -> save or copy -> open a browser or AI tool -> upload -> explain what to inspect -> search`

Scope removes that friction:

`see something -> circle it -> get an answer`

The goal is to make anything visible on the desktop immediately searchable without manually taking a screenshot, saving it, opening a browser, or explaining which part of the screen you mean.

## Use cases

Scope is useful for:

- terminal errors and stack traces
- application errors and warnings
- unfamiliar UI elements and icons
- products and objects
- charts and diagrams
- screenshots, remote desktops, and video frames
- text that is hard to copy
- quick web-grounded research from a visual context

Scope is not designed for face recognition or other identification of real people from images.

## How it works

1. Press `SUPER + SHIFT + Q`.
2. Draw a lasso around the region you want to inspect.
3. Scope captures only the selected area and masks everything else.
4. Codex runs in a protected, read-only search path with web search enabled.
5. Scope normalizes the result, shows sources, and keeps the browser closed until you click a link.
6. Optional follow-ups reuse the same private image.
7. `Open Agent` launches normal interactive Codex for deeper work.

## Features

- Freehand lasso selection.
- Protected visual search on the selected region only.
- Codex web search with sourced results.
- Clickable source chips.
- Clickable links in supported answer text.
- Expand/collapse result view.
- Follow-up questions inside the result card.
- Explicit `Open Agent` escalation.
- Private runtime storage under `$XDG_RUNTIME_DIR/scope/<session>/`.
- Automatic cleanup on close, Escape, failure, timeout, or session end.
- Omarchy theme integration through `Color` and `Style`.
- Fail-closed behavior when the configured Omarchy agent is not Codex.

## Requirements

Scope currently requires:

- Omarchy Quattro / Quickshell
- `Codex` CLI
- `grim`
- ImageMagick (`convert`) for masking
- `jq` for helper-side parsing

For protected Scope Search, your Omarchy default agent must be set to Codex. If another agent is selected, Scope refuses to start the search path and shows a clear error instead of falling back.

## Agent compatibility

Scope Search is currently supported and tested with:

| Agent | Scope Search |
| --- | --- |
| Codex | Supported and tested |
| Other Omarchy agents | Not currently enabled |

Scope was intentionally built to fail closed until a protected visual-search path has been verified end to end.

## Installation

The final public GitHub URL has not been attached to this checkout yet. Before
publishing, replace the placeholder below with that URL:

<!-- INSTALL: Replace <public-git-url> with the final GitHub clone URL before publishing. -->

```bash
omarchy plugin add <public-git-url> --enable
~/.config/omarchy/plugins/goblin.scope/install.sh
```

The first command uses Omarchy's official plugin installer. The second adds
Scope's `SUPER + SHIFT + Q` binding; it is idempotent and does not require root.

For local development, run the installer from a checkout instead:

```bash
./install.sh
```

This copies only Scope's runtime files into Omarchy's plugin directory, adds
the shortcut, and enables the plugin in the running shell.

To remove it:

```bash
~/.config/omarchy/plugins/goblin.scope/install.sh --uninstall
```

## Usage

1. Press `SUPER + SHIFT + Q`.
2. Circle the on-screen content you want to inspect.
3. Release the pointer to start protected search immediately.
4. Read the answer and open sources only when you want to inspect them.
5. Type a follow-up question if you want a second search on the same selection.
6. Click `Open Agent` when you want the handoff to interactive Codex.
7. Press `Escape` to cancel the active session or close Scope.

## Privacy & security

- Scope does not continuously watch the screen.
- No background screenshot history is kept.
- Only the lasso-selected region is captured.
- Temporary files are stored privately in `$XDG_RUNTIME_DIR/scope/<session>/` with `0700` directories and `0600` files.
- Temporary captures are cleaned automatically.
- Scope does not use the clipboard for Search.
- Scope does not store API keys or tokens.
- Protected search runs in a restricted, read-only Codex mode.
- Screenshot content, answer text, and web results are treated as untrusted input.
- Scope does not open a browser automatically.
- Source URLs open only after explicit user clicks.
- `Open Agent` is an explicit escalation into normal interactive Codex.

See [SECURITY.md](SECURITY.md) for the full threat model.

## Limitations

- Codex is the only supported protected visual-search backend in this release.
- Scope inherits the capabilities and safety limits of Codex and its search mode.
- Web answers can be wrong, incomplete, or outdated.
- Not every visual query will produce useful sources.
- Internet access is required for web search.
- Some visual questions may be refused by the underlying agent.

## Help test additional agents

I would welcome help from people who already have working access to compatible agents and want to validate a protected visual-search adapter.

If you use any of the following, you can help test future support:

- Claude Code
- OpenCode
- Antigravity
- Grok
- Gemini CLI
- Copilot
- Pi
- Oh My Pi
- Crush
- other Omarchy agents with image and web-search capabilities

Helpful reports include:

- CLI version
- whether non-interactive image input works
- whether web search works
- whether structured or cited output is available
- whether a restricted or read-only mode is actually enforceable

Please open an issue with reproducible steps and sanitized logs if you can help.

Never post API keys, tokens, cookies, or authentication files in an issue.

## Development / technical notes

Scope is a Quickshell overlay with a small helper pipeline:

`Quickshell overlay -> freehand lasso -> private masked PNG -> protected Codex execution -> answer + sources -> ResultCard`

The protected search path is separate from the interactive `Open Agent` path. Search is ephemeral and read-only; escalation is explicit and user-owned.

Useful files:

- [Scope.qml](Scope.qml)
- [ScopeService.qml](ScopeService.qml)
- [components/ResultCard.qml](components/ResultCard.qml)
- [components/LassoOverlay.qml](components/LassoOverlay.qml)
- [scripts/scope-helper](scripts/scope-helper)

## Known issues

No current known issues are documented beyond the limitations above.

## License

MIT License. See [LICENSE](LICENSE).
