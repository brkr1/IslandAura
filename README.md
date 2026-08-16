# Island Aura

A jailbreak tweak that draws a customizable neon aura around the Dynamic Island — and keeps it locked to the island's real shape as it expands and collapses for calls, timers, media, Face ID, and anything else that uses it.

<img width="709" height="157" alt="image" src="https://github.com/user-attachments/assets/b3429b81-e3c8-4f27-8bd0-803ca4749030" />


## Features

- **Live-tracking** — the aura follows the Dynamic Island's actual on-screen size in real time, not a guessed/static shape. Works for any app or system feature that uses the island, not just media playback.
- **Three styles**
  - **Glow** — a bright, defined outline with a tight shadow.
  - **Pulse** — Glow's outline, breathing gently.
  - **Tint** — a soft color wash instead of a hard edge.
- **Any color**, via a full color picker.
- Settings apply instantly — no respring needed.

## Tested Environment

- iPhone 14 Pro Max (iPhone15,3)
- iOS 16.6.1
- roothide Bootstrap (rootless jailbreak)

Other devices and iOS versions are untested and not yet supported — see [What's next](#whats-next).

## Installation

Add this repo to Sileo/Zebra: https://brkr1.github.io/repo/

Or grab the latest `.deb` from [Releases](../../releases) and install manually.

## Settings

Open **Settings → Island Aura**:

- **Enabled** — on/off.
- **Style** — Glow, Pulse, or Tint.
- **Color** — any color, via the picker.

## What's next

- iOS 17/18 support.
- Possibly: context-aware coloring (different color depending on what's active — a call vs. Face ID vs. media, say).

## Building from source

Requires [Theos](https://theos.dev). CI builds with GitHub Actions on macOS (see `.github/workflows/build.yml`) using the real Xcode toolchain — arm64e builds need this specifically, since clang's class_ro pointer signing on arm64e isn't always read back correctly by libobjc, and can crash the injected process silently if built with the wrong toolchain.

```sh
make package THEOS_PACKAGE_SCHEME=rootless
```

## Support

If you like my tweaks, consider buying me a coffee:

<a href="https://buymeacoffee.com/brkr1" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" height="41" width="174"></a>

## Credits

The overall multi-process architecture behind Dynamic Island tweaks — and the arm64e ptrauth pitfall above — were learned from [NextUp3](https://github.com/Yves000/NextUp3) and [Crescendo](https://github.com/Yves000/Crescendo), both more mature tweaks doing related things. Color picker via [Alderis](https://github.com/hbang/Alderis).
