import os, math
from PIL import Image, ImageDraw, ImageFont, ImageFilter

OUT_DIR = "/Users/adityadasamantharao/Documents/Repos/watchhive_mobile/app_store_screenshots"
RAW_DIR = os.path.join(OUT_DIR, "raw screens for appstore")

W, H = 3840, 1646

def draw_star(draw, cx, cy, r_outer=14, r_inner=6.5, fill="#FFB700", outline="#E59700"):
    points = []
    for i in range(10):
        angle = i * math.pi / 5 - math.pi / 2
        r = r_outer if i % 2 == 0 else r_inner
        points.append((cx + r * math.cos(angle), cy + r * math.sin(angle)))
    draw.polygon(points, fill=fill, outline=outline)

def frame_device(raw_path, pw, ph, corner_r=50, bezel=12, border_color="#3E3E42", border_w=5):
    raw = Image.open(raw_path).convert("RGBA")
    phone = Image.new("RGBA", (pw, ph), (0, 0, 0, 0))
    pdraw = ImageDraw.Draw(phone)
    pdraw.rounded_rectangle([0, 0, pw, ph], radius=corner_r, fill="#1C1C1E", outline=border_color, width=border_w)

    sw = pw - bezel * 2
    sh = ph - bezel * 2
    sr = corner_r - 8

    scaled = raw.resize((sw, sh), Image.Resampling.LANCZOS)
    mask = Image.new("L", (sw, sh), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, sw, sh], radius=sr, fill=255)
    phone.paste(scaled, (bezel, bezel), mask)

    # Dynamic Island
    iw, ih = int(pw * 0.22), 26
    ix = (pw - iw) // 2
    iy = bezel + 12
    pdraw.rounded_rectangle([ix, iy, ix + iw, iy + ih], radius=13, fill="#000000")

    return phone

def add_shadow(img, corner_r=50, blur=35, offset_y=24, alpha=65):
    w, h = img.size
    pad = blur * 2
    sh = Image.new("RGBA", (w + pad * 2, h + pad * 2), (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(sh)
    sdraw.rounded_rectangle([pad, pad, pad + w, pad + h], radius=corner_r, fill=(0, 0, 0, alpha))
    sh = sh.filter(ImageFilter.GaussianBlur(blur))
    
    # Composite img over shadow
    comp = Image.new("RGBA", (w + pad * 2, h + pad * 2 + offset_y), (0, 0, 0, 0))
    comp.alpha_composite(sh, (0, offset_y))
    comp.alpha_composite(img, (pad, pad))
    return comp, pad

def build_header_3840():
    # 1. Warm Cream Canvas #FFF9F0
    base = Image.new("RGBA", (W, H), (255, 249, 240, 255))
    draw = ImageDraw.Draw(base)

    # 2. Ambient Honey Radial Glow centered horizontally
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glow)
    # Center ambient glow
    gdraw.ellipse([W//2 - 1200, -400, W//2 + 1200, 1100], fill=(255, 183, 0, 48))
    gdraw.ellipse([W//2 - 700, 200, W//2 + 700, 1400], fill=(255, 218, 64, 35))
    base.alpha_composite(glow, (0, 0))
    draw = ImageDraw.Draw(base)

    # 3. Fonts
    font_bold = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
    font_reg = "/System/Library/Fonts/Supplemental/Arial.ttf"
    
    f_badge = ImageFont.truetype(font_bold, 36)
    f_title = ImageFont.truetype(font_bold, 86)
    f_sub = ImageFont.truetype(font_bold, 38)
    f_tag = ImageFont.truetype(font_bold, 30)

    # 4. Top Centered Branding & Text (All inside x=1000..2840 safe zone)
    # Badge Pill
    badge_text = "✦  WATCHERSHIVE  •  SOCIAL CINEMA TRACKER  ✦"
    bbox = draw.textbbox((0, 0), badge_text, font=f_badge)
    bw = bbox[2] - bbox[0] + 70
    bx = (W - bw) // 2
    by = 75
    draw.rounded_rectangle([bx, by, bx + bw, by + 68], radius=34, fill="#FFB700")
    draw.text((W // 2, by + 34), badge_text, fill="#262626", font=f_badge, anchor="mm")

    # Hero Title (Centered)
    draw.text((W // 2, 195), "Track, Discover & Connect", fill="#262626", font=f_title, anchor="mm")

    # Subtitle / 4 Pillars (Centered)
    sub_text = "Feed   •   Universal Entries   •   Global Search   •   Profile & Rankings"
    draw.text((W // 2, 275), sub_text, fill="#525252", font=f_sub, anchor="mm")

    # 5. Load and Frame the 4 Core Screens (+ Rankings Card)
    # Central Phone: FEED (Most Prominent)
    p_feed = frame_device(os.path.join(RAW_DIR, "feed.png"), pw=550, ph=1180, corner_r=52, border_color="#FFB700", border_w=6)
    c_feed, pad_feed = add_shadow(p_feed, corner_r=52, blur=45, offset_y=28, alpha=75)

    # Inner Left Phone: ENTRIES
    p_entries = frame_device(os.path.join(RAW_DIR, "entries.png"), pw=480, ph=1040, corner_r=46, border_color="#3E3E42", border_w=4)
    c_entries, pad_entries = add_shadow(p_entries, corner_r=46, blur=32, offset_y=22, alpha=60)

    # Far Left Phone: SEARCH
    p_search = frame_device(os.path.join(RAW_DIR, "search.png"), pw=430, ph=940, corner_r=42, border_color="#3E3E42", border_w=4)
    c_search, pad_search = add_shadow(p_search, corner_r=42, blur=28, offset_y=20, alpha=50)

    # Right Phone: PROFILE
    p_profile = frame_device(os.path.join(RAW_DIR, "profile.png"), pw=490, ph=1060, corner_r=46, border_color="#3E3E42", border_w=4)
    c_profile, pad_profile = add_shadow(p_profile, corner_r=46, blur=34, offset_y=24, alpha=60)

    # Floating Rankings Card over Profile
    raw_rank = Image.open(os.path.join(RAW_DIR, "rankings.png")).convert("RGBA")
    rcw, rch = 390, 520
    crop_rank = raw_rank.crop((70, 360, raw_rank.width - 70, 1450)).resize((rcw, rch), Image.Resampling.LANCZOS)
    card_rank = Image.new("RGBA", (rcw, rch), (0, 0, 0, 0))
    rmask = Image.new("L", (rcw, rch), 0)
    ImageDraw.Draw(rmask).rounded_rectangle([0, 0, rcw, rch], radius=32, fill=255)
    card_rank.paste(crop_rank, (0, 0), rmask)
    ImageDraw.Draw(card_rank).rounded_rectangle([0, 0, rcw, rch], radius=32, outline="#FFB700", width=5)
    c_rank, pad_rank = add_shadow(card_rank, corner_r=32, blur=26, offset_y=18, alpha=70)

    # 6. Symmetrical Positioning centered around X=1920
    # Center X coordinates for phones:
    # Search: 1040
    # Entries: 1440
    # Feed (Center Hero): 1920
    # Profile: 2400
    # Rankings Card: 2680
    
    # Layer 1: Search (Left background)
    sx = 1040 - c_search.width // 2
    sy = 450 - pad_search
    base.alpha_composite(c_search, (sx, sy))

    # Layer 2: Entries (Left midground)
    ex = 1450 - c_entries.width // 2
    ey = 410 - pad_entries
    base.alpha_composite(c_entries, (ex, ey))

    # Layer 3: Profile (Right midground)
    prx = 2400 - c_profile.width // 2
    pry = 410 - pad_profile
    base.alpha_composite(c_profile, (prx, pry))

    # Layer 4: Rankings Floating Card (Right foreground)
    rx = 2650 - c_rank.width // 2
    ry = 680 - pad_rank
    base.alpha_composite(c_rank, (rx, ry))

    # Layer 5: Feed (Center Foreground Hero)
    fx = W // 2 - c_feed.width // 2
    fy = 360 - pad_feed
    base.alpha_composite(c_feed, (fx, fy))

    # 7. Add Floating Indicator Tags above phones for clarity
    draw = ImageDraw.Draw(base)
    def draw_feature_tag(cx, cy, label):
        tbox = draw.textbbox((0, 0), label, font=f_tag)
        tw = tbox[2] - tbox[0] + 50
        th = 48
        tx = cx - tw // 2
        ty = cy - th // 2
        draw.rounded_rectangle([tx + 2, ty + 3, tx + tw + 2, ty + th + 3], radius=24, fill=(0, 0, 0, 40))
        draw.rounded_rectangle([tx, ty, tx + tw, ty + th], radius=24, fill="#FFFFFF", outline="#FFB700", width=2)
        draw.text((cx, cy), label, fill="#262626", font=f_tag, anchor="mm")

    draw_feature_tag(1040, 395, "Search")
    draw_feature_tag(1450, 355, "Entries")
    draw_feature_tag(W // 2, 310, "Community Feed")
    draw_feature_tag(2400, 355, "Profile")
    draw_feature_tag(2650, 630, "Rankings & Stacks")

    # 8. Save 3840 x 1646
    out_3840 = os.path.join(OUT_DIR, "header_asset_3840x1646.png")
    rgb_3840 = base.convert("RGB")
    rgb_3840.save(out_3840, quality=96)
    print(f"Generated Header Asset: {out_3840} (3840x1646)")

    # 9. Generate 5244 x 2950 (Proportional scale with background continuation)
    out_5244 = os.path.join(OUT_DIR, "header_asset_5244x2950.png")
    base_5244 = Image.new("RGBA", (5244, 2950), (255, 249, 240, 255))
    # Ambient glow on 5244 canvas
    glow_5244 = Image.new("RGBA", (5244, 2950), (0, 0, 0, 0))
    gdraw_5244 = ImageDraw.Draw(glow_5244)
    gdraw_5244.ellipse([5244//2 - 1600, -500, 5244//2 + 1600, 1800], fill=(255, 183, 0, 48))
    base_5244.alpha_composite(glow_5244, (0, 0))
    
    # Scale 3840 content to fit 5244 canvas centered
    scaled_w = 5244
    scaled_h = int(5244 * (H / W))
    scaled_img = base.resize((scaled_w, scaled_h), Image.Resampling.LANCZOS)
    y_pos = (2950 - scaled_h) // 2
    base_5244.paste(scaled_img, (0, y_pos), scaled_img)
    base_5244.convert("RGB").save(out_5244, quality=96)
    print(f"Generated Header Asset: {out_5244} (5244x2950)")

build_header_3840()
