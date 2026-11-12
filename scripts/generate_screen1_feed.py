import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

W, H = 1290, 2796
OUTPUT_DIR = "/Users/adityadasamantharao/Documents/Repos/watchhive_mobile/app_store_screenshots"
CACHE_DIR = "/tmp/wh_posters_cache"
os.makedirs(OUTPUT_DIR, exist_ok=True)

def load_cached_image(name, fallback_color="#333333"):
    path = os.path.join(CACHE_DIR, name)
    if os.path.exists(path):
        return Image.open(path).convert("RGBA")
    return Image.new("RGBA", (300, 450), fallback_color)

poster_oppenheimer = load_cached_image("oppenheimer.jpg")
poster_severance = load_cached_image("severance.jpg")
poster_dune = load_cached_image("dune2.jpg")

# Fonts
font_bold = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
font_reg = "/System/Library/Fonts/Supplemental/Arial.ttf"

f_badge = ImageFont.truetype(font_bold, 32)
f_title = ImageFont.truetype(font_bold, 78)
f_sub = ImageFont.truetype(font_reg, 38)
f_callout = ImageFont.truetype(font_bold, 28)

# Phone fonts
pf_time = ImageFont.truetype(font_bold, 30)
pf_logo = ImageFont.truetype(font_bold, 36)
pf_user = ImageFont.truetype(font_bold, 28)
pf_meta = ImageFont.truetype(font_reg, 24)
pf_film_title = ImageFont.truetype(font_bold, 32)
pf_film_sub = ImageFont.truetype(font_reg, 24)
pf_review = ImageFont.truetype(font_reg, 26)
pf_rating = ImageFont.truetype(font_bold, 30)
pf_btn = ImageFont.truetype(font_bold, 24)
pf_tag = ImageFont.truetype(font_bold, 22)

def render_feed_phone(pw, ph):
    phone = Image.new("RGBA", (pw, ph), (255, 249, 240, 255)) # AppColors.background #FFF9F0
    pdraw = ImageDraw.Draw(phone)
    
    # Status bar (iOS style)
    pdraw.text((65, 30), "9:41", fill="#262626", font=pf_time, anchor="lm")
    # Dynamic island
    di_w, di_h = 220, 60
    pdraw.rounded_rectangle([(pw - di_w)//2, 18, (pw + di_w)//2, 18 + di_h], radius=30, fill="#000000")
    
    # App Bar (Honey Bee Logo + Title + Icons)
    appbar_y = 100
    logo_path = "/Users/adityadasamantharao/Documents/Repos/watchhive_mobile/assets/images/watchhive-logo.png"
    if os.path.exists(logo_path):
        logo_im = Image.open(logo_path).convert("RGBA").resize((48, 48), Image.Resampling.LANCZOS)
        phone.paste(logo_im, (50, appbar_y), logo_im)
    
    pdraw.text((112, appbar_y + 24), "WatchersHive", fill="#262626", font=pf_logo, anchor="lm")
    
    # Bell background circle
    pdraw.ellipse([pw - 110, appbar_y, pw - 60, appbar_y + 50], fill="#FFFFFF", outline="#E5E5E5", width=2)
    pdraw.text((pw - 85, appbar_y + 25), "🔔", fill="#262626", font=pf_user, anchor="mm")
    pdraw.ellipse([pw - 74, appbar_y + 4, pw - 58, appbar_y + 20], fill="#FFB700", outline="#262626", width=2)
    pdraw.text((pw - 66, appbar_y + 12), "3", fill="#262626", font=pf_tag, anchor="mm")

    # SmartSuggest Mini Carousel / Hero
    card_y = 175
    card_margin = 45
    card_w = pw - card_margin * 2
    
    # Hero card background
    pdraw.rounded_rectangle([card_margin, card_y, card_margin + card_w, card_y + 190], radius=28, fill="#FFF2D6", outline="#FFB700", width=3)
    pdraw.rounded_rectangle([card_margin + 24, card_y + 22, card_margin + 210, card_y + 58], radius=16, fill="#FFB700")
    pdraw.text((card_margin + 117, card_y + 40), "✦ SmartSuggest", fill="#262626", font=pf_tag, anchor="mm")
    pdraw.text((card_margin + 230, card_y + 40), "96% Taste Match", fill="#E59700", font=pf_tag, anchor="lm")
    
    # Hero Movie: Dune 2
    dune_thumb = poster_dune.resize((85, 125), Image.Resampling.LANCZOS)
    dune_mask = Image.new("L", (85, 125), 0)
    ImageDraw.Draw(dune_mask).rounded_rectangle([0, 0, 85, 125], radius=14, fill=255)
    phone.paste(dune_thumb, (card_margin + 24, card_y + 50), dune_mask)
    
    pdraw.text((card_margin + 125, card_y + 75), "Dune: Part Two (2024)", fill="#262626", font=pf_film_title)
    pdraw.text((card_margin + 125, card_y + 115), "Trending with 8 friends in your circle", fill="#525252", font=pf_film_sub)
    pdraw.text((card_margin + 125, card_y + 145), "Sci-Fi • Adventure • Timothée Chalamet", fill="#737373", font=pf_film_sub)

    # FEED CARD 1: Oppenheimer
    fc1_y = 390
    fc1_h = 700
    pdraw.rounded_rectangle([card_margin, fc1_y, card_margin + card_w, fc1_y + fc1_h], radius=30, fill="#FFFFFF", outline="#EBEBEB", width=2)
    
    # User row
    pdraw.ellipse([card_margin + 24, fc1_y + 24, card_margin + 84, fc1_y + 84], fill="#FFB700")
    pdraw.text((card_margin + 54, fc1_y + 54), "A", fill="#262626", font=pf_user, anchor="mm")
    
    pdraw.text((card_margin + 98, fc1_y + 42), "Aditya D.", fill="#262626", font=pf_user, anchor="lm")
    pdraw.text((card_margin + 98, fc1_y + 68), "@aditya • 2h ago", fill="#737373", font=pf_meta, anchor="lm")
    
    pdraw.rounded_rectangle([pw - card_margin - 180, fc1_y + 34, pw - card_margin - 24, fc1_y + 72], radius=18, fill="#FFF9F0", outline="#FFDA40", width=2)
    pdraw.text((pw - card_margin - 102, fc1_y + 53), "Watched", fill="#262626", font=pf_tag, anchor="mm")

    # Poster & Details
    post_w, post_h = 160, 235
    opp_thumb = poster_oppenheimer.resize((post_w, post_h), Image.Resampling.LANCZOS)
    opp_mask = Image.new("L", (post_w, post_h), 0)
    ImageDraw.Draw(opp_mask).rounded_rectangle([0, 0, post_w, post_h], radius=20, fill=255)
    phone.paste(opp_thumb, (card_margin + 24, fc1_y + 105), opp_mask)
    
    info_x = card_margin + 24 + post_w + 24
    pdraw.text((info_x, fc1_y + 115), "Oppenheimer", fill="#262626", font=pf_film_title)
    pdraw.text((info_x, fc1_y + 155), "2023 • Biography / Drama", fill="#737373", font=pf_film_sub)
    pdraw.text((info_x, fc1_y + 185), "Directed by Christopher Nolan", fill="#525252", font=pf_film_sub)
    
    # Honey Gold Rating Display
    pdraw.rounded_rectangle([info_x, fc1_y + 225, info_x + 220, fc1_y + 275], radius=16, fill="#FFF2D6", outline="#FFB700", width=2)
    pdraw.text((info_x + 24, fc1_y + 250), "★ 9.0 / 10", fill="#262626", font=pf_rating, anchor="lm")
    pdraw.text((info_x + 155, fc1_y + 250), "Honey", fill="#E59700", font=pf_tag, anchor="lm")

    # Review quote box
    review_y = fc1_y + 360
    pdraw.rounded_rectangle([card_margin + 24, review_y, card_margin + card_w - 24, review_y + 155], radius=20, fill="#F9F9F9")
    pdraw.text((card_margin + 44, review_y + 30), "“Nolan’s sound design and Murphy’s performance", fill="#262626", font=pf_review)
    pdraw.text((card_margin + 44, review_y + 65), "are a masterclass. The third act tension is unreal.", fill="#262626", font=pf_review)
    pdraw.text((card_margin + 44, review_y + 100), "Definitely belongs on the all-time shelf.”", fill="#262626", font=pf_review)

    # Social Interaction Row
    action_y = fc1_y + 535
    pdraw.line([(card_margin + 24, action_y), (card_margin + card_w - 24, action_y)], fill="#F0F0F0", width=2)
    
    btn_y = action_y + 30
    pdraw.text((card_margin + 60, btn_y), "❤️ 28", fill="#E53935", font=pf_btn, anchor="lm")
    pdraw.text((card_margin + 180, btn_y), "💬 7", fill="#525252", font=pf_btn, anchor="lm")
    
    pdraw.rounded_rectangle([pw - card_margin - 310, btn_y - 22, pw - card_margin - 150, btn_y + 24], radius=18, fill="#FFF9F0", outline="#FFDA40", width=2)
    pdraw.text((pw - card_margin - 230, btn_y + 1), "+ Watchlist", fill="#262626", font=pf_btn, anchor="mm")
    
    pdraw.text((pw - card_margin - 80, btn_y), "↗ Share", fill="#525252", font=pf_btn, anchor="lm")

    # FEED CARD 2 (Sneak peek at bottom)
    fc2_y = 1115
    pdraw.rounded_rectangle([card_margin, fc2_y, card_margin + card_w, fc2_y + 500], radius=30, fill="#FFFFFF", outline="#EBEBEB", width=2)
    
    # User 2
    pdraw.ellipse([card_margin + 24, fc2_y + 24, card_margin + 84, fc2_y + 84], fill="#FFDA40")
    pdraw.text((card_margin + 54, fc2_y + 54), "E", fill="#262626", font=pf_user, anchor="mm")
    pdraw.text((card_margin + 98, fc2_y + 42), "Elena R.", fill="#262626", font=pf_user, anchor="lm")
    pdraw.text((card_margin + 98, fc2_y + 68), "@elena_films • 4h ago", fill="#737373", font=pf_meta, anchor="lm")
    
    pdraw.rounded_rectangle([pw - card_margin - 210, fc2_y + 34, pw - card_margin - 24, fc2_y + 72], radius=18, fill="#FFF9F0", outline="#FFDA40", width=2)
    pdraw.text((pw - card_margin - 117, fc2_y + 53), "Finished S1", fill="#262626", font=pf_tag, anchor="mm")
    
    sev_thumb = poster_severance.resize((post_w, post_h), Image.Resampling.LANCZOS)
    sev_mask = Image.new("L", (post_w, post_h), 0)
    ImageDraw.Draw(sev_mask).rounded_rectangle([0, 0, post_w, post_h], radius=20, fill=255)
    phone.paste(sev_thumb, (card_margin + 24, fc2_y + 105), sev_mask)
    
    pdraw.text((info_x, fc2_y + 115), "Severance", fill="#262626", font=pf_film_title)
    pdraw.text((info_x, fc2_y + 155), "Apple TV+ • Thriller / Sci-Fi", fill="#737373", font=pf_film_sub)
    pdraw.rounded_rectangle([info_x, fc2_y + 205, info_x + 220, fc2_y + 255], radius=16, fill="#FFF2D6", outline="#FFB700", width=2)
    pdraw.text((info_x + 24, fc2_y + 230), "★ 9.5 / 10", fill="#262626", font=pf_rating, anchor="lm")

    # Bottom Nav Bar
    nav_h = 130
    nav_y = ph - nav_h
    pdraw.rectangle([0, nav_y, pw, ph], fill="#FFFFFF")
    pdraw.line([(0, nav_y), (pw, nav_y)], fill="#EEEEEE", width=2)
    
    tabs = [
        ("Home", "🏠", True),
        ("Entries", "📑", False),
        ("Search", "🔍", False),
        ("MindLens", "🧠", False),
        ("Profile", "👤", False)
    ]
    tab_w = pw // 5
    for i, (name, icon, active) in enumerate(tabs):
        tx = i * tab_w + tab_w // 2
        ty = nav_y + 40
        if active:
            pdraw.rounded_rectangle([tx - 45, ty - 25, tx + 45, ty + 45], radius=20, fill="#FFF2D6")
            pdraw.text((tx, ty), icon, fill="#262626", font=pf_user, anchor="mm")
            pdraw.text((tx, ty + 32), name, fill="#262626", font=pf_tag, anchor="mm")
        else:
            pdraw.text((tx, ty), icon, fill="#888888", font=pf_user, anchor="mm")
            pdraw.text((tx, ty + 32), name, fill="#888888", font=pf_tag, anchor="mm")
            
    pdraw.rounded_rectangle([(pw - 260)//2, ph - 22, (pw + 260)//2, ph - 14], radius=4, fill="#262626")

    return phone

def build_app_store_slide():
    base = Image.new("RGBA", (W, H), (255, 249, 240, 255))
    draw = ImageDraw.Draw(base)

    # Ambient Honey Glow
    glow = Image.new("RGBA", (W, 850), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glow)
    gdraw.ellipse([-300, -400, W + 300, 500], fill=(255, 183, 0, 42))
    base.alpha_composite(glow, (0, 0))
    draw = ImageDraw.Draw(base)

    # Category Pill
    badge_text = "COMMUNITY FEED"
    badge_w = 420
    badge_h = 68
    badge_x = (W - badge_w) // 2
    badge_y = 120
    draw.rounded_rectangle([badge_x, badge_y, badge_x + badge_w, badge_y + badge_h], radius=34, fill="#FFB700")
    draw.text((W // 2, badge_y + 34), badge_text, fill="#262626", font=f_badge, anchor="mm")

    # Headline & 2-Line Pictorial Benefit
    draw.text((W // 2, 245), "See What Friends Are Watching", fill="#262626", font=f_title, anchor="mm")
    draw.text((W // 2, 335), "Real-time reviews and honey ratings from people you trust.", fill="#525252", font=f_sub, anchor="mm")
    draw.text((W // 2, 395), "Add recommendations straight to your watchlist in one tap.", fill="#737373", font=f_sub, anchor="mm")

    # Phone Screen
    phone_w = 980
    phone_h = 2080
    phone_screen = render_feed_phone(phone_w, phone_h)

    # Shadow & Hardware Bezel
    phone_x = (W - phone_w) // 2
    phone_y = 510
    corner_r = 72

    shadow_pad = 60
    shadow = Image.new("RGBA", (phone_w + shadow_pad * 2, phone_h + shadow_pad * 2), (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(shadow)
    sdraw.rounded_rectangle(
        [shadow_pad, shadow_pad, phone_w + shadow_pad, phone_h + shadow_pad],
        radius=corner_r,
        fill=(0, 0, 0, 50)
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(35))
    base.alpha_composite(shadow, (phone_x - shadow_pad, phone_y - shadow_pad + 25))

    phone_frame = Image.new("RGBA", (phone_w, phone_h), (0, 0, 0, 0))
    fdraw = ImageDraw.Draw(phone_frame)
    fdraw.rounded_rectangle([0, 0, phone_w, phone_h], radius=corner_r, fill="#1C1C1E", outline="#3E3E42", width=6)

    bezel = 14
    inner_w = phone_w - bezel * 2
    inner_h = phone_h - bezel * 2
    inner_screen = phone_screen.resize((inner_w, inner_h), Image.Resampling.LANCZOS)
    screen_mask = Image.new("L", (inner_w, inner_h), 0)
    ImageDraw.Draw(screen_mask).rounded_rectangle([0, 0, inner_w, inner_h], radius=corner_r - 10, fill=255)
    phone_frame.paste(inner_screen, (bezel, bezel), screen_mask)

    base.alpha_composite(phone_frame, (phone_x, phone_y))
    draw = ImageDraw.Draw(base)

    # Pictorial Callout Badges
    def draw_callout_pill(cx, cy, text, icon="✦", on_left=True):
        pill_w = len(text) * 16 + 80
        pill_h = 58
        px = cx - pill_w if on_left else cx
        py = cy - pill_h // 2
        draw.rounded_rectangle([px + 3, py + 5, px + pill_w + 3, py + pill_h + 5], radius=29, fill=(0, 0, 0, 40))
        draw.rounded_rectangle([px, py, px + pill_w, py + pill_h], radius=29, fill="#FFFFFF", outline="#FFB700", width=3)
        draw.text((px + 28, py + pill_h // 2), f"{icon}  {text}", fill="#262626", font=f_callout, anchor="lm")
    
    # Floating highlights
    draw_callout_pill(phone_x + phone_w - 60, phone_y + 810, "10-Point Honey Ratings", on_left=False)
    draw_callout_pill(phone_x + 60, phone_y + 1090, "Instant Watchlist Add", on_left=True)

    # Save to dedicated folder
    out_67 = os.path.join(OUTPUT_DIR, "01_community_feed.png")
    final_rgb = base.convert("RGB")
    final_rgb.save(out_67, quality=96)
    print(f"Generated Slide 1: {out_67}")

build_app_store_slide()
