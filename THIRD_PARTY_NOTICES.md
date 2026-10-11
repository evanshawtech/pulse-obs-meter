# Third-party scope

The distributed application uses inline HTML/CSS/JavaScript and browser/system fonts (Arial/Helvetica/sans-serif). No downloaded font, image, third-party package source, runtime binary or profile is included. The Lua companion and tests are project source. No third-party copyright or license declaration was found in the selected source; that inspection is not proof of sole ownership.

The following are external tools, not redistributed components:

- OBS Studio and obs-browser: optional runtime. The companion uses source UUIDs and the source-local JavaScript event procedure.
- Node.js: source checks use built-in assert/fs/path/vm.
- Python and an existing Lua/LuaJIT runtime: optional mocked-interface checks.
- Playwright and Chromium: optional future browser checks, not installed or included here.

Official API and implementation references used by the project are retained in [OBS-SETUP.md](obs/OBS-SETUP.md). The OBS countdown example is cited for API/persistence context. A reference link does not establish copying, and the public preparation does not grant a new license to third-party code.

Before a licensed release, the owner must confirm contribution rights and whether any source was adapted from protected third-party examples. If an adaptation requires attribution or incompatible terms, preserve its legitimate notice and resolve the conflict before publication.

Release preparation compared the Lua companion with the referenced official OBS countdown example (in OBS’s GPL-2.0 repository). No countdown implementation block was identified in this companion; the similarities were standard callback declarations and API usage. The example itself is not redistributed. API references retain their upstream identities.
