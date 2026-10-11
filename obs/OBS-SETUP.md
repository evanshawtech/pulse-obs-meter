# Optional PULSE controls for OBS

Status: **core integration verified in Windows OBS 32.2.2**. This package adds a small Lua script so OBS can dispatch increase, decrease and reset commands without keyboard focus in the overlay page. You can still use the portable HTML on its own. The final passed, failed and unrun items are recorded in [the real OBS results](../evidence/HISTORICAL_VALIDATION.md); this is not a compatibility claim for other environments.

## Setup

Use an existing OBS Studio installation with Browser Source and Lua scripting. The UUID APIs require **OBS 29.1 or newer**; that is an API minimum, not a tested compatibility promise. The script also checks the APIs/procedure it needs and refuses unsupported commands.

1. Open this package's `START-HERE.html` in your usual browser. Open **Customize & control**, set the design, and tick **Enable optional OBS Lua controls in the exported overlay**. Click **Download configured overlay**. Older exports and the unchanged public demo do not contain this feature.
2. In OBS, add or update one **Browser Source**, enable **Local file**, and select the newly downloaded HTML. Use 1920 × 1080, or 1080 × 1920 for portrait. Keep the default transparent background CSS. Wait until the meter is visible. For the first check, leave **Shutdown source when not visible** and **Refresh browser source when scene becomes active** off.
3. Open **Tools → Scripts**, click **+**, and select `pulse-controls.lua` from this folder. Add it once. No extra plugin, Python installation, server, account, network connection, or WebSocket setup is needed by this companion.
4. Select the intended source in **PULSE Browser Source**. Nothing is selected automatically. Use **Refresh source list** if it was added later. The dropdown shows browser sources; remote-URL sources are refused when a command is attempted.
5. Click **Test: +1 selected meter**, **Test: -1 selected meter**, then **Test: reset selected meter**. Confirm that only the intended meter changes and ends at 0. “Dispatched” only means OBS accepted the procedure call; it is not a page acknowledgment.
6. In **Settings → Hotkeys**, search for **PULSE** and assign distinct combinations for increase, decrease and reset. No keys are assigned by the script. Prefer combinations with a modifier (for example Ctrl+Alt plus a key) that do not conflict with your other shortcuts. Avoid plain +, −, arrows or R: those already operate the HTML when its page is focused.
7. Close the overlay's **Interact** window and any captured control panel. With the main OBS window focused, test your three combinations and visually confirm the result. Make a short local recording before using the sample live.

## Limits and recovery

- **Page focus versus app focus:** the command path does not use the page's keyboard listener. Whether OBS receives your combination while another app is focused depends on OBS's **Hotkey Focus Behavior**, your operating system and its permissions. This package does not change those settings and does not promise universal global shortcuts. If background hotkeys fail, test with the main OBS window focused first.
- **One selected source:** selection uses a stable source UUID, so renaming it does not retarget the script. Deleting/recreating a source or changing scene collections can require selecting it again. If the same source is reused across several scenes, those appearances share its meter. No other scene or source properties are changed.
- **Showing is not “live on program”:** OBS considers previews/displays too. The script refuses a non-showing source and never queues/replays its commands. Showing does not prove the page finished loading; commands during loading, refresh or shutdown can be lost. Wait for the meter, then check visually before repeating a command.
- **No confirmation channel:** after a hotkey, open the script and click **Show last dispatch status** for diagnostics. A successful dispatch with no visible change usually means an old export, disabled checkbox, preview mode, or a page that was not ready. Re-export this version with the checkbox enabled and verify the selected source's Local file.
- **Current state remains in the HTML:** commands use the same bounded 0–5 logic, animations and local storage as page controls. OBS and your ordinary browser store separately. Lua does not keep a second counter. Browser-page reload and state recovery passed in this OBS environment; see the results for other reload/restart cases. Separate exports have separate instance IDs; reusing the same HTML is not a promise of independent stored state.
- **Remove cleanly:** remove this script from Tools → Scripts to unregister its hotkeys. The overlay and its current local state remain. To disable the page listener too, clear the optional checkbox in that source's Interact controls, or load a new export with the checkbox off. Close the panel afterward.

## Verification included

- 19 HTML source-level groups pass under Node VM with a minimal DOM/OBS-runtime substitute, including opt-in, fixed-event handling, invalid events, bounds, persistence and portable export
- 12 Lua mock groups pass using the Lua 5.1 / LuaJIT 2.1.1736781742 shared library included with OBS. They cover UUID routing, reference cleanup, repeat suppression, refusals and hotkey save/load/unload; OBS APIs remain mocked in these groups
- Windows OBS 32.2.2 core checks passed with the original script: real LuaJIT/OBS bindings, local-page rendering, UUID selection, all three test buttons, boundaries and repeated operations, invalid-target refusals, page opt-out, hidden-source refusal without replay, and browser-page reload with state recovery
- See [the real OBS results](../evidence/HISTORICAL_VALIDATION.md) for final evidence and all passed, failed and unrun items. `tests/browser-tests.cjs` was not run in this task. The user confirmed the focused physical-key sequence at 2026-10-08 13:44 UTC: Ctrl+Alt+F8 twice to 2, Ctrl+Alt+F9 to 1, Ctrl+Alt+F10 to 0. This is user-reported acceptance, not independent observation by the agent. Automated SendInput, long holds and background hotkeys remain unrun

For development only, run `node tests/source-tests.cjs` and `python -B tests/run-lua-tests.py` from the package root. The latter uses an existing Lua runtime/library; it does not install one. Alternatively run `lua tests/obs-controls-tests.lua` from the root with an existing Lua interpreter. These tools are not application dependencies.

On Windows, the optional `--library` argument can point to an existing OBS LuaJIT DLL; no environment-variable change is required. The runner searches only that DLL's parent directory for dependencies and reports missing files or load failures; it does not change the system PATH:

```powershell
python -B tests/run-lua-tests.py --library "<existing Lua shared library>"
```

## Official API references

Checked 2026-10-07. The browser-event bridge is verified from OBS's official implementation, rather than a documented cross-version extension contract.

- [OBS scripting and hotkey callbacks](https://docs.obsproject.com/scripting#obs_hotkey_register_frontend)
- [Source lookup by UUID, added in 29.1](https://docs.obsproject.com/reference-core#c.obs_get_source_by_uuid)
- [Source references, UUID and showing state](https://docs.obsproject.com/reference-sources)
- [Procedure handlers and calldata](https://docs.obsproject.com/reference-libobs-callback)
- [OBS's source-local javascript_event procedure](https://github.com/obsproject/obs-browser/blob/master/obs-browser-source.cpp)
- [OBS's CustomEvent delivery to window](https://github.com/obsproject/obs-browser/blob/master/browser-app.cpp)
- [Official Lua countdown hotkey persistence example](https://github.com/obsproject/obs-studio/blob/master/plugins/frontend-tools/data/scripts/countdown.lua)
- [OBS Hotkey Focus Behavior setting labels](https://github.com/obsproject/obs-studio/blob/master/frontend/data/locale/en-US.ini)
