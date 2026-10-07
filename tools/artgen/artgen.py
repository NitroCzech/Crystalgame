#!/usr/bin/env python3
"""Generate game art with the OpenAI Images API and install the picked one.

    python3 tools/artgen/artgen.py generate crystal "a glowing violet crystal"
    python3 tools/artgen/artgen.py pick <round folder> 2

`generate` makes 3 options for a slot and a numbered preview sheet.
Run it again with the same prompt to retry. `pick` copies the chosen option
into assets/art/<slot>.png, which the game loads automatically
(see scripts/art.gd).

Needs OPENAI_API_KEY in the environment. Standard library only; Pillow is
used for the preview sheet and resizing when it is installed.
"""

import argparse
import base64
import json
import os
import shutil
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
ART_DIR = REPO / "assets" / "art"
DEFAULT_OUT = Path("/mnt/project-files/art/candidates")
API_URL = os.environ.get("OPENAI_BASE_URL", "https://api.openai.com/v1") + "/images/generations"

STYLE = (
    "Polished 2D mobile idle game art, vibrant saturated colors, soft glow, "
    "clean shapes that read well at small sizes. No text, no letters, no watermark."
)
SPRITE = "A single centered object filling most of the frame, on a fully transparent background."

RARITY_SLOTS = ["common", "uncommon", "rare", "epic", "legendary", "mythic", "celestial"]

# slot -> (size sent to the API, final size in the game, extra prompt text, transparent?)
SLOTS = {
    "crystal": ("1024x1024", (512, 512), SPRITE, True),
    "background": ("1024x1536", (720, 1280),
                   "Portrait phone game background, dark and calm in the middle so "
                   "white text and a crystal stay readable on top of it.", False),
}
for _r in RARITY_SLOTS:
    SLOTS["gem_" + _r] = ("1024x1024", (512, 512), SPRITE, True)


def _pil():
    try:
        from PIL import Image, ImageDraw
        return Image, ImageDraw
    except ImportError:
        return None, None


def generate(slot: str, prompt: str, out_root: Path, count: int, model: str) -> Path:
    key = os.environ.get("OPENAI_API_KEY")
    if not key:
        sys.exit("OPENAI_API_KEY is not set.")
    size, _, extra, transparent = SLOTS[slot]
    body = {
        "model": model,
        "prompt": f"{prompt}\n\n{extra}\n{STYLE}",
        "n": count,
        "size": size,
        "output_format": "png",
    }
    if transparent:
        body["background"] = "transparent"
    req = urllib.request.Request(
        API_URL,
        data=json.dumps(body).encode(),
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=300) as resp:
            data = json.load(resp)
    except urllib.error.HTTPError as e:
        sys.exit(f"OpenAI API error {e.code}: {e.read().decode(errors='replace')}")

    round_dir = out_root / slot / time.strftime("%Y%m%d-%H%M%S")
    round_dir.mkdir(parents=True, exist_ok=True)
    files = []
    for i, item in enumerate(data["data"], start=1):
        path = round_dir / f"option-{i}.png"
        path.write_bytes(base64.b64decode(item["b64_json"]))
        files.append(path)
    (round_dir / "round.json").write_text(json.dumps(
        {"slot": slot, "prompt": prompt, "model": model, "size": size,
         "options": [p.name for p in files]}, indent=2))
    sheet = make_sheet(files, round_dir / "preview.png")
    print(round_dir)
    if sheet:
        print(sheet)
    return round_dir


def make_sheet(files, dest: Path):
    """Side-by-side preview with big 1/2/3 labels, on a checkerboard so
    transparency shows."""
    Image, ImageDraw = _pil()
    if not Image or not files:
        return None
    thumbs = [Image.open(p).convert("RGBA") for p in files]
    h = 512
    thumbs = [t.resize((round(t.width * h / t.height), h)) for t in thumbs]
    gap = 24
    width = sum(t.width for t in thumbs) + gap * (len(thumbs) + 1)
    sheet = Image.new("RGBA", (width, h + 2 * gap + 72), "#140c2a")
    draw = ImageDraw.Draw(sheet)
    x = gap
    for n, t in enumerate(thumbs, start=1):
        for cy in range(0, h, 32):
            for cx in range(0, t.width, 32):
                shade = "#2a2050" if (cx + cy) // 32 % 2 else "#221a42"
                draw.rectangle([x + cx, gap + cy, x + cx + 31, gap + cy + 31], fill=shade)
        sheet.alpha_composite(t, (x, gap))
        draw.text((x + t.width // 2, gap + h + 36), str(n), fill="white",
                  anchor="mm", font_size=56)
        x += t.width + gap
    sheet.convert("RGB").save(dest)
    return dest


def pick(round_dir: Path, choice: int) -> Path:
    meta = json.loads((round_dir / "round.json").read_text())
    slot = meta["slot"]
    src = round_dir / f"option-{choice}.png"
    if not src.exists():
        sys.exit(f"No option {choice} in {round_dir}")
    ART_DIR.mkdir(parents=True, exist_ok=True)
    dest = ART_DIR / f"{slot}.png"
    final_size = SLOTS[slot][1]
    Image, _ = _pil()
    if Image:
        img = Image.open(src).convert("RGBA")
        # Scale to cover the target, then center-crop.
        scale = max(final_size[0] / img.width, final_size[1] / img.height)
        img = img.resize((round(img.width * scale), round(img.height * scale)), Image.LANCZOS)
        left = (img.width - final_size[0]) // 2
        top = (img.height - final_size[1]) // 2
        img.crop((left, top, left + final_size[0], top + final_size[1])).save(dest, optimize=True)
    else:
        shutil.copyfile(src, dest)
    (round_dir / "picked.json").write_text(json.dumps({"option": choice, "installed": str(dest)}))
    print(dest)
    return dest


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="cmd", required=True)
    g = sub.add_parser("generate", help="make options for a slot")
    g.add_argument("slot", choices=sorted(SLOTS))
    g.add_argument("prompt")
    g.add_argument("--count", type=int, default=3)
    g.add_argument("--out", type=Path, default=DEFAULT_OUT)
    g.add_argument("--model", default=os.environ.get("OPENAI_IMAGE_MODEL", "gpt-image-1"))
    p = sub.add_parser("pick", help="install an option into the game")
    p.add_argument("round_dir", type=Path)
    p.add_argument("option", type=int)
    sub.add_parser("slots", help="list art slots")
    args = parser.parse_args()

    if args.cmd == "generate":
        generate(args.slot, args.prompt, args.out, args.count, args.model)
    elif args.cmd == "pick":
        pick(args.round_dir, args.option)
    else:
        for name, (_, final, _, transparent) in sorted(SLOTS.items()):
            print(f"{name:16} {final[0]}x{final[1]}{'  transparent' if transparent else ''}")


if __name__ == "__main__":
    main()
