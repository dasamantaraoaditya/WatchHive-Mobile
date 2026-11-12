import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

W, H = 1290, 2796
OUTPUT_DIR = "/Users/adityadasamantharao/Documents/Repos/watchhive_mobile/app_store_screenshots"
os.makedirs(OUTPUT_DIR, exist_ok=True)
os.makedirs(os.path.join(OUTPUT_DIR, "6.5_inch"), exist_ok=True)

# System fonts
try:
    font_badge = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 34)
    font_title = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 74)
    font_sub = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 39)
except Exception:
    font_badge = font_title = font_sub = ImageFont.load_default()

SLIDES = [
    {
        "filename": "01_season_episode_tracking.png",
        "badge": "EPISODE & SEASON TRACKER",
        "title": "Track Seasons & Episodes",
        "line1": "Log every season and episode across TV shows and anime.",
        "line2": "Effortless one-tap checkmarks to never lose your place.",
        "screen_path": "/tmp/android_tv_seasons.png"
    },
    {
        "filename": "02_friend_circle_feed.png",
        "badge": "COMMUNITY FEED",
        "title": "Connect With Your Circle",
        "line1": "See what your friends are watching, rating, and loving in real time.",
        "line2": "Discover trending cinema directly from your social feed.",
        "screen_path": "/Users/adityadasamantharao/.gemini/antigravity/brain/bd03a7c2-8dbd-452c-868d-d921e4f0c878/emulator_v1020_feed.png"
    },
    {
        "filename": "03_suggest_and_influence.png",
        "badge": "SUGGESTIONS & INFLUENCE",
        "title": "Suggest & Boost Influence",
        "line1": "Recommend favorite cinema directly to friends with reviews.",
        "line2": "Earn higher Influence Scores when friends watch your picks.",
        "screen_path": "/Users/adityadasamantharao/.gemini/antigravity/brain/bd03a7c2-8dbd-452c-868d-d921e4f0c878/suggest_to_friends_step2.png"
    },
    {
        "filename": "04_rankings_and_compare.png",
        "badge": "CINEMA & ANIME RANKINGS",
        "title": "Rank & Compare Your Stacks",
        "line1": "Build custom tier lists for cinema, anime, and series.",
        "line2": "Compare your rankings side-by-side with fellow cinephiles.",
        "screen_path": "/tmp/android_rankings.png"
    },
    {
        "filename": "05_profile_privacy_journey.png",
        "badge": "PRIVACY & REPORT CARDS",
        "title": "Privacy & Cinematic Journey",
        "line1": "Manage granular privacy so data is visible only to your circle.",
        "line2": "Showcase your personalized report cards, badges, and stats.",
        "screen_path": "/Users/adityadasamantharao/.gemini/antigravity/brain/bd03a7c2-8dbd-452c-868d-d921e4f0c878/android_profile_scrolled.png"
    },
    {
        "filename": "06_mindlens_taste_dna.png",
        "badge": "MINDLENS TASTE DNA",
        "title": "Decode Your Viewing Profile",
        "line1": "Interactive radar charts decode your genre preferences.",
        "line2": "Uncover Shannon entropy taste analytics and cinematic insights.",
        "screen_path": "/Users/adityadasamantharao/.gemini/antigravity/brain/bd03a7c2-8dbd-452c-868d-d921e4f0c878/emulator_mindlens_analytics.png"
    }
]

def create_slide(slide):
    # 1. Canvas with Warm Cream Background (#FFF9F0)
    base = Image.new("RGBA", (W, H), (255, 249, 240, 255))
    draw = ImageDraw.Draw(base)

    # 2. Honey ambient glow
    accent_overlay = Image.new("RGBA", (W, 700), (255, 183, 0, 0))
    accent_draw = ImageDraw.Draw(accent_overlay)
    accent_draw.ellipse([-200, -350, W + 200, 450], fill=(255, 183, 0, 35))
    base.alpha_composite(accent_overlay, (0, 0))
    draw = ImageDraw.Draw(base)

    # 3. Badge Pill
    badge_text = slide["badge"]
    badge_w = len(badge_text) * 21 + 70
    badge_x = (W - badge_w) // 2
    badge_y = 120
    draw.rounded_rectangle([badge_x, badge_y, badge_x + badge_w, badge_y + 64], radius=32, fill="#FFB700")
    draw.text((W // 2, badge_y + 32), badge_text, fill="#262626", font=font_badge, anchor="mm")

    # 4. Headline and 1-2 line descriptions
    draw.text((W // 2, 245), slide["title"], fill="#262626", font=font_title, anchor="mm")
    draw.text((W // 2, 335), slide["line1"], fill="#525252", font=font_sub, anchor="mm")
    draw.text((W // 2, 395), slide["line2"], fill="#737373", font=font_sub, anchor="mm")

    # 5. Device Mockup Frame
    phone_w = 980
    phone_h = 2100
    phone_x = (W - phone_w) // 2
    phone_y = 490
    corner_r = 75

    # Shadow
    shadow_pad = 50
    shadow = Image.new("RGBA", (phone_w + shadow_pad * 2, phone_h + shadow_pad * 2), (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(shadow)
    sdraw.rounded_rectangle(
        [shadow_pad, shadow_pad, phone_w + shadow_pad, phone_h + shadow_pad],
        radius=corner_r,
        fill=(0, 0, 0, 40)
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(30))
    base.alpha_composite(shadow, (phone_x - shadow_pad, phone_y - shadow_pad + 20))

    # Outer Phone Bezel
    phone_body = Image.new("RGBA", (phone_w, phone_h), (0, 0, 0, 0))
    pdraw = ImageDraw.Draw(phone_body)
    pdraw.rounded_rectangle([0, 0, phone_w, phone_h], radius=corner_r, fill="#1C1C1E", outline="#3A3A3C", width=6)

    # Screen inside bezel
    bezel = 18
    screen_w = phone_w - bezel * 2
    screen_h = phone_h - bezel * 2
    screen_r = corner_r - 12

    # Prepare Screenshot
    screen_img = None
    if os.path.exists(slide["screen_path"]):
        raw_screen = Image.open(slide["screen_path"]).convert("RGBA")
        raw_ratio = raw_screen.width / raw_screen.height
        target_ratio = screen_w / screen_h
        if raw_ratio > target_ratio:
            new_w = int(raw_screen.height * target_ratio)
            crop_x = (raw_screen.width - new_w) // 2
            raw_screen = raw_screen.crop((crop_x, 0, crop_x + new_w, raw_screen.height))
        else:
            new_h = int(raw_screen.width / target_ratio)
            raw_screen = raw_screen.crop((0, 0, raw_screen.width, new_h))
        screen_img = raw_screen.resize((screen_w, screen_h), Image.Resampling.LANCZOS)
    else:
        screen_img = Image.new("RGBA", (screen_w, screen_h), "#FFF9F0")

    # Round screen corners with mask
    mask = Image.new("L", (screen_w, screen_h), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, screen_w, screen_h], radius=screen_r, fill=255)
    
    phone_body.paste(screen_img, (bezel, bezel), mask)

    # Dynamic Island Pill
    island_w = 210
    island_h = 56
    island_x = (phone_w - island_w) // 2
    island_y = bezel + 22
    pdraw = ImageDraw.Draw(phone_body)
    pdraw.rounded_rectangle([island_x, island_y, island_x + island_w, island_y + island_h], radius=28, fill="#000000")

    # Paste phone onto base
    base.alpha_composite(phone_body, (phone_x, phone_y))

    # Save 6.7 inch (1290 x 2796)
    final_67 = base.convert("RGB")
    out_67 = os.path.join(OUTPUT_DIR, slide["filename"])
    final_67.save(out_67, quality=95)

    # Save 6.5 inch (1242 x 2688)
    final_65 = final_67.resize((1242, 2688), Image.Resampling.LANCZOS)
    out_65 = os.path.join(OUTPUT_DIR, "6.5_inch", slide["filename"])
    final_65.save(out_65, quality=95)

    print(f"Generated: {slide['filename']} (6.7\": 1290x2796, 6.5\": 1242x2688)")

for s in SLIDES:
    create_slide(s)

print("All requested feature screenshots generated successfully!")
