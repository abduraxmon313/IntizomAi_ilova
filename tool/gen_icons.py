"""IntizomAI ikonka manbalarini assets/images/logo.png dan yaratadi.

Ishga tushirish (Pillow + numpy kerak):
    python3 tool/gen_icons.py
Keyin launcher ikonkalarini yaratish:
    dart run flutter_launcher_icons

Chiqadi (assets/icon/):
  icon.png        1024  — to'liq (opaque) ikonka: och fon + belgi (iOS + legacy Android)
  foreground.png  1024  — adaptiv foreground: belgi shaffof fonda (xavfsiz zona ichida)
  background.png  1024  — adaptiv background: och gradient
  monochrome.png  1024  — Android 13+ mavzuli ikonka: oq siluet

Va to'g'ridan-to'g'ri android drawable-* ga bildirishnoma ikonkasi (oq siluet):
  ic_stat_notification.png  24/36/48/72/96
"""
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets/images/logo.png")
OUT = os.path.join(ROOT, "assets/icon")
os.makedirs(OUT, exist_ok=True)

# Och fon ranglari (logo plitkasidan olingan, toza gradient)
BG_TOP = (247, 249, 253)
BG_BOT = (231, 237, 247)


def load_mark():
    """logo.png dan belgini (ko'k M/sparkle/dot) ajratib, tight RGBA qaytaradi."""
    im = Image.open(SRC).convert("RGBA")
    a = np.asarray(im).astype(np.float32)
    R, G, B, A = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    H, W = A.shape
    # "Ko'klik" = B - R. Belgi to'yingan ko'k (B>>R); fon oq (B≈R);
    # plitka chegarasi/soyasi — xira. Yuqori ostona bilan faqat kuchli belgi qoladi.
    d = B - R
    alpha = np.clip((d - 60.0) / (130.0 - 60.0), 0.0, 1.0)
    alpha = np.where(B > 120, alpha, 0.0)
    alpha = np.where(A > 128, alpha, 0.0)
    # Chekka ramka (plitka chegarasi) — butunlay o'chiramiz.
    m = int(round(min(H, W) * 0.08))
    frame = np.ones((H, W), np.float32)
    frame[:m, :] = 0
    frame[-m:, :] = 0
    frame[:, :m] = 0
    frame[:, -m:] = 0
    alpha = alpha * frame

    ys, xs = np.where(alpha > 0.5)
    x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
    pad = 6
    x0, y0 = max(0, x0 - pad), max(0, y0 - pad)
    x1, y1 = min(W - 1, x1 + pad), min(H - 1, y1 + pad)
    rgb = a[..., :3].astype(np.uint8)
    out = np.dstack([rgb, (alpha * 255).astype(np.uint8)])
    return Image.fromarray(out[y0:y1 + 1, x0:x1 + 1], "RGBA")


def grad_bg(size):
    top = np.array(BG_TOP, np.float32)
    bot = np.array(BG_BOT, np.float32)
    t = np.linspace(0, 1, size).reshape(size, 1, 1)
    arr = (top * (1 - t) + bot * t).astype(np.uint8)
    arr = np.repeat(arr, size, axis=1)
    rgba = np.dstack([arr, np.full((size, size), 255, np.uint8)])
    return Image.fromarray(rgba, "RGBA")


def place(mark, canvas_size, frac, bg=None, dy=0):
    canvas = bg.copy() if bg is not None else Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    mw, mh = mark.size
    scale = (frac * canvas_size) / max(mw, mh)
    nw, nh = max(1, round(mw * scale)), max(1, round(mh * scale))
    m = mark.resize((nw, nh), Image.LANCZOS)
    canvas.alpha_composite(m, ((canvas_size - nw) // 2, (canvas_size - nh) // 2 + dy))
    return canvas


def white_silhouette(mark):
    a = np.asarray(mark).astype(np.uint8).copy()
    a[..., 0] = 255
    a[..., 1] = 255
    a[..., 2] = 255
    return Image.fromarray(a, "RGBA")


def main():
    mark = load_mark()
    print("mark size:", mark.size)
    S = 1024
    bg = grad_bg(S)

    # icon.png — iOS/legacy, to'g'ridan-to'g'ri ishlatiladi (0.70).
    # foreground/monochrome — flutter_launcher_icons ustiga 16% inset qo'shadi,
    # shuning uchun to'laroq (0.82) olamiz → inset'dan keyin xavfsiz zonaga tushadi.
    place(mark, S, 0.70, bg=bg, dy=-int(S * 0.01)).convert("RGB").save(f"{OUT}/icon.png")
    place(mark, S, 0.82, dy=-int(S * 0.01)).save(f"{OUT}/foreground.png")
    bg.convert("RGB").save(f"{OUT}/background.png")
    place(white_silhouette(mark), S, 0.82, dy=-int(S * 0.01)).save(f"{OUT}/monochrome.png")

    sil = white_silhouette(mark)
    for d, px in {"mdpi": 24, "hdpi": 36, "xhdpi": 48, "xxhdpi": 72, "xxxhdpi": 96}.items():
        canvas = Image.new("RGBA", (px, px), (0, 0, 0, 0))
        inner = px - 2 * round(px * 0.08)
        mw, mh = sil.size
        scale = inner / max(mw, mh)
        nw, nh = max(1, round(mw * scale)), max(1, round(mh * scale))
        m = sil.resize((nw, nh), Image.LANCZOS)
        canvas.alpha_composite(m, ((px - nw) // 2, (px - nh) // 2))
        ddir = os.path.join(ROOT, f"android/app/src/main/res/drawable-{d}")
        os.makedirs(ddir, exist_ok=True)
        canvas.save(f"{ddir}/ic_stat_notification.png")
    print("done")


if __name__ == "__main__":
    main()
