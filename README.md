# Scope

**Select it. Understand it. Solve it.**

Scope is a visual context tool for Omarchy. Select anything on your screen and
get a web-grounded explanation, solution, or research result from Codex—then
hand that context directly to the agent when you need to go deeper.


https://github.com/user-attachments/assets/be330f11-9948-411d-9cf6-d5ada31dd007



```text
see something
    → select it
    → get an answer
```

The interaction is inspired by the convenience of Circle-to-Search, but Scope
is built as a native Omarchy workflow around the desktop, Quickshell, and your
configured Codex agent.

<!-- DEMO: Add the final Scope demo GIF/video here. -->
<!-- SCREENSHOT: Add a Scope lasso/result screenshot here. -->

## Why Scope

Without Scope, visual research often means:

```text
see something
    → screenshot
    → save or copy
    → open a browser or AI tool
    → upload
    → explain what to inspect
    → search
```

With Scope, the workflow is simply:

```text
see something
    → select it
    → get an answer
```

Scope is useful when the thing you need to understand is visible, but not
easily selectable or worth turning into a separate screenshot file.

## What it does

1. Open Scope from the Omarchy bar or the optional keyboard shortcut.
2. Draw a freehand lasso around the screen region you want to inspect.
3. Scope captures only that region and masks the rest.
4. Protected Codex Search analyzes the image and searches the web when useful.
5. Scope shows a concise answer and sources inline.
6. Ask a follow-up using the same selected image, or choose **Open Agent** for
   an interactive Codex session with the visual context.

## Use cases

### Errors and debugging

Circle a terminal error, stack trace, package/build failure, Python traceback,
QML error, browser error, GUI warning, or configuration problem. Scope can
explain what is visible and find relevant documentation or sources.

Scope is not an application crash or coredump replacement; Omarchy already has
native tooling for that. Its advantage is working on anything visible, even
when no crash report exists.

### Visual UI and context

Select an unfamiliar icon, setting, control, or software interface to get an
explanation of what it is and how it is typically used.

### Charts and diagrams

Use a selection to ask about a chart, diagram, technical visual, or other
information that is difficult to describe precisely in text.

### Hard-to-copy content

Scope works with screenshots, video frames, remote desktops, images, and
non-selectable UI.

### Research

Select a product, object, or visual reference and get current web-grounded
information with sources when the search path finds them.

### Deeper work

```text
Scope result
    → Open Agent
    → interactive Codex with the selected context
```

Scope does not claim to identify real people from faces.

## Installation

Scope is installed as a native Omarchy plugin:

```bash
omarchy plugin add https://github.com/sanjyay/scope --enable
```

Enabling the plugin adds a magnifying-glass action to the Omarchy bar's
default right section. Click it to open Scope. Scope does not edit
`~/.config/hypr/bindings.lua`.

To remove the plugin:

```bash
omarchy plugin remove goblin.scope
```

## Usage
<img width="280" height="102" alt="image" src="https://github.com/user-attachments/assets/603a46b9-96bd-48ea-b553-1b020d43cb71" />

1. Click the Scope magnifying glass in the bar.
2. Draw around something on screen and release.
3. Read the answer and open sources explicitly when you want to inspect them.
4. Type a follow-up question if you want another search on the same selection.
5. Choose **Expand** for the full result or **Open Agent** for interactive
   Codex work.
6. Press `Escape` to cancel an active search or close Scope.

The overlay is reusable immediately after cancellation or an Open Agent
handoff.

## Optional keyboard shortcut

The bar widget is the default access path. If you prefer keyboard access, add
this optional entry to `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + SHIFT + Q", "Scope", "omarchy-shell shell summon goblin.scope '{}'")
```

This is a manual user preference; Scope does not add or remove the binding.
If you added it yourself, remove the line when you no longer want the
shortcut.

## Features

- Native Omarchy `overlay` and `bar-widget` plugin kinds.
- Freehand lasso with selected-region-only capture and polygon masking.
- Codex vision analysis and protected web search.
- Concise inline answers with structured, clickable sources.
- Safe rendering of supported inline Markdown links.
- Expandable results and follow-up questions using the same selected image.
- Explicit Open Agent handoff to interactive Codex.
- Immediate Escape cancellation and reusable session lifecycle.
- Omarchy `Color`/`Style` theme integration.
- Private runtime storage with restrictive permissions and automatic cleanup.
- Fail-closed behavior when the selected Omarchy agent is not Codex.

## Agent compatibility

Scope currently supports **Codex** for protected visual search and requires
Codex to be the selected Omarchy default agent. Scope refreshes that selection
when it opens; it does not silently fall back to Codex when another agent is
configured.

The protected path needs all of the following together:

- local image input;
- reliable non-interactive execution;
- web search;
- structured or reliably handled sources;
- restrictive, read-only execution;
- predictable cancellation; and
- a safe interactive handoff.

Codex is the path that has been verified end to end for Scope. Other agents
are not currently enabled—not because they are necessarily incapable, but
because their complete image, web-search, permissions, source, cancellation,
and handoff behavior has not been verified for this plugin.

I currently use Codex as my paid agent, so it is the implementation I can test
thoroughly myself. I do not want to mark another adapter as supported until it
has been exercised under the same constraints.

## Help test additional agents

If you already have access to another Omarchy-compatible agent, help validate
future support by opening an issue or proposing a compatibility contribution.
Useful candidates include:

- Claude Code
- OpenCode
- Antigravity
- Grok
- Gemini CLI
- Copilot
- Pi
- Oh My Pi
- Crush
- other agents with local image input and web search

Please report the agent and CLI version, image-input behavior, headless
execution, web search, cited or structured output, restricted/read-only mode,
and cancellation behavior. Include reproducible steps and sanitized logs.

**Never post API keys, tokens, cookies, credentials, or authentication files in
an issue.**

## Privacy & security

- Scope does not continuously watch the screen or take background screenshots.
- Capture begins only after an explicit selection, and only the selected region
  is retained.
- Temporary images and handoff context stay in private runtime storage with
  restrictive permissions and bounded cleanup. Scope keeps no screenshot
  history.
- Scope does not use the clipboard for Search and does not store API keys or
  tokens. It uses the user's existing Codex authentication.
- Selected images, questions, and web-search data may be transmitted through
  Codex/OpenAI according to the user's service and configuration terms.
- Screenshot contents, model answers, and web results are untrusted data.
- Protected Search is restricted/read-only. Sources open only after an explicit
  click; the browser is not opened automatically.
- Open Agent is an explicit escalation into normal interactive Codex.

See [SECURITY.md](SECURITY.md) for the detailed threat model.

## Limitations

- Codex is the only supported protected visual-search backend in this release.
- Scope inherits Codex and model/provider safety restrictions; some visual
  questions may be refused.
- Scope is not intended for facial recognition or identifying real people from
  faces.
- AI answers and web results can be wrong, incomplete, or outdated. Check the
  sources for important decisions.
- Web search requires internet access and a working Codex account/service.
- Response time depends on the model, network, provider load, and search.
- Some responses may not include useful web sources.

## Technical overview

Scope is a native Omarchy Quattro multi-kind plugin with an overlay and a
bar-widget entry point:

```text
Omarchy bar / optional shortcut
        ↓
Scope overlay
        ↓
freehand lasso
        ↓
selected Wayland region
        ↓
private masked image
        ↓
protected Codex search
        ↓
answer + sources
        ↓
ResultCard
        ↓
optional Open Agent handoff
```

The bar launcher is a native `BarWidget`/`BarIconButton` using Omarchy's
standard magnifying-glass icon and in-process shell summon path. It launches
the existing overlay; it does not create a second Scope instance or spawn a
separate daemon.

Useful entry points and implementation areas:

- [Scope.qml](Scope.qml)
- [ScopeLauncher.qml](ScopeLauncher.qml)
- [ScopeOverlay.qml](ScopeOverlay.qml)
- [ScopeService.qml](ScopeService.qml)
- [components/](components/)
- [scripts/](scripts/)
- [tests/](tests/)

## Development

The repository includes the plugin manifest, runtime helper, QML components,
security documentation, and regression tests. Validate changes in an Omarchy
environment with the current plugin validator, `qmllint`, and the test runner.

Please include the Omarchy version, Scope commit, Codex CLI version,
reproduction steps, and sanitized logs in bug reports. Never include
credentials.

## License

Scope is released under the [MIT License](LICENSE).
