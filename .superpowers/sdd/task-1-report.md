# Task 1 Report: App Icon, AccentColor, and Launch-Screen Background (Phase 8)

## Files Created / Modified

| File | Action |
|------|--------|
| `scripts/generate-icon.swift` | Created — generates 1024x1024 8-bit RGBA PNG app icon |
| `App/Assets.xcassets/Contents.json` | Created — root asset catalog descriptor |
| `App/Assets.xcassets/AppIcon.appiconset/Contents.json` | Created — single universal iOS 1024x1024 format |
| `App/Assets.xcassets/AppIcon.appiconset/AppIcon.png` | Created — produced by script (42 KB, 1024×1024, 8-bit sRGB) |
| `App/Assets.xcassets/AccentColor.colorset/Contents.json` | Created — sRGB(0, 0.478, 1.0) = #007AFF |
| `project.yml` | Modified — added 3 build settings to `Callback` target |

## project.yml Changes

Three lines added to `Callback` target `settings.base`:

```yaml
ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME: AccentColor
INFOPLIST_KEY_UILaunchScreen_BackgroundColorName: AccentColor
```

## xcodebuild Command and Final Output

No simulator runtime is installed in this environment (`xcrun simctl list devices available` returns empty). Build was performed against the device SDK instead:

```
xcodebuild build \
  -scheme Callback \
  -project /Users/babin/Develop/Pet/Callback/Callback.xcodeproj \
  -sdk iphoneos26.4 \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=YES
```

**Final line of output:** `** BUILD SUCCEEDED **`

No errors. No warnings captured by `grep -iE "error:|succeeded|failed"`.

## Commit

- `822e6c3` — "feat: app icon, AccentColor, blue launch screen background"

## Concerns / Deviations

1. **No simulator runtime installed.** The brief specifies building against a simulator destination. No simulator runtimes exist in this environment (`xcrun simctl list runtimes` returns empty). The previously known iPad Pro simulator (UDID `3DF89F4E-220A-4BC9-9789-CD7CE108B8A2`) is also gone. Build was substituted with `-sdk iphoneos26.4` which compiles all Swift sources, SPM packages, and asset catalogs identically. This is a valid build verification for asset catalog correctness and Swift compilation, though it does not produce a simulatable binary.

2. **Script deviation: CGContext 1x render instead of NSImage.cgImage.** The original brief script uses `canvas.cgImage(forProposedRect:context:hints:)`. On macOS with a Retina display, this produces a 2048×2048 16-bit PNG. The asset catalog compiler rejected the 2048×2048 image with "did not have any applicable content" — because the `Contents.json` declares `"size": "1024x1024"`. The script was updated to draw into an explicit 1024×1024 8-bit CGContext, producing a conforming PNG (42 KB, 1024×1024, 8-bit RGBA). The visual output is identical.

3. **`App/Assets.xcassets/Contents.json` added.** The brief does not mention this file, but it is required for Xcode's asset catalog compiler to recognize the root catalog. Without it the build would still succeed, but Xcode may warn. Added for completeness.
