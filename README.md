# PULSE OBS Meter

A self-contained 0–5 stream overlay with optional controls for one local OBS Browser Source.

## What it does

PULSE makes a small stream status meter easy to customize, export and hand off. The HTML owns its bounded state and display. The optional Lua script sends commands to a deliberately selected OBS source so the page does not need keyboard focus.

## Features

- Editable title, label, two colors and reduced-motion setting.
- Increase, decrease and reset; values stay within 0–5.
- Local persistence and export to one transparent, self-contained HTML file.
- Optional OBS source selection by UUID, with no default hotkeys.
- No server, account, runtime packages, external fonts or network resources.

## Quick start

1. Download or clone this repository. Open `START-HERE.html` (or `index.html`) in a browser, then choose **Open interactive preview**.
2. Open **Customize & control**. Use the buttons, + / right arrow, − / left arrow or R; C toggles controls and Esc closes them. Text inputs retain normal editing behavior.
3. Select **Download configured overlay**. The result contains your settings and current level. This is a local browser download, not an upload.

`overlay.html` is the full application. `PULSE-ready.html` reuses the existing ready export with a generic storage instance: level 0, optional OBS receiver enabled, transparent background. It has its own storage instance; reusing the same file does not promise independent state across sources.

To stop standalone use, close the tab or window. State can remain in that browser's localStorage. Browser and OBS storage are separate, and moving a file or changing profiles can affect recovery.

## OBS integration

Use an existing OBS Studio installation with Browser Source and Lua scripting. Historical checks used **Windows OBS 32.2.2**. OBS 29.1 is the UUID API minimum, not a tested compatibility guarantee.

1. Export an overlay with **Enable optional OBS Lua controls in the exported overlay** enabled, or use `PULSE-ready.html`.
2. Add a **Browser Source**, select **Local file**, and choose the HTML. Start with 1920×1080 or 1080×1920 and transparent background CSS. Initially leave **Shutdown source when not visible** and **Refresh browser source when scene becomes active** off.
3. Add `obs/pulse-controls.lua` once under **Tools → Scripts**. Select the intended source explicitly; nothing is targeted by default.
4. Check the three Test buttons visually. Assign distinct combinations under **Settings → Hotkeys**, then close Interact and any control panel before capture.

Lua dispatches a fixed source-local `javascript_event`. The HTML accepts valid commands only inside OBS, outside preview mode, with explicit opt-in. Lua does not keep a second counter, change scenes or queue/replay commands. Missing, non-browser, remote or non-showing targets are refused. A dispatch status is not a page acknowledgement: loading or reloading can lose commands.

To stop Lua control, remove the script in **Tools → Scripts**. To disable the HTML receiver, clear its opt-in checkbox through Interact or export with opt-in off. Remove the Browser Source to stop display. See [setup, recovery and API references](obs/OBS-SETUP.md).

## Examples

- A manually updated five-step progress/status indicator in a stream.
- The supplied ready HTML as an OBS overlay.
- A configured export with different wording and colors, controlled by the page or the optional OBS companion.

These are usage examples, not evidence of live-stream deployment.

## Testing

Run lightweight checks from the repository root with existing tools:

```text
node tests/source-tests.cjs
python -B tests/run-lua-tests.py --library "<existing Lua shared library>"
```

The Node check writes a generated report excluded by `.gitignore`. It executes the embedded JavaScript with a minimal DOM substitute; it cannot prove browser layout. The Lua runner uses an existing CLI/shared library and mocked OBS interfaces. Neither command installs dependencies or starts OBS.

Historical 2026-10-08 evidence records **19 Node groups, 12 Lua mock groups and nine real OBS core checks**, plus reload/restart/source-removal follow-ups. Focused physical short presses were user-confirmed, not independently observed. See [historical scope](evidence/HISTORICAL_VALIDATION.md) and [release checks](evidence/RELEASE_CHECKS.md) for fresh versus historical results.

`tests/browser-tests.cjs` is optional future Playwright/Chromium testing. It requires those tools separately and was **NOT_RUN** in this release preparation. Real OBS, browser rendering, physical hotkeys, long holds and background hotkeys were not rerun.

## Known limitations

- No universal global-hotkey, cross-platform, cross-version or live-stream acceptance claim.
- Showing in OBS does not prove the page is ready or live on program; verify commands visually.
- Shared sources share state. Multiple independent-source synchronization is not provided.
- Storage depends on the browser/OBS environment; storage failure does not disable session controls.
- No compatibility claim for automated key delivery or long-hold/OS auto-repeat.

## License

Original PULSE software and documentation are available under the [MIT License](LICENSE). External runtime tools are not included or relicensed. See [third-party scope](THIRD_PARTY_NOTICES.md).
