import os, math
from PIL import Image, ImageDraw, ImageFont, ImageFilter

W, H = 1290, 2796
RAW_DIR = "/Users/adityadasamantharao/Documents/Repos/watchhive_mobile/app_store_screenshots/raw screens for appstore"
OUT_DIR = "/Users/adityadasamantharao/Documents/Repos/watchhive_mobile/app_store_screenshots"
OUT_65_DIR = os.path.join(OUT_DIR, "6.5_inch")

os.makedirs(OUT_DIR, exist_ok=True)
os.makedirs(OUT_65_DIR, exist_ok=True)

# System fonts
font_bold = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
font_reg = "/System/Library/Fonts/Supplemental/Arial.ttf"

f_badge = ImageFont.truetype(font_bold, 30)
f_title = ImageFont.truetype(font_bold, 68)
f_sub = ImageFont.truetype(font_reg, 34)
f_callout = ImageFont.truetype(font_bold, 26)

def draw_star(draw, cx, cy, r_outer=12, r_inner=5.5, fill="#FFB700", outline="#E59700"):
    points = []
    for i in range(10):
        angle = i * math.pi / 5 - math.pi / 2
        r = r_outer if i % 2 == 0 else r_inner
        points.append((cx + r * math.cos(angle), cy + r * math.sin(angle)))
    draw.polygon(points, fill=fill, outline=outline)

def create_base_canvas(badge_text, title_text, line1, line2):
    base = Image.new("RGBA", (W, H), (255, 249, 240, 255)) # AppColors.background #FFF9F0
    draw = ImageDraw.Draw(base)

    # Ambient Honey Glow at top
    glow = Image.new("RGBA", (W, 850), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glow)
    gdraw.ellipse([-300, -420, W + 300, 480], fill=(255, 183, 0, 42))
    base.alpha_composite(glow, (0, 0))
    draw = ImageDraw.Draw(base)

    # Category Pill
    badge_bbox = draw.textbbox((0, 0), badge_text, font=f_badge)
    badge_text_w = badge_bbox[2] - badge_bbox[0]
    badge_w = badge_text_w + 56
    badge_h = 60
    badge_x = (W - badge_w) // 2
    badge_y = 110
    draw.rounded_rectangle([badge_x, badge_y, badge_x + badge_w, badge_y + badge_h], radius=30, fill="#FFB700")
    draw.text((W // 2, badge_y + 30), badge_text, fill="#262626", font=f_badge, anchor="mm")

    # Title & Subtitles
    draw.text((W // 2, 230), title_text, fill="#262626", font=f_title, anchor="mm")
    draw.text((W // 2, 315), line1, fill="#525252", font=f_sub, anchor="mm")
    draw.text((W // 2, 365), line2, fill="#737373", font=f_sub, anchor="mm")

    return base

def frame_screenshot(raw_img_path, pw=920, ph=2020, corner_r=70, bezel=14):
    raw = Image.open(raw_img_path).convert("RGBA")
    
    phone = Image.new("RGBA", (pw, ph), (0, 0, 0, 0))
    pdraw = ImageDraw.Draw(phone)
    pdraw.rounded_rectangle([0, 0, pw, ph], radius=corner_r, fill="#1C1C1E", outline="#3E3E42", width=6)

    sw = pw - bezel * 2
    sh = ph - bezel * 2
    sr = corner_r - 10

    scaled_screen = raw.resize((sw, sh), Image.Resampling.LANCZOS)
    screen_mask = Image.new("L", (sw, sh), 0)
    ImageDraw.Draw(screen_mask).rounded_rectangle([0, 0, sw, sh], radius=sr, fill=255)
    phone.paste(scaled_screen, (bezel, bezel), screen_mask)

    # Dynamic Island
    island_w, island_h = 200, 54
    island_x = (pw - island_w) // 2
    island_y = bezel + 20
    pdraw.rounded_rectangle([island_x, island_y, island_x + island_w, island_y + island_h], radius=27, fill="#000000")

    return phone

def composite_phone_with_shadow(base, phone, px, py, pw=920, ph=2020, corner_r=70):
    shadow_pad = 60
    shadow = Image.new("RGBA", (pw + shadow_pad * 2, ph + shadow_pad * 2), (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(shadow)
    sdraw.rounded_rectangle(
        [shadow_pad, shadow_pad, pw + shadow_pad, ph + shadow_pad],
        radius=corner_r,
        fill=(0, 0, 0, 50)
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(36))
    base.alpha_composite(shadow, (px - shadow_pad, py - shadow_pad + 24))
    base.alpha_composite(phone, (px, py))

def draw_callout_pill(draw, text, side="left", y_pos=800):
    bbox = draw.textbbox((0, 0), text, font=f_callout)
    text_w = bbox[2] - bbox[0]
    text_h = bbox[3] - bbox[1]

    icon_size = 26
    pad_h = 22
    pill_w = text_w + icon_size + pad_h * 2 + 10
    pill_h = 56

    margin = 55
    if side == "left":
        px = margin
    elif side == "right":
        px = W - margin - pill_w
    else:
        px = (W - pill_w) // 2

    py = y_pos - pill_h // 2

    # Draw soft drop shadow
    draw.rounded_rectangle([px + 3, py + 5, px + pill_w + 3, py + pill_h + 5], radius=28, fill=(0, 0, 0, 42))
    # Draw white pill with crisp honey gold border
    draw.rounded_rectangle([px, py, px + pill_w, py + pill_h], radius=28, fill="#FFFFFF", outline="#FFB700", width=3)

    # Draw vector honey star
    star_cx = px + pad_h + icon_size // 2
    star_cy = py + pill_h // 2
    draw_star(draw, star_cx, star_cy, r_outer=12, r_inner=5.5, fill="#FFB700", outline="#E59700")

    # Draw text cleanly
    text_x = star_cx + icon_size // 2 + 10
    text_y = py + (pill_h - text_h) // 2 - bbox[1]
    draw.text((text_x, text_y), text, fill="#262626", font=f_callout)

def save_slide(base, filename):
    out_67 = os.path.join(OUT_DIR, filename)
    rgb_67 = base.convert("RGB")
    rgb_67.save(out_67, quality=96)

    out_65 = os.path.join(OUT_65_DIR, filename)
    rgb_65 = rgb_67.resize((1242, 2688), Image.Resampling.LANCZOS)
    rgb_65.save(out_65, quality=96)
    print(f"Saved: {filename} (6.7\" & 6.5\")")

# ─────────────────────────────────────────────────────────────────────────────
# SLIDE 1: COMMUNITY FEED
# ─────────────────────────────────────────────────────────────────────────────
def build_slide_1():
    base = create_base_canvas(
        "COMMUNITY FEED",
        "See What Friends Are Watching",
        "Live reviews and honey ratings from your circle.",
        "Add friend picks to your watchlist in one tap."
    )
    phone = frame_screenshot(os.path.join(RAW_DIR, "feed.png"))
    px = (W - 920) // 2
    py = 480
    composite_phone_with_shadow(base, phone, px, py)

    draw = ImageDraw.Draw(base)
    draw_callout_pill(draw, "10-Point Honey Ratings", side="left", y_pos=py + 760)
    draw_callout_pill(draw, "Live Friend Feed", side="right", y_pos=py + 1180)

    save_slide(base, "01_community_feed.png")

# ─────────────────────────────────────────────────────────────────────────────
# SLIDE 2: ENTRIES & UNIVERSAL TRACKING
# ─────────────────────────────────────────────────────────────────────────────
def build_slide_2():
    base = create_base_canvas(
        "UNIVERSAL TRACKER",
        "Track Everything In One Place",
        "Easily organize movies, TV shows, and anime.",
        "Switch between Watching, Watchlist & Completed."
    )
    phone = frame_screenshot(os.path.join(RAW_DIR, "entries.png"))
    px = (W - 920) // 2
    py = 480
    composite_phone_with_shadow(base, phone, px, py)

    draw = ImageDraw.Draw(base)
    draw_callout_pill(draw, "Watching & Watchlist Tabs", side="left", y_pos=py + 680)
    draw_callout_pill(draw, "Quick Category Filters", side="right", y_pos=py + 1120)

    save_slide(base, "02_entries_tracking.png")

# ─────────────────────────────────────────────────────────────────────────────
# SLIDE 3: SUGGEST & INFLUENCE SCORE
# ─────────────────────────────────────────────────────────────────────────────
def build_slide_3():
    base = create_base_canvas(
        "SUGGESTIONS & COMMUNITY",
        "Suggest & Boost Influence",
        "Recommend favorite shows directly to friends.",
        "Earn higher Influence Scores when friends watch."
    )
    phone = frame_screenshot(os.path.join(RAW_DIR, "suggest.png"))
    px = (W - 920) // 2
    py = 480
    composite_phone_with_shadow(base, phone, px, py)

    draw = ImageDraw.Draw(base)
    draw_callout_pill(draw, "Pick Titles & Friends", side="left", y_pos=py + 720)
    draw_callout_pill(draw, "Boost Influence Score", side="right", y_pos=py + 1220)

    save_slide(base, "03_suggest_and_influence.png")

# ─────────────────────────────────────────────────────────────────────────────
# SLIDE 4: MINDLENS — TASTE PROFILE & ARCHETYPE (COMBINED 1, 2, 3)
# ─────────────────────────────────────────────────────────────────────────────
def build_slide_4():
    base = create_base_canvas(
        "MINDLENS AI",
        "Decode Your Cinematic DNA",
        "Interactive radar charts uncover genre psychology.",
        "Unlock cognitive archetypes and viewing traits."
    )
    phone = frame_screenshot(os.path.join(RAW_DIR, "mindlense_2.png"), pw=880, ph=1920)
    px = (W - 880) // 2 - 35
    py = 510
    composite_phone_with_shadow(base, phone, px, py, pw=880, ph=1920)

    raw3 = Image.open(os.path.join(RAW_DIR, "mindlense_3.png")).convert("RGBA")
    card_w, card_h = 520, 680
    crop3 = raw3.crop((80, 520, raw3.width - 80, 1600)).resize((card_w, card_h), Image.Resampling.LANCZOS)
    
    float_card = Image.new("RGBA", (card_w, card_h), (0, 0, 0, 0))
    fdraw = ImageDraw.Draw(float_card)
    card_mask = Image.new("L", (card_w, card_h), 0)
    ImageDraw.Draw(card_mask).rounded_rectangle([0, 0, card_w, card_h], radius=34, fill=255)
    float_card.paste(crop3, (0, 0), card_mask)
    fdraw.rounded_rectangle([0, 0, card_w, card_h], radius=34, outline="#FFB700", width=4)

    card_shadow = Image.new("RGBA", (card_w + 50, card_h + 50), (0, 0, 0, 0))
    ImageDraw.Draw(card_shadow).rounded_rectangle([25, 25, card_w + 25, card_h + 25], radius=34, fill=(0, 0, 0, 55))
    card_shadow = card_shadow.filter(ImageFilter.GaussianBlur(22))
    
    fx = W - card_w - 55
    fy = py + 840
    base.alpha_composite(card_shadow, (fx - 25, fy - 25 + 15))
    base.alpha_composite(float_card, (fx, fy))

    draw = ImageDraw.Draw(base)
    draw_callout_pill(draw, "Cognitive Archetypes", side="left", y_pos=py + 640)
    draw_callout_pill(draw, "Genre Psychology Radar", side="right", y_pos=py + 380)

    save_slide(base, "04_mindlens_dna.png")

# ─────────────────────────────────────────────────────────────────────────────
# SLIDE 5: PROFILE & RANKINGS (COMBINED PROFILE + RANKINGS)
# ─────────────────────────────────────────────────────────────────────────────
def build_slide_5():
    base = create_base_canvas(
        "PROFILE & RANKINGS",
        "Flaunt Your Journey & Stacks",
        "Showcase your cinema journey and report cards.",
        "Build custom tier lists to rank and compare."
    )
    phone = frame_screenshot(os.path.join(RAW_DIR, "profile.png"), pw=880, ph=1920)
    px = (W - 880) // 2 - 35
    py = 510
    composite_phone_with_shadow(base, phone, px, py, pw=880, ph=1920)

    raw_rank = Image.open(os.path.join(RAW_DIR, "rankings.png")).convert("RGBA")
    card_w, card_h = 520, 680
    crop_rank = raw_rank.crop((80, 380, raw_rank.width - 80, 1500)).resize((card_w, card_h), Image.Resampling.LANCZOS)

    float_card = Image.new("RGBA", (card_w, card_h), (0, 0, 0, 0))
    fdraw = ImageDraw.Draw(float_card)
    card_mask = Image.new("L", (card_w, card_h), 0)
    ImageDraw.Draw(card_mask).rounded_rectangle([0, 0, card_w, card_h], radius=34, fill=255)
    float_card.paste(crop_rank, (0, 0), card_mask)
    fdraw.rounded_rectangle([0, 0, card_w, card_h], radius=34, outline="#FFB700", width=4)

    card_shadow = Image.new("RGBA", (card_w + 50, card_h + 50), (0, 0, 0, 0))
    ImageDraw.Draw(card_shadow).rounded_rectangle([25, 25, card_w + 25, card_h + 25], radius=34, fill=(0, 0, 0, 55))
    card_shadow = card_shadow.filter(ImageFilter.GaussianBlur(22))

    fx = W - card_w - 55
    fy = py + 840
    base.alpha_composite(card_shadow, (fx - 25, fy - 25 + 15))
    base.alpha_composite(float_card, (fx, fy))

    draw = ImageDraw.Draw(base)
    draw_callout_pill(draw, "Private Privileges & Stats", side="left", y_pos=py + 640)
    draw_callout_pill(draw, "Cinema Stacks & Tier Lists", side="right", y_pos=py + 380)

    save_slide(base, "05_profile_and_rankings.png")

# ─────────────────────────────────────────────────────────────────────────────
# SLIDE 6: UNIVERSAL SEARCH
# ─────────────────────────────────────────────────────────────────────────────
def build_slide_6():
    base = create_base_canvas(
        "UNIVERSAL SEARCH",
        "Search Anything In WatchHive",
        "Explore movies, TV shows, anime, and directors.",
        "Find fellow members, friends, and shared stacks."
    )
    phone = frame_screenshot(os.path.join(RAW_DIR, "search.png"))
    px = (W - 920) // 2
    py = 480
    composite_phone_with_shadow(base, phone, px, py)

    draw = ImageDraw.Draw(base)
    draw_callout_pill(draw, "Instant Global Search", side="left", y_pos=py + 680)
    draw_callout_pill(draw, "Movies, TV & Members", side="right", y_pos=py + 1180)

    save_slide(base, "06_universal_search.png")

# ─────────────────────────────────────────────────────────────────────────────
# SLIDE 7: QUICK ADD / LOGGING (DEDICATED FULL SCREEN)
# ─────────────────────────────────────────────────────────────────────────────
def build_slide_7():
    base = create_base_canvas(
        "QUICK LOGGING",
        "One-Tap Quick Logging",
        "Update watching status and rate with honey stars.",
        "Add to watchlist or mark as watched in seconds."
    )
    phone = frame_screenshot(os.path.join(RAW_DIR, "quick add movie status.png"))
    px = (W - 920) // 2
    py = 480
    composite_phone_with_shadow(base, phone, px, py)

    draw = ImageDraw.Draw(base)
    draw_callout_pill(draw, "One-Tap Status Update", side="left", y_pos=py + 720)
    draw_callout_pill(draw, "Instant Watchlist Add", side="right", y_pos=py + 1180)

    save_slide(base, "07_quick_logging.png")

# ─────────────────────────────────────────────────────────────────────────────
# SLIDE 8: SEASON & EPISODE TRACKING (DEDICATED FULL SCREEN)
# ─────────────────────────────────────────────────────────────────────────────
def build_slide_8():
    base = create_base_canvas(
        "EPISODE TRACKER",
        "Track Seasons & Episodes",
        "Log every episode across TV series and anime.",
        "Monitor progress with effortless checkmarks."
    )
    phone = frame_screenshot(os.path.join(RAW_DIR, "season and episode tracking.png"))
    px = (W - 920) // 2
    py = 480
    composite_phone_with_shadow(base, phone, px, py)

    draw = ImageDraw.Draw(base)
    draw_callout_pill(draw, "Season Progress & Checkmarks", side="left", y_pos=py + 720)
    draw_callout_pill(draw, "Detailed Episode Guide", side="right", y_pos=py + 1180)

    save_slide(base, "08_season_episode_tracking.png")

print("Generating separated slides 7 and 8...")
build_slide_1()
build_slide_2()
build_slide_3()
build_slide_4()
build_slide_5()
build_slide_6()
build_slide_7()
build_slide_8()
print("All 8 slides successfully generated!")
