# Mac Utils

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**Mac Utils** — a free, open-source macOS menu bar utility suite.

A lightweight menu bar app that puts nine powerful utilities at your fingertips: display brightness control, window snapping, clipboard history, paste formatting stripping, image optimisation, file hiding, OCR text capture, focus timer, and Quick Look extensions.

---

## Screenshots

*Screenshots coming soon*

---

## Requirements

- **macOS 12 Monterey** or later
- **Apple Silicon** or **Intel** Mac (universal binary)

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/MacUtils.git
   ```
2. Open `MacUtils/MacUtils.xcodeproj` in Xcode
3. Select the **MacUtils** scheme
4. Build and Run (⌘R)

The app will appear in your menu bar as a grid icon.

---

## Modules

| Module | Description |
|--------|-------------|
| **Lumens** | Control brightness and volume of external monitors via DDC/CI |
| **Tyle** | Snap windows to screen halves and quarters via keyboard shortcuts |
| **Unformat** | Intercept ⌘V system-wide and strip rich text formatting |
| **CtrlPaste** | Remember and recall your last 20 clipboard entries |
| **Shrink** | Losslessly optimise images by stripping all metadata |
| **Conceal** | Hide/unhide files and toggle Finder hidden file visibility |
| **Scan** | Capture and copy any text visible on screen using OCR |
| **Focus** | Pomodoro-style focus timer with session notes and history |
| **Glimpse** | Quick Look extension for code, markdown, CSV, ZIP, and more |

---

## Permissions

Mac Utils requires the following permissions to function:

| Permission | Why It's Needed |
|------------|-----------------|
| **Accessibility** | Window snapping (Tyle), paste interception (Unformat), keyboard shortcuts (Lumens F-keys), screen text capture (Scan) |
| **Screen Recording** | OCR text capture (Scan) — needs to read screen contents |
| **Automation (Apple Events)** | Restarting Finder when toggling hidden files (Conceal) |
| **Finder Extension** | Right-click context menus for image optimisation (Shrink) and file hiding (Conceal) |

All permissions are requested on first launch via an onboarding wizard. You can manage them in **System Settings → Privacy & Security**.

---

## Building from Source

### Core Logic Tests (Swift Package)

You can run the core logic tests without Xcode:

```bash
cd MacUtils
swift test
```

### Full App Build (Xcode)

1. Open `MacUtils.xcodeproj`
2. Select the **MacUtils** scheme
3. Product → Build (⌘B)
4. Product → Test (⌘U) for full test suite

---

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
