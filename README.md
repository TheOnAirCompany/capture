<p align="center">
  <img src="Design/icon-256.png" width="128" height="128" alt="Capture icon">
</p>

<h1 align="center">Capture</h1>

<p align="center">
  Clean iPhone screenshots and screen recordings, straight from your Mac.<br>
  The 9:41 status bar Apple uses in its own product shots, without the QuickTime hassle.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-26%2B-black" alt="macOS 26+">
  <img src="https://img.shields.io/badge/Swift-6-orange" alt="Swift 6">
  <img src="https://img.shields.io/badge/license-MIT-blue" alt="MIT License">
</p>

---

## Why Capture?

When a Mac opens the screen of a USB-connected iPhone (the way QuickTime Player's *New Movie Recording* does), iOS switches to a **demo status bar**: 9:41, full battery, full signal and no notifications. It's perfect for App Store screenshots, marketing visuals and product demos, but QuickTime is not built for that workflow.

Capture is a small, native macOS app designed around it: plug in your iPhone, take a screenshot or record a video, and find everything in one place.

## Features

- [x] Guided onboarding (English and French)
- [x] Automatic iPhone detection over USB
- [x] Live preview that fits the window
- [ ] Screenshots at full native resolution
- [ ] Screen recordings with sound
- [ ] Recent captures library
- [ ] Device frames (bezels) added when editing
- [ ] Signed and notarized DMG

## Requirements

- macOS 26 or later
- An iPhone connected **with a USB cable** (the demo status bar is not available over Wi-Fi)
- Camera access: macOS exposes the iPhone screen as a camera device, so Capture asks for it on first launch. Nothing leaves your Mac.

## How it works

iOS devices are hidden from AVFoundation until an app opts in through CoreMediaIO:

```swift
var address = CMIOObjectPropertyAddress(
    mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyAllowScreenCaptureDevices),
    mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
    mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
)
var allow: UInt32 = 1
CMIOObjectSetPropertyData(CMIOObjectID(kCMIOObjectSystemObject), &address, 0, nil,
                          UInt32(MemoryLayout.size(ofValue: allow)), &allow)
```

The iPhone then shows up as an external `AVCaptureDevice` with the `.muxed` media type. As soon as a capture session starts streaming from it, iOS switches its status bar to demo mode.

## Building

1. Install Xcode 26 or later.
2. Clone the repository and open `Capture.xcodeproj`.
3. Build and run the **Capture** scheme.

The project is signed to run locally by default. Pick your own team in *Signing & Capabilities* if you want to sign with your Developer ID.

The Xcode project is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen). After adding or removing files, run:

```sh
xcodegen generate
```

## Project structure

```
Capture/
├── App/            App entry point
├── Device/         iPhone discovery, capture session and live preview
├── Main/           Main window: sidebar, empty state, preview
├── Onboarding/     First-launch walkthrough
└── Resources/      Assets and string catalogs (en, fr)
scripts/
├── make-icons.swift  Generates the AppIcon set from Design/AppIcon.png
└── strings.py        Regenerates the string catalogs with French translations
```

## Localization

Capture ships in English and French. Strings live in `Capture/Resources/Localizable.xcstrings`. French translations are maintained in `scripts/strings.py`: edit them there, then run `python3 scripts/strings.py`.

## Contributing

Issues and pull requests are welcome. Please keep the app native, minimal and in line with Apple's Human Interface Guidelines.

## License

Capture is released under the [MIT License](LICENSE).

iPhone, Mac, macOS and QuickTime are trademarks of Apple Inc. This project is not affiliated with or endorsed by Apple.
