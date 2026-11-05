# WatchersHive UI/UX Standards & Design System 🐝🎨

> **The Single Source of Truth for WatchersHive UI/UX Design**  
> *Targeted for UI/UX Designers, Frontend Engineers, and AI Pair Programming Agents.*  
> *Covers design rationale, color tokens, typography hierarchy, accessibility, component blueprints, and platform parity (Flutter Mobile & Web PWA).*

---

## 🍯 1. Design Rationale & Brand Identity

### The WatchersHive Ethos
Most movie tracking and cataloging platforms (Letterboxd, Trakt, IMDb) default to cold, sterile dark themes (`#000000` or `#121212`) punctuated by harsh neon blues or muted grays. They often feel utilitarian, isolated, or algorithmic.

**WatchersHive is built around the concept of a living, warm community — "The Hive".**
- **Warm Honey & Cream Aesthetic**: Warm amber gold (`#FFB700`), soothing cream backgrounds (`#FFF9F0`), elevated pure-white cards (`#FFFFFF`), and crisp charcoal typography (`#2D2926`).
- **Emotional Association**: Evokes golden cinema projector beams, buttery theater popcorn, warm vintage cinema lobbies, honeycombs, and friendly recommendations.
- **Cinematic Contrast for Media**: While main app navigation embraces the warm cream palette, full-screen media components (e.g., the 9:16 Instagram Story card and movie backdrop headers) use ambient cinematic darkness infused with warm golden glows so movie artwork pops vibrantly.

---

## 🎨 2. Core Color Palette & Design Tokens

### Primary & Brand Colors
| Token Name | Hex Code | Flutter (`AppColors`) | Web CSS Variable | Usage |
| :--- | :--- | :--- | :--- | :--- |
| **Honey Gold (Primary)** | `#FFB700` | `AppColors.primary` | `--primary-500` / `#ffb700` | Brand identity, primary CTAs, active highlights, star ratings |
| **Honey Gold Dark** | `#E59700` | `AppColors.primaryDark` | `--primary-600` / `#e59700` | Pressed/active button states, active navigation tabs |
| **Honey Gold Light** | `#FFDA40` | `AppColors.primaryLight` | `--primary-300` / `#ffda40` | Secondary accents, progress indicators |
| **Honey Tint (Soft Wash)** | `alpha: 0.12–0.15` | `AppColors.primary.withValues(alpha: 0.15)` | `rgba(255, 183, 0, 0.15)` | Badge backgrounds, active pill highlights, unread badges |

### Backgrounds & Surfaces
| Token Name | Hex Code | Flutter (`AppColors`) | Web CSS Variable | Usage |
| :--- | :--- | :--- | :--- | :--- |
| **Warm Cream (Scaffold)** | `#FFF9F0` | `AppColors.background` | `--bg-primary` / `#fff9f0` | Main screen scaffold background |
| **Pure White (Surface)** | `#FFFFFF` | `AppColors.surface` / `cardBg` | `--neutral-0` / `#ffffff` | Cards, bottom sheets, dialogue containers |
| **Surface Elevated** | `#FFF3E0` | `AppColors.surfaceElevated` | `--neutral-100` / `#fff3e0` | Text input fills, inactive filter chips |
| **Surface Highest** | `#F5EFE6` | `AppColors.surfaceHighest` | `--neutral-200` / `#f5efe6` | Poster placeholders, subtle divider backgrounds |

### Typography & Neutrals
| Token Name | Hex Code | Flutter (`AppColors`) | Usage |
| :--- | :--- | :--- | :--- |
| **Charcoal Black (Primary)** | `#2D2926` | `AppColors.textPrimary` | Primary headings, button labels on gold, body text, form labels |
| **Secondary Charcoal** | `#525252` | `AppColors.textSecondary` | Subtitles, secondary metadata, user handles |
| **Muted Slate Grey** | `#737373` | `AppColors.textMuted` | Timestamps, placeholder text, inactive icons |
| **Subtle Border** | `#E5E5E5` | `AppColors.border` | Card borders, dividers, inactive input outlines |
| **Focused Border** | `#FFB700` | `AppColors.borderFocused` | Active text field outline, selected item border |

### Semantic System Colors
| Semantic | Hex Code | Flutter (`AppColors`) | Usage |
| :--- | :--- | :--- | :--- |
| **Success** | `#22C55E` | `AppColors.success` | Toast successes, completed watches, checkmarks |
| **Error** | `#EF4444` | `AppColors.error` | Validation errors, delete actions, failed sync |
| **Warning** | `#F59E0B` | `AppColors.warning` | Rewatch indicators, sync pending alerts |
| **Info** | `#3B82F6` | `AppColors.info` | Information banners, series season indicators |

---

## ♿ 3. Accessibility & Contrast Standards

> [!IMPORTANT]
> ### The Golden Contrast Rule
> All text and icons placed over **Honey Gold (`#FFB700`)**, **Warm Cream (`#FFF9F0`)**, or **Pure White (`#FFFFFF`)** must be **Charcoal Black (`#2D2926`)** or pure black (`#000000`).  
> **NEVER use white, yellow, or light grey text over light or gold backgrounds.**

### Strict Accessibility Guidelines
1. **Buttons**:
   - Primary CTA button (solid `#FFB700`): Label text must be `#2D2926` or `#000000` with `FontWeight.w700` or `w800`.
   - Secondary button (outlined): Border `#E5E5E5`, text `#2D2926`.
2. **Touch Targets**:
   - Minimum interactive area: `44 x 44 dp` (e.g. icon buttons, action pills, QR code triggers).
3. **Form Controls & Toggles**:
   - Switches / Checkboxes ("Post to Feed", "Rewatch"): When active, track is `#FFB700`, label is `#2D2926`.
   - Inactive: `#E5E5E5` border with `#525252` label.
4. **Form Inputs**:
   - Input text: `#2D2926`.
   - Placeholder text: `#737373` (WCAG AA 4.5:1 on `#FFF3E0` and `#FFFFFF`).
   - Focus outline: 1.5px solid `#FFB700`.

---

## 🔤 4. Typography Scale & Specifications

**Primary Typeface**: `Inter` (Clean geometric grotesque sans-serif with excellent numerals and micro-legibility).

```
Display / Hero      26px - 28px   Bold (w900)      -0.5px letter-spacing  (Story titles, Splash)
Heading 1 (H1)      20px - 22px   ExtraBold (w800) -0.3px letter-spacing  (Screen AppBars, Modal Titles)
Heading 2 (H2)      16px - 18px   Bold (w700)       0.0px letter-spacing  (Section headers, Card titles)
Heading 3 (H3)      14px - 15px   SemiBold (w600)   0.0px letter-spacing  (Sub-headers, user display names)
Body Regular        14px          Regular (w400)    1.45 line-height      (Reviews, summaries, bios)
Body Medium         13px - 14px   Medium (w500)     1.35 line-height      (Secondary labels, descriptions)
Captions / Meta     11px - 12.5px SemiBold (w600)   0.2px letter-spacing  (Release years, timestamps, tags)
Micro Badges        9px - 10.5px  ExtraBold (w900)  0.5px letter-spacing  (SERIES, MOVIE, TASTE chips)
```

---

## 🧱 5. Component Blueprint & UI Patterns

### 1. Buttons (`WHButton`)
- **Primary Action**: Solid `#FFB700` fill, rounded corners `14px–16px`, height `48px–52px`, `FontWeight.w800`, `#2D2926` text. Built-in progress spinner for async state.
- **Outlined / Secondary**: Background transparent, border `1.5px solid #E5E5E5`, text `#2D2926`, `FontWeight.w700`.
- **Ghost / Icon Button**: Circular background `Colors.black.withValues(alpha: 0.55)` for floating backdrop buttons, or transparent for AppBars.

### 2. Cards & Containers (`WHFeedCard`, `WHEntryGridCard`)
- **Border Radius**: `16px–20px`.
- **Border**: `1px solid #E5E5E5`.
- **Shadow**: Subtle ambient elevation:
  ```dart
  boxShadow: [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ]
  ```
- **Poster Aspect Ratio**: Always **2:3** for movie and TV posters (`childAspectRatio: 0.65` in grids).

### 3. Star Ratings & Pictorial Scoring
WatchersHive tracks entries on a **10-point scale** (e.g., `8.5 / 10`) mapped visually into **5 honey-gold stars**:
- Full star: `score >= index` (`Icons.star_rounded`, color: `#FFB700`).
- Half star: `score >= index - 0.5` (`Icons.star_half_rounded`, color: `#FFB700`).
- Empty star: `Icons.star_outline_rounded` (color: `#FFB700` with 30% opacity).
- Accompanied by a bold numeric rating badge: `★ 8.5 / 10`.

### 4. Bottom Sheets & Modal Drawers
- **Top Corner Radius**: `24px–28px`.
- **Drag Handle**: Centered capsule `40px x 4px`, color `#2D2926` with `0.20` opacity.
- **Header**: Left-aligned bold title, right-aligned circular close button.
- **Content Padding**: `20px` horizontal, `16px` vertical.

### 5. In-App Guidance & Screen Guides
Every major screen (Feed, Search, Entries, Movie Details, Profile) features a **Screen Guide button (`?`)** in the top-right AppBar action position:
- Icon: `Icons.help_outline_rounded`, size `20px`.
- On tap: Opens [`ScreenGuideDialog`](file:///Users/adityadasamantharao/Documents/Repos/watchhive_mobile/lib/features/onboarding/widgets/screen_guide_dialog.dart) displaying screen-specific onboarding, feature highlights, and walkthroughs.

### 6. Instagram & Social 9:16 Story Cards (`InstagramStoryCard`)
- **Aspect Ratio**: Exact **9:16** (`1080 x 1920` logical preview / 3.0x high-res PNG export).
- **Background**: Gaussian-blurred backdrop bleed (`sigmaX: 20, sigmaY: 20`) with dark cinematic gradient mesh and warm golden ambient orb glows.
- **Poster Container**: Elevated 2:3 poster with glowing 1.5px gold border and drop shadow.
- **Branding**: Official `WHBrandLogo` at top with `🍿 JUST WATCHED` / `📺 WATCHING` badge.
- **Bottom Callout**: High-contrast Hive QR code + `watchershive.com/m/:id` deep link pill.

### 7. Floating Toast Alerts (`WHAlert`)
- Positioned as a floating top/bottom toast banner.
- Border radius: `16px`.
- High contrast, tinted with semantic severity color (`success`, `error`, `warning`, `info`).
- Supports trailing actions (e.g. `"Share Story"`, `"Undo"`).

---

## 📳 6. Haptic Feedback & Tactile Delight

WatchersHive incorporates precise tactile haptics to give interactions a physical, high-craft sensation:
- **Tab Selection / Chip Tap**: `HapticFeedback.selectionClick()`
- **Button Press / Rating Change**: `HapticFeedback.lightImpact()`
- **Watch Completed / Story Generated**: `HapticFeedback.mediumImpact()`
- **Critical Action / Delete**: `HapticFeedback.heavyImpact()`

---

## 📐 7. Spacing, Radii & Grid System

```
Spacing Scale:
  xxs:  4px   (tight icon-text spacing, micro badges)
  xs:   8px   (chip padding, inline items)
  sm:  12px   (card internal item gaps)
  md:  16px   (standard screen edge padding, card padding)
  lg:  20px   (section spacing, modal horizontal padding)
  xl:  24px   (major block spacing)
  xxl: 32px   (screen bottom padding)

Corner Radii:
  sm:   6px   (micro tags, media type chips)
  md:  10px   (poster image thumbnails, input fields)
  lg:  14px–16px (standard cards, primary buttons)
  xl:  20px–22px (hero containers, dialog cards)
  pill: 999px (badges, filter chips, action pills)
  sheet: 24px–28px (top corners of bottom sheets)
```

---

## ⚠️ 8. Future Agent & Designer Checklist (Rules of Engagement)

When building or modifying UI in WatchersHive, ensure compliance with these non-negotiables:

1. [ ] **Color Check**: Did you use `AppColors.primary` (`#FFB700`) for actions and `AppColors.background` (`#FFF9F0`) for backgrounds?
2. [ ] **Contrast Check**: Is all text appearing on gold or cream surfaces set to `AppColors.textPrimary` (`#2D2926`) or `#000000`? (Never use white or yellow on cream!).
3. [ ] **Typography**: Are all custom fonts using `Inter`?
4. [ ] **Screen Guide (`?`)**: Does your new main screen or flow have a `ScreenGuideDialog` trigger in the top right corner of the AppBar?
5. [ ] **Interactive Targets**: Are all tappable icons and buttons at least `44 x 44 dp`?
6. [ ] **Haptics**: Did you add appropriate light or selection haptic feedback to the primary action?
7. [ ] **Loading States**: Did you provide a shimmer skeleton (`WHSkeleton`) or `WHAppLogoLoader` instead of generic spinners?
8. [ ] **Deep Links**: Does social sharing use clean `watchershive.com/m/:id` routes?
