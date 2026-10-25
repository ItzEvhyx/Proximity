# DESIGN.md: Proximity UI Redesign

> Instructions for the AI agent redesigning the **Proximity** Flutter app (Philippine commute companion).
> **Scope: visual redesign only.** Features, navigation structure, screen flow, data layer (Firebase / Cloud Firestore), Mapbox integration, and business logic stay exactly as they are. Do not add, remove, or rename features. Restyle what exists.

---

## 1. Goal

Proximity currently uses a green + white palette. Redesign it into a **modern, dark, monochrome** interface using **black, grays, and white only**, with **frozen / liquid glass** surfaces on appropriate floating elements (search bar, top bars, floating buttons, sheets).

The reference mood is a premium dark "flight tracker" style app: a desaturated grayscale map in the background, with dark rounded cards, pill-shaped controls, and big clean typography floating on top. Secondary reference: a minimalist dark gym tracker with large numerals, dot-grid visuals, and lots of breathing room.

### Design principles

1. **Monochrome only.** No green, blue, red, or any hue. Hierarchy comes from lightness, size, weight, and spacing, not color.
2. **Map is the hero.** Keep the map visible and let UI float over it.
3. **Pills and soft geometry.** Large radii, circular icon buttons, segmented pill tabs.
4. **Glass for floating, solid for content.** Glass on things that float over the map; solid dark cards for dense information.
5. **Big numbers, small labels.** Data (fares, ETAs, distances) is large and light; labels are small and muted.
6. **Calm and uncluttered.** Remove decorative elements that don't carry information.

---

## 2. Color System

Strictly grayscale. Define everything as tokens in one place (e.g. `lib/core/theme/app_colors.dart`) and **replace every hardcoded color in the codebase** with these tokens.

| Token | Hex | Usage |
|---|---|---|
| `bg` | `#101010` | App background, scaffold |
| `surface` | `#1A1A1A` | Large sheets, bottom sheets |
| `surfaceRaised` | `#2C2C2C` | Cards, tiles, inputs, inactive circular buttons |
| `surfaceHigh` | `#3A3A3A` | Pressed states, dividers on raised surfaces |
| `border` | `#FFFFFF` @ 8% | Hairline borders on solid surfaces |
| `textPrimary` | `#FFFFFF` | Headings, key numbers, active labels |
| `textSecondary` | `#B3B3B3` | Body, secondary labels |
| `textMuted` | `#7A7A7A` | Hints, placeholders, captions, disabled text |
| `onLight` | `#101010` | Text/icons on white pills and buttons |
| `mapGray` | `#4A4A4A` to `#8A8A8A` | Grayscale map land/water/roads (see Map) |

### Gradients (grayscale only)

Gradients are allowed but **must be white/gray only**. No color grading, no tinted gradients.

- **Primary CTA gradient** (replaces any green/colored button): `#FFFFFF` to `#BDBDBD`, top-left to bottom-right, with `#101010` text/icon.
- **Subtle surface gradient** (optional, large cards): `#2C2C2C` to `#1A1A1A`, top to bottom.
- **Glass sheen**: `#FFFFFF` @ 14% to `#FFFFFF` @ 4% (see Glass spec).
- **Progress / route line**: white to `#8A8A8A` fade (solid portion white, remaining portion dashed `#8A8A8A`).

### Semantic states without color

Since no hue is allowed, express state through form:

- **Active / selected**: white fill with dark text (pill) or white circle with dark icon.
- **Inactive**: `surfaceRaised` fill with `textSecondary`.
- **Success / confirmed**: white check icon, filled-white dot.
- **Warning / delay / error**: bold white text plus an icon (e.g. alert triangle) and, if needed, a dashed or double border. Never red.
- **Disabled**: 40% opacity.

**Migration rule:** search the entire project for every green shade (`Colors.green*`, `Color(0xFF...)` greens, theme `primary`/`secondary`, gradients, icon tints, map markers, polyline colors, shadows) and replace with the tokens above.

---

## 3. Typography

**Keep the app's existing font pairing. Do not introduce any new typeface.**

- **Poppins**: headers and display text (screen titles, card titles, hero numbers, large station/route codes).
- **Inter**: subtext and body text (body copy, labels, captions, hints, metadata, inputs, buttons' small text).
- Both are already in use in the app, so reuse the current setup (`google_fonts` or bundled files). Set them in `ThemeData.textTheme` so no widget falls back to the default font.

| Style | Font | Size / Weight | Use |
|---|---|---|---|
| `display` | Poppins | 48 / Light (300) | Hero numbers (fare, ETA) |
| `title` | Poppins | 28 / Medium (500) | Screen titles |
| `headline` | Poppins | 20 / Medium (500) | Card titles, route names |
| `code` | Poppins | 20 to 32 / Medium (500), tabular figures | Large station/route codes (e.g. `LRT-1`) |
| `body` | Inter | 15 / Regular (400) | General text |
| `label` | Inter | 13 / Regular (400) | Row labels (e.g. "Scheduled") |
| `caption` | Inter | 11 / Regular (400) | Hints, metadata, `textMuted` |

Rules:
- Use **tabular figures** (`FontFeature.tabularFigures()`) for fares, times, distances.
- Large numerals are Poppins Light, with small muted Inter unit text beside them (e.g. big fare number, small `₱` or unit).
- Letter spacing: default for body, +0.5 for `caption` and uppercase labels.

---

## 4. Shape, Spacing, Elevation

- **Spacing scale:** 4, 8, 12, 16, 20, 24, 32. Screen horizontal padding: 16.
- **Radii:**
  - Pills / search bars / segmented tabs / CTAs: fully rounded (`999`)
  - Cards / info tiles: `24`
  - Bottom sheets: `32` top corners
  - Small chips / tags: `999`
  - Circular icon buttons: 44 to 48 px diameter
- **Elevation:** avoid heavy Material shadows. Use hairline borders + very soft shadow on floating glass only (`black @ 35%`, blur 24, offset `(0, 8)`).
- **Dividers inside cards:** 1px `#FFFFFF` @ 6%. Info cards can use a **grid of cells** separated by hairlines (like the origin/destination and scheduled/actual table in the reference).
- **Touch targets:** minimum 44x44.

---

## 5. Liquid / Frozen Glass Spec

Use glass **only** for elements that float above the map or content:

- Search bar (primary glass element)
- Top floating bars / back-button chips / route header pill
- Floating map controls (zoom +/-, compass, locate-me)
- Bottom navigation bar container
- Overlay sheets / toasts / dialogs where it doesn't hurt legibility

**Do not** use glass on dense content cards (fare tables, lists); those stay solid `surfaceRaised` for readability.

### Recipe (Flutter)

Layer order, bottom to top:

1. `ClipRRect` with the element's radius
2. `BackdropFilter` with `ImageFilter.blur(sigmaX: 18, sigmaY: 18)`
3. `Container` with tint fill: `Colors.white` @ 8 to 12% (use `#101010` @ 45% when over a bright area for contrast)
4. **Gradient sheen** overlay: top-left `#FFFFFF` @ 14% to bottom-right `#FFFFFF` @ 3%
5. **Border**: 1px gradient stroke, `#FFFFFF` @ 35% (top-left) to `#FFFFFF` @ 6% (bottom-right) to fake a light edge
6. Optional inner highlight: 1px line at the top edge, `#FFFFFF` @ 20%
7. Soft outer shadow (see Elevation)

```dart
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.radius = 999,
    this.blur = 18,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.tint = 0.10,
  });

  final Widget child;
  final double radius;
  final double blur;
  final EdgeInsets padding;
  final double tint;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(tint + 0.04),
                  Colors.white.withOpacity(tint - 0.07),
                ],
              ),
              border: GradientBoxBorder( // or a CustomPainter / stacked containers
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.35),
                    Colors.white.withOpacity(0.06),
                  ],
                ),
                width: 1,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
```

Notes:
- Create this **once** as a shared widget (`GlassContainer`) and reuse it everywhere. Do not duplicate blur code.
- If `GradientBoxBorder` isn't available, use the `gradient_borders` package or a stacked `Container` (outer gradient, inner 1px inset).
- Optional: the `liquid_glass_renderer` package can be evaluated for a more refractive "liquid" look; fall back to the recipe above if it hurts performance or compatibility.
- **Performance:** `BackdropFilter` is expensive. Keep it to a handful of simultaneous instances on screen, avoid placing it inside scrolling list items, and wrap in `RepaintBoundary` where appropriate. Never nest glass inside glass.
- **Legibility:** glass text/icons are `textPrimary` white; make sure contrast holds over the lightest part of the grayscale map. Increase dark tint if not.

---

## 6. Map

- Switch the Mapbox style to a **grayscale / desaturated dark style** (a custom Mapbox Studio style, or a built-in dark/monochrome style with all hue removed).
  - Land: `#5A5A5A`-ish mid-gray; water: darker `#3A3A3A`; roads: lighter gray lines; labels: white at reduced opacity; buildings subtle.
  - Remove all colored layers (green parks, blue water, orange highways).
- **Markers:** white filled circle/icon with dark glyph. Selected/user location: larger white dot with soft white halo (`white @ 20%` ring).
- **Route polyline:** completed/active portion solid white, remaining portion dashed `#8A8A8A`, with small white origin/destination dots and **pill labels** (dark `#101010` pill, white code text, e.g. station name) at the ends.
- **Vehicle / transit icon** (when shown on route): solid white glyph with slight shadow.
- **Controls:** zoom +/- as a stacked vertical glass pill; compass as a small circular glass or `#101010` button; locate-me as a circular glass button. Place on the right edge above the bottom sheet.

---

## 7. Component Specs

### 7.1 Search bar (hero glass element)
- Full-width floating pill, height 56, 16px from screen edges, below the safe area.
- Frozen glass (Section 5). Leading search icon (white, 22px), placeholder in `textMuted`, trailing filter/tune icon in a subtle circular area.
- Focus state: border sheen brightens (35% to 55%), no color change.
- Applies to the "Sakay" AI route search entry as well; keep its function and just restyle it.

### 7.2 Segmented pill tabs
- Container: rounded pill, `surfaceRaised` (or glass over map).
- Active segment: **white pill, `#101010` text**, medium weight. Inactive: `textSecondary` on transparent.
- Animate the white pill sliding between segments (200 to 250 ms, `easeOutCubic`).
- Use this for any existing tab/toggle UI (e.g. switching between views or categories).

### 7.3 Bottom sheet / info panel
- Dark `surface` (`#1A1A1A`), 32px top radius, slight overlap with the map, drag handle (36x4, `white @ 20%`).
- Contains segmented tabs at the top, then solid `surfaceRaised` info cards.
- **Info card grid:** two-column cells separated by 1px hairlines for paired data (origin to destination, scheduled vs. actual, etc.). Each cell: big station/route code in `display` or `headline`, small muted label below.
- Center a small circular `#101010` badge with an icon between paired cells (like the plane icon in the reference), e.g. a transit icon between origin and destination.

### 7.4 Primary CTA button
- Full-width pill (or flex-fill next to a circular secondary button), height 56.
- Fill: **white-to-light-gray gradient** (`#FFFFFF` to `#BDBDBD`), text/icon `#101010`, medium weight.
- Pressed: scale 0.98, darken gradient slightly.
- Secondary / tertiary actions: circular 48px `surfaceRaised` button with white icon (e.g. share), or outlined pill with `border` color.
- Use this for actions like enabling stop-proximity alerts.

### 7.5 List items (routes, stops, fares)
- Solid `surfaceRaised` card, 24px radius, 16px padding.
- Route row: small circular badge (white icon on `#101010`), route code in `code` style, origin to destination as large codes on left/right with a thin line + small icon between them showing progress (white progress segment, gray remainder).
- Trailing chips: small `#101010` pills with `caption` text (e.g. line/vehicle type).
- 12px gap between cards.

### 7.6 Bottom navigation
- Floating glass bar (or solid `#101010`), pill-shaped, inset 16px from edges and bottom safe area.
- Icons only (outlined, 24px), `textSecondary` when inactive.
- Active item: **white filled circle (48px) with `#101010` icon**, animated scale/slide.
- Keep the same destinations and order as the current app.

### 7.7 Top bar / route header
- Floating glass pill with back arrow (left), route/title in `headline` with a muted subtitle (e.g. "Origin to Destination", codes highlighted in white, rest in `textSecondary`), overflow menu (right).
- No Material `AppBar` color fills; use transparent scaffold with floating elements.

### 7.8 Fare matrix (LRT-1 / LRT-2 / MRT-3)
- Solid dark cards, dense table styled with hairline-divided cells.
- Fares as large Light numerals with small `₱` prefix in `textMuted`.
- Line selector uses segmented pill tabs (7.2).
- Highlight the selected origin/destination cell with a white outline or white-filled cell with dark text.

### 7.9 Data visuals (optional polish, reuse existing data only)
- Where a history/streak/frequency visual makes sense (e.g. trips taken), use a **dot-grid** style: small gray dots (`#3A3A3A`), filled-white dots for active entries, a hollow white ring for "today". Only add if it replaces an existing visual; do not invent new features.

### 7.10 Inputs, chips, dialogs, snackbars
- Text fields: `surfaceRaised`, pill or 16px radius, no underline, white cursor, `textMuted` hint.
- Chips: pill, `surfaceRaised`; selected = white fill + dark text.
- Dialogs / sheets: glass or `surface` with 28px radius; destructive actions use bold white text + icon (no red).
- Snackbars/toasts: floating glass pill at the bottom above the nav.
- Switches/checkboxes/sliders: white thumb/check on `surfaceHigh` track; active track `#BDBDBD`.

### 7.11 Icons
- One consistent **outlined, rounded** icon set (e.g. Lucide / Phosphor / Material Symbols Rounded, weight ~400). Stroke white or `textSecondary`. No multicolor icons.
- Replace any colored illustrations/SVGs with monochrome versions (white or gray).

### 7.12 Splash, onboarding, empty & loading states
- Splash/onboarding: `#101010` background, white wordmark/logo, optional faint gray radial gradient glow (`#2C2C2C` to `#101010`).
- Update the **app icon and logo** to a monochrome (white on black) version.
- Loading: skeleton shimmer in `surfaceRaised` to `surfaceHigh`; spinners in white.
- Empty states: muted outlined icon, `headline` text, one-line `textSecondary` description, optional white pill CTA.

---

## 8. Motion

- Durations: 150 to 250 ms for micro-interactions, 300 to 400 ms for sheet and page transitions.
- Curves: `easeOutCubic` for entrances, `easeInOutCubic` for toggles.
- Sheets spring up with slight overshoot; tab pill slides; nav active circle scales in.
- Keep motion subtle. No bouncing or flashy effects.
- Respect "reduce motion" (`MediaQuery.disableAnimations`).

---

## 9. Theme Implementation (Flutter)

1. Create `AppColors`, `AppTextStyles`, `AppRadii`, `AppSpacing`, and `AppTheme` under `lib/core/theme/`.
2. Build a single **dark** `ThemeData` (`useMaterial3: true`, `brightness: Brightness.dark`) with:
   - `scaffoldBackgroundColor: AppColors.bg`
   - `colorScheme`: `primary: white`, `onPrimary: #101010`, `surface: AppColors.surface`, `onSurface: white`, `secondary: #BDBDBD`, `outline: border`
   - `textTheme`: Poppins for display/title/headline, Inter for body/label/caption
   - Themed `bottomSheetTheme`, `inputDecorationTheme`, `chipTheme`, `dialogTheme`, `snackBarTheme`, `switchTheme`, `iconTheme`, `dividerTheme`, `navigationBarTheme`
3. Set status/navigation bar to transparent with **light** icons (`SystemUiOverlayStyle.light`) and use edge-to-edge.
4. Build reusable widgets: `GlassContainer`, `PillTabs`, `PrimaryButton`, `CircleIconButton`, `InfoCard`, `RouteCard`, `GlassSearchBar`, `MapControls`, `SheetHandle`.
5. Remove or replace any light-theme code paths. The app is dark-only unless a light theme already exists, in which case ask before removing.

---

## 10. Agent Workflow

1. **Audit first.** List all screens, widgets, and every place color/typography is defined (search for `Color(`, `Colors.`, `TextStyle(`, `ThemeData`, gradients, Mapbox style URL, SVG/PNG assets with colors).
2. **Build the foundation**: theme tokens, Poppins + Inter text theme, `GlassContainer`, shared components.
3. **Restyle screen by screen**, starting with the map/home screen (search bar, controls, bottom sheet), then route/stop details, fare matrix, Sakay AI search, settings, onboarding.
4. **Swap the map style** to grayscale and recolor markers/polylines.
5. **Replace assets** (icons, logo, illustrations) with monochrome versions.
6. **Final sweep**: grep for leftover green or any non-gray hex values and fix them.
7. Run `flutter analyze` and test on a real device or emulator (glass/blur performance, contrast, small screens).

### Hard constraints
- Do not change app logic, routing, state management, API calls, or Firestore schema.
- Do not add new features or screens.
- Do not introduce any hue. Everything must be a gray from `#000000` to `#FFFFFF`.
- Keep layouts responsive (small phones to large) and respect safe areas.
- Keep accessibility: text contrast at least 4.5:1 (7:1 for small text on glass if possible), semantic labels on icon-only buttons.

### Definition of done
- [ ] Zero green (or any non-gray) colors remain in code, assets, or map style
- [ ] Poppins (headers) and Inter (body/subtext) applied app-wide, no other fonts
- [ ] Search bar and floating controls use the shared glass component
- [ ] Gradients, where present, are white/gray only
- [ ] Map is grayscale with white markers and a white/gray route line
- [ ] Segmented pill tabs, circular nav indicator, and white-gradient CTA are used consistently
- [ ] All existing features work exactly as before
- [ ] `flutter analyze` is clean and scrolling and map interaction stay smooth with blur enabled

---

## 11. Reference Notes (from the provided images)

- **Palette**: `#101010` (base), `#2C2C2C` (cards), `#FFFFFF` (accents). The reference also has a green-blue gradient CTA; **do not copy it**. Use the white-to-gray gradient instead.
- **Font**: the reference uses Kanit, but **ignore it**. Proximity keeps Poppins for headers and Inter for subtext/body.
- **Layout pattern**: floating dark pill search bar on top of a grayscale map, a rounded dark bottom panel with pill tabs, a hairline-divided info grid, a full-width gradient CTA beside a circular share button, and a bottom nav with a white circle on the active item.
- **Gym tracker reference**: large light numerals with small muted units, calm dark cards, dot-grid calendar visuals, subtle icon-only controls on cards.
