#!/usr/bin/env python3
"""
Imports the onboarding illustrations into Assets.xcassets as tintable template images.

Source art arrives trimmed to its bounding box at ~400-530 px. This pads each one back to a
square canvas with the margin the design spec asks for, then writes 1x/2x/3x slots plus a
Contents.json marked `template-rendering-intent`.

Template rendering means iOS uses only the alpha channel and paints it with whatever
`foregroundStyle` the call site sets — so the art follows `primaryColor` and adapts to dark mode
for free. That is what let `DarkModeColorInvert.swift` be deleted instead of carried forward.

NOTE: this is the *fallback* path. These sources are ~500 px, and a hero renders ~250 pt, so the
3x slot is being upscaled and will be slightly soft. The real fix is tracing to PDF with
Preserve Vector Data — see docs/onboarding-asset-prompts.md §3. Re-run this, or replace with
PDFs, once a tracer is available.

    python3 scripts/import-onboarding-assets.py ~/Downloads/separated_transparent_pngs
"""
import json, os, sys

try:
    from PIL import Image
except ImportError:
    sys.exit("needs Pillow:  pip3 install --user Pillow")

CATALOG = os.path.join(os.path.dirname(__file__), "..", "PPTAMinimal", "Assets.xcassets")

# source filename -> asset name. `onb-the-loop` is deliberately absent: the generated version
# drifted to a "secure device sync" concept and was rejected. YourRulesView falls back to an SF
# Symbol until it lands, so a missing entry here is not a broken build.
MAPPING = {
    "01_key_access.png":      "onb-the-key",
    "02_select_option.png":   "onb-pick-apps",
    "04_helping_hand.png":    "onb-find-coach",
    "05_pending_message.png": "onb-waiting",
}

SUBJECT_FRACTION = 0.78   # leaves ~11% clear margin per side
BASE_3X = 1024


def square_with_margin(im):
    """Crop to actual ink, then centre it on a square canvas at the spec margin."""
    bbox = im.getbbox()
    if bbox:
        im = im.crop(bbox)
    side = int(max(im.size) / SUBJECT_FRACTION)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(im, ((side - im.width) // 2, (side - im.height) // 2), im)
    return canvas


def write_imageset(name, source):
    folder = os.path.join(CATALOG, f"{name}.imageset")
    os.makedirs(folder, exist_ok=True)

    # Clear stale files so a re-run never leaves an orphaned slot behind.
    for existing in os.listdir(folder):
        os.remove(os.path.join(folder, existing))

    padded = square_with_margin(Image.open(source).convert("RGBA"))
    images = []
    for scale, side in (("1x", BASE_3X // 3), ("2x", BASE_3X * 2 // 3), ("3x", BASE_3X)):
        filename = f"{name}@{scale}.png"
        padded.resize((side, side), Image.LANCZOS).save(os.path.join(folder, filename))
        images.append({"filename": filename, "idiom": "universal", "scale": scale})

    with open(os.path.join(folder, "Contents.json"), "w") as handle:
        json.dump({
            "images": images,
            "info": {"author": "xcode", "version": 1},
            "properties": {"template-rendering-intent": "template"},
        }, handle, indent=2)

    return padded.size[0]


def main(folder):
    if not os.path.isdir(folder):
        sys.exit(f"not a directory: {folder}")
    done = 0
    for filename, name in MAPPING.items():
        source = os.path.join(folder, filename)
        if not os.path.exists(source):
            print(f"  skip  {filename} (not found)")
            continue
        side = write_imageset(name, source)
        print(f"  ok    {filename}  ->  {name}.imageset   ({side}px padded, 1x/2x/3x, template)")
        done += 1
    print(f"\n{done}/{len(MAPPING)} imported into Assets.xcassets")
    print("Pending: onb-the-loop (regenerate — see asset prompts §1 prompt 3)")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~/Downloads/separated_transparent_pngs"))
