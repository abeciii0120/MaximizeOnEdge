# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MaximizeOnEdge is a macOS menu bar application written in Swift that automatically maximizes windows when dragged to screen edges. It's a single-file Swift application requiring macOS 13+ and uses accessibility permissions to manipulate window positions.

## Architecture

The application is entirely contained in `Sources/MaximizeOnEdge/main.swift`:
- **AppDelegate**: Main controller managing event tap, menu bar, preferences, and LaunchAgent
- **PreviewView**: Visual overlay (blue tint) shown when window enters snap zone
- **SettingsWindowController**: Preferences window for configuring edge thresholds and enabled edges
- **Event System**: Uses CGEventTap to monitor global mouse events (down/drag/up)
- **Window Manipulation**: Uses Accessibility API (AXUIElement) to get/set window positions and sizes

## Key Commands

### Build and Package
```bash
# Build release version and create .app bundle
./scripts/make_app_bundle.sh

# Create distributable zip with README (for end users)
./scripts/package_zip_with_readme.sh

# Build only (using Swift Package Manager)
swift build -c release

# Run debug version
swift build && swift run
```

### Development
```bash
# Clean build artifacts
swift package clean

# Build debug version
swift build

# Run directly from build output
.build/debug/MaximizeOnEdge
```

## Important Implementation Details

### Coordinate System Conversion
- **Critical**: Cocoa uses bottom-left origin, Accessibility API uses top-left
- Conversion handled in `maximizeWindow()` method - must convert between coordinate systems when setting window positions
- Screen detection uses `NSScreen.screens` to find correct display

### Accessibility Permissions
- App requires accessibility permissions via `AXIsProcessTrustedWithOptions`
- Permission prompt shown automatically on first launch
- Check status with `AXIsProcessTrusted()`

### Edge Detection Logic
- Configurable threshold (default 12px) stored in UserDefaults as `edgeThreshold`
- Each edge (top/left/right/bottom) can be individually enabled/disabled
- Detection happens during mouse drag events via CGEventTap

### LaunchAgent Management
- Auto-start uses LaunchAgent plist at `~/Library/LaunchAgents/dev.tabe.maximizeonedge.plist`
- Installation/removal handled by `installLaunchAgent()` and `removeLaunchAgent()` methods
- Bundle ID: `dev.tabe.maximizeonedge`

### Event Tap Details
- Monitors: `leftMouseDown`, `leftMouseDragged`, `leftMouseUp`
- Requires running on main thread
- Must be added to current run loop
- Automatically disabled when app loses accessibility permission

## Testing Considerations

When testing changes:
1. Grant accessibility permissions in System Settings > Privacy & Security > Accessibility
2. Test with multiple displays - coordinate conversion is critical
3. Verify LaunchAgent installation/uninstallation (`launchctl list | grep maximizeonedge`)
4. Check UserDefaults persistence: `defaults read dev.tabe.maximizeonedge`
5. Test all edge combinations and threshold values
6. Verify preview window appears/disappears correctly