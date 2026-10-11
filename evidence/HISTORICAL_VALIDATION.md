# Historical validation — 2026-10-08

These are existing delivery records, not tests run during this staging pass.

- `history/source-test-report-20261008.json`: unchanged 19-group Node VM report; DOM substitution cannot establish browser layout or real browser behavior.
- `history/lua-mock-report-20261008.txt`: original 12-group LuaJIT mock output with only the machine-specific library path redacted. Its final statement says OBS APIs were not exercised; a LuaJIT library was used.
- `history/real-obs-sanitized-20261008.json`: selected historical real OBS observations. Nine core groups plus restart, script-reload and source-removal records are included. Source/instance UUIDs, host paths, UIAutomation references, personal conversation text and screenshot references were omitted. No original screenshots or environment profiles were copied.

Environment: Windows, OBS 32.2.2, browser plugin 2.26.9, CEF 127.0.6533.120, Lua 5.1 / LuaJIT 2.1.1736781742. Historical records report original product logic was unchanged during that acceptance.

Focused physical-key short presses were user-confirmed (increase twice, decrease once, reset once), not independently observed by the agent. Automated SendInput, long holds/OS auto-repeat, background application hotkeys, other OBS versions and other operating systems remain NOT_RUN. No livestream, recording acceptance or public deployment is established.

Historical records are preserved as sanitized summaries. The old mock-output footer refers to real OBS integration not being exercised: the LuaJIT runtime itself was used, while OBS interfaces were substituted. This does not establish cross-version or cross-platform compatibility.
