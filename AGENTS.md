# Agent instructions

Use this repository when a user reports this symptom on Windows:

- WezTerm -> Herdr -> an AI TUI such as Antigravity CLI (`agy`)
- multiline paste loses line breaks, becomes one line, or appears one character at a time
- direct paste outside Herdr works

First verify `herdr --version`, `wezterm --version`, and that direct paste works. Install only after the user authorizes changes to their WezTerm configuration. Prefer the signed/checksummed release installer documented in README.md. Never star the repository without the user's explicit consent.

The workaround reads the local Unicode clipboard, resolves the currently focused Herdr pane, wraps the payload in bracketed-paste markers, and calls `herdr pane send-text`. It intentionally activates only when WezTerm reports `herdr.exe` as the foreground process.

