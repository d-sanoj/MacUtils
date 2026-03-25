# MacUtils

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

MacUtils is a lightweight macOS menu bar app that bundles a few everyday utilities into one place:

- `Focus` for quick Pomodoro-style focus sessions
- `Lumens` for external display brightness and volume control
- `CtrlPaste` for clipboard history
- `Unformat` for stripping rich-text formatting on paste
- `Scan` for OCR text capture from the screen

## Requirements

- macOS 13 or later
- Swift 5.9+ if building locally

## Install From GitHub Releases

If you just want to use the app, download the latest `.dmg` from [GitHub Releases](https://github.com/d-sanoj/MacUtils/releases).

1. Download the latest `MacUtils-*.dmg`
2. Open the DMG
3. Drag `MacUtils.app` into `/Applications`
4. Eject the DMG
5. Launch `MacUtils.app` from `/Applications`

Important:
- Do not run the app directly from the mounted DMG
- Launching from `/Applications` helps macOS keep permissions and relaunch behavior consistent

## Run Locally From Source

The Swift package for the app lives in the `MacUtils/` subdirectory.

```bash
git clone https://github.com/d-sanoj/MacUtils.git
cd MacUtils/MacUtils
swift run MacUtils
```

For a release build:

```bash
cd MacUtils/MacUtils
swift build -c release
```

To run the test suite:

```bash
cd MacUtils/MacUtils
swift test
```

## Permissions

MacUtils currently uses:

- `Accessibility` for global keyboard handling and paste interception
- `Screen Recording` for the `Scan` OCR workflow

The app guides you through permission setup on first launch. You can also re-check the current permission state from the app’s `Settings > Permissions` view.

## Resetting Permissions While Testing

If you uninstall the app, move it between locations, or test multiple builds, macOS can keep stale permission records.

1. Quit `MacUtils`
2. Remove the app copy you were testing
3. Reset the cached permissions in Terminal:

```bash
tccutil reset Accessibility com.macutils.app
tccutil reset ScreenCapture com.macutils.app
```

Then reinstall `MacUtils.app` into `/Applications` and launch it again.

If macOS still shows stale permission state, logging out or restarting macOS usually clears the remaining UI cache.

## Modules

| Module | What it does |
|--------|---------------|
| `Focus` | Starts focus/break sessions and keeps lightweight session history |
| `Lumens` | Controls external monitor brightness and volume, including media-key mapping |
| `CtrlPaste` | Stores recent clipboard entries for quick reuse |
| `Unformat` | Removes rich formatting when pasting plain text |
| `Scan` | Lets you capture screen text and copy it using OCR |

## Development Notes

- The repo ignores generated DMGs and local export output
- Release installers are intended to be distributed through GitHub Releases, not committed into the repo

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE).
