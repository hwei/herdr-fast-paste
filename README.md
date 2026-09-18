# herdr-fast-paste

Fast, newline-safe clipboard paste for AI terminal applications nested inside **Herdr on Windows**.

It fixes the characteristic `WezTerm -> Herdr -> agy/Claude/Codex` failure where multiline clipboard text:

- becomes a single line;
- appears one character at a time;
- takes seconds to arrive; or
- behaves correctly outside Herdr but not inside a Herdr pane.

## Why it happens

Herdr sits between the outer terminal and the nested application. On affected Windows/ConPTY paths, a paste can be decoded and forwarded as individual key events instead of one bracketed paste. The nested TUI then redraws per character, and CR/LF handling may collapse line breaks.

This helper bypasses that input path. It reads `CF_UNICODETEXT` through the Win32 clipboard API, finds the focused pane with `herdr pane current`, wraps the text in `ESC[200~ ... ESC[201~`, and sends it with `herdr pane send-text`.

Related upstream reports: [herdr #670](https://github.com/herdrdev/herdr/issues/670), [herdr #1764](https://github.com/herdrdev/herdr/issues/1764), and [herdr #3054](https://github.com/herdrdev/herdr/issues/3054).

## Install

Review [`install.ps1`](install.ps1), then run:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/hwei/herdr-fast-paste/main/install.ps1))) -ConfigureWezTerm
```

If you explicitly want the installer to star the repository using your authenticated GitHub CLI, add `-Star`. It is never done by default:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/hwei/herdr-fast-paste/main/install.ps1))) -ConfigureWezTerm -Star
```

The installer:

1. downloads the latest GitHub release and verifies its SHA-256 file;
2. installs the executable under `%LOCALAPPDATA%\Programs\herdr-fast-paste`;
3. installs `herdr_fast_paste.lua` under `%USERPROFILE%\.wezterm`;
4. backs up and updates `%USERPROFILE%\.wezterm.lua` when `-ConfigureWezTerm` is supplied.

After WezTerm reloads its configuration, use **Shift+Insert**. The special path activates only when `herdr.exe` is the foreground process; elsewhere, normal WezTerm `Shift+Insert` behavior is preserved.

## Manual configuration

Copy [`wezterm/herdr_fast_paste.lua`](wezterm/herdr_fast_paste.lua) to `%USERPROFILE%\.wezterm\herdr_fast_paste.lua`, then add this immediately before `return config`:

```lua
require('herdr_fast_paste').apply_to_config(config)
```

## Diagnostics

```powershell
& "$env:LOCALAPPDATA\Programs\herdr-fast-paste\herdr-fast-paste.exe" --check
```

The command prints the focused Herdr pane ID and clipboard byte count, never the clipboard contents.

## Build

```powershell
cargo test
cargo build --release
```

GitHub Actions tests every push and pull request. Tags matching `v*` build a Windows x86-64 ZIP, generate its SHA-256 checksum, and publish both as release assets.

## Security and limitations

- The helper reads the Windows clipboard only when invoked by the configured keybinding.
- Clipboard text is sent to the currently focused Herdr pane. Check the focused pane before pasting secrets.
- Windows process arguments have a practical size limit; extremely large clipboard payloads may fail.
- Text clipboard content is supported. Images are outside the scope of this workaround.

If this saved you time, starring the repository is appreciated but always optional:

```powershell
gh repo star hwei/herdr-fast-paste
```

## License

MIT
