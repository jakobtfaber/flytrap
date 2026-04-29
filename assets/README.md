# Assets

Source artwork for app and menu-bar icons. Bundled resources at `Flytrap/Flytrap.icns`, `Flytrap/MenubarIcon.png`, and `Flytrap/MenubarIcon@2x.png` are derived from the masters here. They're added to the .app via the `Resources` build phase in `Flytrap.xcodeproj`.

| Master | Derived (bundled) | Used for |
|---|---|---|
| `assets/Flytrap.png` (1024×1024) | `Flytrap/Flytrap.icns` | App icon (Finder, Privacy panels) |
| `assets/Flytrap-Menubar.png` (black silhouette + alpha) | `Flytrap/MenubarIcon.png` (22pt) and `MenubarIcon@2x.png` (44pt) | Menu-bar status icon (template — auto-tinted by macOS) |

## Regenerating `Flytrap/Flytrap.icns`

If you update `assets/Flytrap.png` (must remain 1024×1024 PNG), regenerate the icns from the repo root:

```bash
ICONSET=/tmp/Flytrap.iconset
rm -rf "$ICONSET" && mkdir -p "$ICONSET"

sips -z 16   16   assets/Flytrap.png --out "$ICONSET/icon_16x16.png"      >/dev/null
sips -z 32   32   assets/Flytrap.png --out "$ICONSET/icon_16x16@2x.png"   >/dev/null
sips -z 32   32   assets/Flytrap.png --out "$ICONSET/icon_32x32.png"      >/dev/null
sips -z 64   64   assets/Flytrap.png --out "$ICONSET/icon_32x32@2x.png"   >/dev/null
sips -z 128  128  assets/Flytrap.png --out "$ICONSET/icon_128x128.png"    >/dev/null
sips -z 256  256  assets/Flytrap.png --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256  256  assets/Flytrap.png --out "$ICONSET/icon_256x256.png"    >/dev/null
sips -z 512  512  assets/Flytrap.png --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512  512  assets/Flytrap.png --out "$ICONSET/icon_512x512.png"    >/dev/null
cp assets/Flytrap.png "$ICONSET/icon_512x512@2x.png"

iconutil -c icns "$ICONSET" -o Flytrap/Flytrap.icns
rm -rf "$ICONSET"
```

Then rebuild and reinstall. To force Finder/Dock to drop their cached old icon:

```bash
killall Dock; killall Finder
```

## Regenerating `Flytrap/MenubarIcon.png` and `MenubarIcon@2x.png`

If you update `assets/Flytrap-Menubar.png` (should be a black silhouette on transparent background — macOS treats it as a template image and tints it for light/dark mode), regenerate from the repo root:

```bash
sips -Z 22 assets/Flytrap-Menubar.png --out Flytrap/MenubarIcon.png      >/dev/null
sips -Z 44 assets/Flytrap-Menubar.png --out 'Flytrap/MenubarIcon@2x.png' >/dev/null
```

`-Z` (capital) preserves aspect ratio. The 22pt height matches macOS's recommended menu-bar item size; macOS picks `@2x.png` automatically on Retina displays.

The Swift code that loads it is at `Flytrap/FlytrapApp.swift` in `applicationDidFinishLaunching`. It sets `isTemplate = true` and falls back to the SF Symbol `cpu` if the PNG is missing for any reason.
