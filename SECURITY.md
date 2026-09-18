# Security

## Clipboard access

`herdr-fast-paste` reads Unicode text from the Windows clipboard only when the configured paste key is pressed. It does not run as a service, modify the clipboard, persist clipboard contents, emit telemetry, or log pasted text.

The clipboard payload is passed as one argument to `herdr pane send-text`. Payloads above 24,000 UTF-16 code units are rejected to stay below Windows command-line limits. The destination pane is resolved immediately before each paste, but focus can still change between resolution and delivery; confirm the focused pane before pasting sensitive text.

## Reporting a vulnerability

Please use GitHub private vulnerability reporting for this repository. Do not include real clipboard contents, credentials, tokens, or other secrets in a report.

