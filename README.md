# FakeCrossover (MVP)

Minimal macOS SwiftUI app that manages Wine prefixes ("bottles") and runs Windows installers/apps.

Made by GUNNA-at.

## Runtime strategy
This MVP installs a downloadable Wine runtime into:
`~/Library/Application Support/FakeCrossover/Runtimes/`

You must provide a runtime archive (zip or tar.*) that contains `bin/wine` or `bin/wine64`.

## Requirements
- macOS 13+ (Ventura or newer)
- Apple Silicon (arm64) supported; Intel optional
- Xcode 15+
- Rosetta 2 may be required for some x86 helper tools

## Build
```bash
./scripts/build.sh
```

## Run
Open `FakeCrossover.xcodeproj` and run the app, or launch the built app:
```
build/Build/Products/Release/FakeCrossover.app
```

## Install runtime
1) Click **Install Runtime** in the sidebar.
2) Paste a runtime URL (zip or tar.*) or choose a local archive.
3) Watch **Task Logs** for download/extract/validate progress.

Tip: If you already have Wine installed locally and just need a runtime quickly:
```bash
WINE_BIN=$(realpath $(which wine))
WINE_ROOT=$(dirname "$WINE_BIN")/..
tar -czf WineRuntime.tar.gz -C "$WINE_ROOT" .
```
Then select `WineRuntime.tar.gz` in the app.

## Example workflow (Notepad++)
1) Click **New Bottle**, name it `Notepad++`, choose Windows 10, and create.
2) Click **Install...** and select the Notepad++ installer EXE.
3) After install, click **Refresh** to scan Program Files for EXEs.
4) Click **Run** next to the Notepad++ shortcut.

## Paths
- Bottles: `~/Library/Application Support/FakeCrossover/Bottles/<BottleID>/`
- Runtimes: `~/Library/Application Support/FakeCrossover/Runtimes/`
- Logs: `~/Library/Logs/FakeCrossover/`

## Licensing and compliance
- This app does not use or copy CodeWeavers CrossOver source code, branding, or assets.
- Wine is licensed under LGPL; review Wine licensing terms if you redistribute Wine binaries.

## Known MVP limitations
- Runtime archives must include a `bin/wine` or `bin/wine64` binary.
- Winetricks requires an external `winetricks` install in PATH.
- Shortcut scanning is a simple Program Files EXE scan and may include extra executables.
- DLL overrides and environment variables are stored as plain text in metadata.
- No built-in DXVK installer; set DXVK variables manually.
