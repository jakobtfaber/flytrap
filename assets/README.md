# Assets

Source artwork for the app icon. The .icns at `Flytrap/Flytrap.icns` is generated from `assets/Flytrap.png` and bundled into the .app via the `Resources` build phase in `Flytrap.xcodeproj`.

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
