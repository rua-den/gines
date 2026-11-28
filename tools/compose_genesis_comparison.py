"""Pair full, unedited Godot viewport captures under matching labels."""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

root = Path(sys.argv[1])
scenes = [("menu", "01  MENU"), ("map01", "02  MAP 01 / SPAWN"), ("bloom", "03  MAP 03 / BLOOM + EVOLUTION")]
font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 22)
meta = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 17)
for key, caption in scenes:
    originals = [Image.open(root / f"{version}-{key}.png").convert("RGB") for version in ("before", "after")]
    a, b = originals
    assert a.size == b.size, (key, a.size, b.size)
    w, h = a.size
    out = Image.new("RGB", (w * 2 + 34, h + 88), "#101720")
    draw = ImageDraw.Draw(out)
    draw.text((10, 6), caption, font=font, fill="#ffffff")
    for i, (label, revision) in enumerate([("TRƯỚC", "e33a7b8"), ("SAU", "db4ba12")]):
        x = 10 if i == 0 else w + 24
        draw.text((x, 38), f"{label}  ·  {revision}", font=meta, fill="#86ebd7")
        out.paste(originals[i], (x, 66))
    draw.text((10, h + 68), "Godot 4.7.2 · Cùng cảnh, camera và độ phân giải", font=meta, fill="#c8d5dc")
    out.save(root / f"compare-{key}.png", optimize=True)
