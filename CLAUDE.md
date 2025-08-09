# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MaximizeOnEdge is a macOS menu bar application written in Swift that automatically maximizes windows when dragged to screen edges. It requires macOS 13+ and uses accessibility permissions to manipulate window positions.

## Architecture

The application consists of:
- **main.swift**: Single-file Swift application containing all logic
  - `AppDelegate`: Main application controller managing event tap, preferences, and LaunchAgent
  - `PreviewView`: Visual preview overlay shown when window is in snap zone
  - `SettingsWindowController`: Preferences window for edge thresholds and enabled edges
- **Event Monitoring**: Uses CGEventTap to monitor global mouse events (down/drag/up)
- **Window Manipulation**: Uses Accessibility API (AXUIElement) to resize/reposition windows

## Key Commands

### Build and Package
```bash
# Build release version and create .app bundle
./scripts/make_app_bundle.sh

# Create distributable zip with README
./scripts/package_zip_with_readme.sh

# Build only (using Swift Package Manager)
swift build -c release
```

### Development
```bash
# Build and run debug version
swift build
swift run

# Clean build artifacts
swift package clean
```

## Important Implementation Details

- **Coordinate Systems**: Cocoa uses bottom-left origin while Accessibility API uses top-left. Conversions are handled in `maximizeWindow()` method.
- **Permissions**: Requires accessibility permissions - handled with `AXIsProcessTrustedWithOptions`
- **LaunchAgent**: Auto-start functionality uses LaunchAgent plist in `~/Library/LaunchAgents/`
- **Edge Detection**: Configurable threshold (default 12px) for detecting when cursor is near screen edge
- **Multi-monitor**: Uses `NSScreen.screens` to find correct screen and handle coordinate conversions

## Testing Considerations

When testing changes:
1. Ensure accessibility permissions are granted in System Settings
2. Test with multiple displays if available
3. Verify LaunchAgent installation/uninstallation works correctly
4. Check that preferences persist across app restarts