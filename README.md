<div align="center">

# iTermate

**A native macOS companion panel for iTerm2 and Ghostty sessions.**

Keep windows, tabs, projects, shell commands, and coding-agent activity visible at a glance—without leaving your terminal.

[English](README.md) · [简体中文](README.zh-CN.md)

</div>

<p align="center">
  <a href="https://github.com/SSBun/iTermate/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/SSBun/iTermate?display_name=tag&amp;sort=semver&amp;style=flat-square"></a>
  <img alt="macOS 13.0 or later" src="https://img.shields.io/badge/macOS-13.0%2B-000000?style=flat-square&amp;logo=apple&amp;logoColor=white">
  <img alt="Apple Silicon" src="https://img.shields.io/badge/Apple%20Silicon-arm64-333333?style=flat-square&amp;logo=apple&amp;logoColor=white">
  <img alt="Swift 5" src="https://img.shields.io/badge/Swift-5.0-F05138?style=flat-square&amp;logo=swift&amp;logoColor=white">
</p>

<p align="center">
  <img src="docs/images/itermate-preview.webp" alt="iTermate showing grouped iTerm2 sessions and their activity status beside an iTerm2 window" width="100%">
</p>

## Overview

iTermate places a lightweight, resizable panel beside the frontmost iTerm2 or Ghostty window. It mirrors the terminal's Window → Tab → Session hierarchy, can regroup sessions by project directory, and shows whether shells and supported coding agents are running, finished, failed, or waiting for input.

A bundled Python Bridge reads iTerm2 through its official API, while Ghostty uses its official AppleScript interface. Session navigation and status updates stay on the Mac.

## Highlights

- **Always in context** — follows the frontmost iTerm2 or Ghostty window and hides when neither terminal is active.
- **Flexible organization** — group sessions by Window or Project Path, with collapsible Tab subgroups.
- **Direct session control** — focus or close a session, close an entire group, and resize the panel from either edge.
- **Project customization** — pin, favorite, and color-code project folders.
- **Live activity status** — distinguish shell commands from coding-agent work, including elapsed and completion time.
- **Configurable status visuals** — choose Alien, Robot, or Classic animations and colors for each state.
- **Native macOS features** — launch at login, completion notifications, menu-bar controls, appearance settings, and Sparkle updates.
- **Coding-agent integrations** — optional lifecycle reporting for [Pi](https://github.com/badlogic/pi-mono) and [Codex](https://github.com/openai/codex).
- **No Accessibility permission required** — iTermate follows iTerm2 without controlling the Mac through Accessibility APIs.

## Requirements

- macOS 13 Ventura or later
- Apple Silicon Mac (`arm64`) for the downloadable release
- [iTerm2](https://iterm2.com/) or [Ghostty](https://ghostty.org/) installed

> Ghostty activity icons require a build whose AppleScript Terminal exposes `tty`; Ghostty 1.3.1 does not expose this property.

## Installation

1. Download the latest DMG from [GitHub Releases](https://github.com/SSBun/iTermate/releases/latest).
2. Open the DMG and drag **iTermate** into **Applications**.
3. Start iTerm2 or Ghostty, then open iTermate.
4. Approve Automation access when macOS asks iTermate to communicate with the terminal.

> [!IMPORTANT]
> Current release builds are ad hoc signed and are **not notarized by Apple**. Verify the published `.sha256` file, then Control-click **iTermate.app** and choose **Open** if macOS blocks the first launch.

When iTerm2 is used, iTermate installs and manages its bundled Bridge in iTerm2's AutoLaunch scripts directory. No separate Python setup is required.

## Usage

### Navigate sessions

- Use the panel menu to switch between **Window** and **Project Path** grouping.
- Click a Session to activate its Tab and pane in iTerm2.
- Hover a Session to reveal its close button.
- Expand or collapse Window, Tab, and Project Path sections.
- Use a Project Path context menu to pin, favorite, or assign a custom color.

### Configure iTermate

Open the gear button in the panel or the iTermate menu-bar item to configure:

- whether the panel appears in iTerm2 and Ghostty independently;
- preferred left or right docking side;
- system, light, or dark panel appearance with blur or opaque backgrounds;
- accent color, font, and font size;
- Tab headers, project-title style, session times, and time format;
- completion notifications and launch at login;
- per-state status animation style and color.

### Enable coding-agent status

Open **Settings → Agents** and enable the integration you use:

- **Pi:** enable Pi, then run `/reload` in existing Pi sessions.
- **Codex:** enable Codex, then review and approve the new hooks with `/hooks`.

Pi and Codex are currently the supported agent integrations. For ordinary command status in Ghostty, enable the matching zsh, Bash, or fish toggle in the same settings and restart that shell; iTerm2 continues to observe shell activity through its Bridge.

## Troubleshooting

- **“Waiting for iTerm2 Bridge”** — make sure iTerm2 is running, allow iTermate under **System Settings → Privacy & Security → Automation**, then restart iTerm2 if needed.
- **Stale activity state** — use the refresh button in the panel header; it restarts only the Bridge and does not restart iTerm2 or its sessions.
- **Missing agent state** — confirm the integration is enabled in **Settings → Agents**, then reload or approve it as described above.

## Build from source

The Xcode project is checked in and resolves [Sparkle 2](https://github.com/sparkle-project/Sparkle) with Swift Package Manager.

```bash
git clone https://github.com/SSBun/iTermate.git
cd iTermate
open iTermate.xcodeproj
```

Select the **iTermate** scheme in Xcode and run it, or build from the command line:

```bash
xcodebuild -project iTermate.xcodeproj \
  -scheme iTermate \
  -configuration Debug \
  build
```

[`project.yml`](project.yml) is the source of truth for project settings. After changing it, regenerate the Xcode project with [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```bash
xcodegen generate
```

## Project structure

| Path | Responsibility |
| --- | --- |
| [`iTermate/`](iTermate/) | Native SwiftUI/AppKit app, floating panel, settings, notifications, and Bridge client |
| [`iTermateBridge/`](iTermateBridge/) | Bundled Python helper that reads and controls iTerm2 through its official API |
| [`integrations/`](integrations/) | Optional Pi and Codex lifecycle adapters |
| [`iTermateTests/`](iTermateTests/) | Tests for grouping, Bridge messages, integrations, layout, and notifications |
| [`docs/appcast.xml`](docs/appcast.xml) | Sparkle update feed |
| [`project.yml`](project.yml) | Canonical XcodeGen project configuration |

## Updates and releases

iTermate checks for updates with Sparkle. You can also choose **Settings → About → Check for Updates…** or visit [GitHub Releases](https://github.com/SSBun/iTermate/releases).

See [`CHANGELOG.md`](CHANGELOG.md) for release notes.
