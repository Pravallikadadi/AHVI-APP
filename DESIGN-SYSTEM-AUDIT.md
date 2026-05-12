# AHVI Design System Audit

_Audit date: 2026-05-09 — read-only._

## Summary

- **Files scanned:** 44 `.dart` files under `lib/` (excluding `lib/theme/` and `lib/services/`); 7 theme files and 6 widget files read in full as the source-of-truth baseline.
- **Tokens defined:** 12 color tokens (semantic) + 11 named color constants in `BaseTheme` + 3 accent colors per palette × 3 palettes; **4 gradients**; **0 spacing tokens**; **0 radius tokens**; **0 typography tokens** (only color is set in `TextTheme`, no sizes/weights).
- **Total token-violation occurrences:** roughly **3,950** raw literal usages that should be tokenized:
  - Hardcoded `Color(0x...)` — **485**
  - Hardcoded `Color.fromRGBO(...)` — **9**
  - `Colors.X` Material constants — **430** (213 white, 118 transparent, 84 black, plus 15 reds/ambers)
  - `TextStyle(...)` literals — **882**
  - `EdgeInsets.*` literals — **836**
  - `BorderRadius.circular(...)` literals — **776**
  - `fontSize:` literals — **617**
  - `fontWeight:` literals — **601**
  - `SizedBox(width|height: N)` literals — **782**
  - `withValues(alpha: ...)` ad-hoc opacity tweaks — **814**
- **Score: 38 / 100.** The theme system has a solid color-token foundation (`AppThemeTokens` ThemeExtension is well-designed and used in 23 of ~30 visual files), but the system stops at color. There are no spacing, radius, or typography tokens, so 95%+ of layout / typography decisions are made with bare numerics in feature files. Three feature files (`wardrobe.dart` 6.4k LOC, `home.dart` 5.1k LOC, `chat.dart` 4.3k LOC) hold the bulk of violations and contain hundreds of inline `TextStyle`s and `BorderRadius.circular(N)` calls. Component library is thin (6 widgets, mostly screen-level shells, not primitives like `AhviButton`/`AhviCard`/`AhviTile`). Accessibility is largely missing: 0 `Semantics(...)` wrappers, 0 image `semanticLabel`s, 1 tooltip across 30 files.

A score above 70 would require: (a) spacing/radius/typography tokens added to `AppThemeTokens`, (b) primitive components (`AhviButton`, `AhviCard`, `AhviTextField`), (c) baseline a11y instrumentation.

---

## 1. Source of Truth (Theme System)

`lib/theme/` is 7 files, ~330 LOC total. Inventory:

### Tokens (in `theme_tokens.dart` via `AppThemeTokens` ThemeExtension)
| Token | Type | Notes |
|---|---|---|
| `backgroundPrimary` | Color | scaffold-level bg, lerped with accent |
| `backgroundSecondary` | Color | secondary surface |
| `textPrimary` | Color | body text |
| `mutedText` | Color | secondary text |
| `panel` | Color | translucent panel |
| `panelBorder` | Color | panel border |
| `card` | Color | card surface |
| `cardBorder` | Color | card border, lerped with accent |
| `phoneShell` | Color | phone-mockup outer |
| `phoneShellInner` | Color | phone-mockup inner |
| `tileText` | Color | tile label color |
| `accent` | `AccentPalette` | nested: `primary`, `secondary`, `tertiary` |

Accessed via `context.themeTokens` extension — clean ergonomics.

### Base color constants (`base_theme.dart`)
11 named constants: `darkBgPrimary`, `darkBgSecondary`, `darkText`, `darkPhoneShell`, `darkPhoneShellInner`, `lightBgPrimary`, `lightBgSecondary`, `lightText`, `lightMuted`, `lightPhoneShell`, `lightPhoneShellInner`. These power `BaseTheme.light` / `BaseTheme.dark` `ThemeData`.

### Accent palettes (`accent_palette.dart`)
3 hardcoded palettes: `coolBlue`, `sunsetPop`, `futureCandy`. Each has `primary`, `secondary`, `tertiary`. Switched at runtime via `ProfileTheme` enum and `ThemeController`.

### Gradients (`gradients.dart`)
4 functions: `mainBackground`, `glowPrimary`, `glowSecondary`, `glowTertiary`. All radial glows hardcode `alpha: 0.35` and pair with `Colors.transparent`.

### Runtime / persistence
`theme_controller.dart`, `theme_provider.dart`, `theme_storage.dart` — `ChangeNotifier` + `SharedPreferences` for ThemeMode + ProfileTheme. Note duplication: both `ThemeController` and `ThemeProvider` exist and both read/write `'themeMode'` SharedPreferences key — stale code; pick one.

### GAPS (the bar this audit measures against)
- **No spacing tokens.** No `s4`, `s8`, `s12`, etc. Every `EdgeInsets`/`SizedBox` is a literal.
- **No radius tokens.** No `radiusSm`/`radiusMd`/`radiusLg`/`radiusPill`. Every `BorderRadius.circular(N)` is a literal.
- **No typography tokens.** `BaseTheme.light/dark` only set `color` on five `TextTheme` slots (`bodyLarge`, `bodyMedium`, `bodySmall`, `titleMedium`, `titleSmall`) — no `fontSize`, no `fontWeight`, no `height`, no `letterSpacing`. Effectively every screen builds its own `TextStyle` from scratch.
- **No elevation/shadow tokens.** Shadows are inlined as `BoxShadow(color: x.withValues(alpha: 0.10), blurRadius: 28, offset: Offset(0, 6))` etc.
- **No motion tokens.** Durations/curves (`Duration(milliseconds: 200)`, `Curves.easeOutCubic`) are inlined.
- **No semantic accent roles.** `accent.primary`/`secondary`/`tertiary` are positional, not role-named (e.g., "interactive", "info", "success"). There is no danger/warning/success token at all — `Colors.redAccent`/`Color(0xFFB71C1C)` is hardcoded for the "listening mic" state in `ahvi_chat_prompt_bar.dart`.
- **Duplication between `ThemeController` and `ThemeProvider`.** Both notify on theme mode changes, both persist to the same SharedPreferences key.

---

## 2. Token Coverage

### Colors

| Pattern | Count | Top files (count) |
|---|---|---|
| `Color(0xFF...)` | 485 | `fitness_page.dart` (71), `onboarding3.dart` (61), `onboarding2.dart` (58), `signin.dart` (50), `diet_page.dart` (41), `onboarding1.dart` (42), `profile.dart` (31), `boards.dart` (30), `bills_page.dart` (21) |
| `Color.fromRGBO(...)` | 9 | `onboarding2.dart` (1); the rest live inside `theme_tokens.dart` (legitimate) |
| `Colors.white` | 213 | `wardrobe.dart`, `home.dart`, `chat.dart` lead |
| `Colors.transparent` | 118 | broadly distributed (legitimate in many cases — clip layers, gesture detectors) |
| `Colors.black` | 84 | mostly shadow boxes |
| `Colors.redAccent` | 6 | `ahvi_chat_prompt_bar.dart`, error states |
| `Colors.red` | 5 | error states |
| `Colors.amber` | 1 | one-off |

**Findings:**
- Five files (`fitness_page`, `onboarding1-3`, `signin`) account for **252 of 485** raw `Color(0xFF...)` literals — onboarding+signin are the design-system-coldest area, likely because they predate the tokens.
- `Colors.white` at 213 occurrences is the single biggest violation. Most should be `t.card`, `t.panel`, or `t.tileText` (for icon colors on accent surfaces). Inside light theme, `card`/`panel` already resolve to white but with proper alpha — direct `Colors.white` breaks dark mode.
- `Colors.black` is almost always used as `Colors.black.withValues(alpha: 0.x)` for shadows (~80 of 84 occurrences). Should be a `shadowColor` token.
- The "listening mic" red gradient `[Colors.redAccent, Color(0xFFB71C1C)]` (`ahvi_chat_prompt_bar.dart:204-205`) is the only non-accent-palette gradient in shared widgets — should become `tokens.danger` / `tokens.recording`.

**Recommendations:**
1. Add `dangerPrimary`, `dangerSecondary`, `success`, `warning` semantic colors to `AppThemeTokens`.
2. Add a `shadowColor` token (single source for all `BoxShadow.color`).
3. Add `iconOnAccent` (for white icons on top of accent backgrounds — currently `Colors.white` and `Color(0xFF1A1A2E)`).
4. Re-audit onboarding screens; they are the worst offenders and look like they were written before the theme system.

### Typography

| Pattern | Count | Top files |
|---|---|---|
| `TextStyle(...)` literal | 882 | `bills_page.dart` (82), `wardrobe.dart` (86), `profile.dart` (69), `medi_tracker.dart` (68), `home.dart` (65), `chat.dart` (45), `fitness_page.dart` (60), `diet_page.dart` (58) |
| `fontSize:` | 617 | follows the same distribution |
| `fontWeight:` | 601 | follows the same distribution |

**fontSize value distribution (top values):**
| Size | Occurrences |
|---|---|
| 13 | 133 |
| 11 | 122 |
| 12 | 107 |
| 10 | 72 |
| 14 | 70 |
| 15 | 54 |
| 18 | 25 |
| 16 | 22 |
| 20 | 20 |
| 22 | 19 |

**fontWeight distribution:**
| Weight | Occurrences |
|---|---|
| `w600` | 192 |
| `w700` | 181 |
| `w500` | 73 |
| `w400` | 51 |
| `w800` | 41 |
| `w900` | 27 |
| `w300` | 27 |
| `bold` (alias) | 1 |

**Findings:**
- The codebase uses **20+ distinct fontSize values** (8, 9, 10, 10.5, 11, 11.5, 12, 12.5, 13, 13.5, 14, 14.5, 15, 16, 17, 18, 20, 22, 24, 26, 28, ...). Half-step values (11.5, 13.5) suggest pixel-pushing rather than a scale.
- No file reads `Theme.of(context).textTheme.X` for `fontSize`/`fontWeight` — the existing `TextTheme` slots are essentially ignored.
- All 7 weights (`w300`–`w900`) appear, but ~70% of weights are `w600`/`w700`, suggesting the rest are noise.

**Recommended type scale (inferred from real usage):**
```
caption      11 / 1.3   w400 / w500
captionStrong 11 / 1.3  w700
body         13 / 1.4   w400
bodyStrong   13 / 1.4   w600
label        14 / 1.3   w600
title        18 / 1.2   w700
heading      22 / 1.1   w800
display      28 / 1.0   w900
```
Eight slots covers ~90% of current hits. Extend `BaseTheme.light/dark` `TextTheme` (or add an `AppTextStyles` ThemeExtension) to expose these.

### Spacing

| Pattern | Count |
|---|---|
| `EdgeInsets.*` | 836 |
| `SizedBox(width|height: N)` | 782 |

**Most-used SizedBox values:** 8 (134), 10 (113), 12 (85), 6 (65), 14 (53), 4 (46), 16 (41), 2 (35), 5 (31), 7 (27), 3 (24), 20 (22), 9 (20), 24 (13), 18 (12).

**Most-used EdgeInsets shapes:** `only(bottom: 8)` (17), `all(16)` (13), `all(12)` (11), `only(bottom: 10)` (10), `all(14)` (10), `symmetric(vertical: 13)` (9), `only(right: 8)` (9), `all(4)` (9), `all(8)` (8), `fromLTRB(16, 0, 16, 16)` (8).

**Recommended spacing scale (inferred):**
```
s2  = 2
s4  = 4
s6  = 6
s8  = 8     ← most common
s10 = 10
s12 = 12
s14 = 14
s16 = 16    ← page padding
s20 = 20
s24 = 24
s32 = 32
```
The "off-grid" 5/7/9/11/13 values (collectively ~120 occurrences) appear in nudge-padding for borders/icons. Either consolidate to nearest even value or accept them as a sub-step (`s5`, `s7`, `s9`).

### Radii

| Pattern | Count |
|---|---|
| `BorderRadius.circular(N)` | 776 |

**Most-used radii:**
| Value | Count | Suggested name |
|---|---|---|
| 12 | 78 | `radiusMd` |
| 16 | 73 | `radiusLg` |
| 14 | 62 | `radiusMd+` |
| 20 | 61 | `radiusXl` |
| 10 | 61 | `radiusSm+` |
| 100 | 33 | `radiusPill` |
| 18 | 27 | (drop or merge with 16/20) |
| 50 | 21 | `radiusPill` |
| 13 | 18 | (consolidate to 12 or 14) |
| 8 | 17 | `radiusSm` |
| 24 | 17 | `radius2xl` |
| 999 | 13 | `radiusPill` |
| 22 | 11 | (consolidate to 20 or 24) |

**Findings:** 12, 14, 13, 10, 11 are functionally interchangeable but spelled differently across files — a textbook tokenization opportunity. Three different "pill" spellings (50, 100, 999) all mean the same thing.

**Recommended radius scale:**
```
radiusXs  = 4
radiusSm  = 8
radiusMd  = 12
radiusLg  = 16
radiusXl  = 20
radius2xl = 24
radiusPill = 999
```

---

## 3. ThemeData Adoption

**Files reading the theme** (`Theme.of(context)` or `context.themeTokens`): 23 of ~30 visual files.

**Files NOT reading the theme** despite heavy styling:
| File | Hardcoded `Color(0xFF...)` count | Notes |
|---|---|---|
| `lib/onboarding1.dart` | 42 | onboarding flow, all colors hardcoded |
| `lib/onboarding2.dart` | 58 | same |
| `lib/onboarding3.dart` | 61 | same |
| `lib/signin.dart` | 50 | sign-in flow, all colors hardcoded |
| `lib/profile.dart` | 31 | defines its own internal `ThemeColors` class — bypasses the system |
| `lib/splash_screen.dart` | 11 | splash; arguably acceptable |
| `lib/widgets/ahvi_chat_prompt_bar.dart` | 2 | accepts colors as constructor params instead of reading tokens directly — over-pluggable |
| `lib/widgets/ahvi_lens_sheet.dart` | 0 | accepts `AppThemeTokens t` as a param — workable but verbose |
| `lib/widgets/offline_image.dart` | 1 | one hardcoded fallback color |
| `lib/style_board/board_renderer.dart` | 3 | rendering layer; partly excused |

**Two structural anti-patterns:**
1. **`profile.dart` defines its own `ThemeColors` class** (line near top of file). This is a parallel, undocumented theme system that the rest of the app cannot see.
2. **Shared widgets in `lib/widgets/` accept color props instead of reading `themeTokens` directly.** `AhviChatPromptBar` declares 8 separate `Color` parameters (`surface`, `border`, `accent`, `accentSecondary`, `textHeading`, `textMuted`, `shadowMedium`, `onAccent`) plus `themeTokens`. Every consumer has to wire all of these by hand — defeats the purpose of having tokens.

---

## 4. Component Completeness

`lib/widgets/` (6 widgets) + `lib/style_board/` shared (`saved_board_thumb`, `editorial_board_widgets`).

| Component | Docs | States | Variants | A11y | Score |
|---|---|---|---|---|---|
| `AhviHeader` | yes (good doc block) | static (no states) | `showBack`, `right`, `showBorder`, `frosted` | back button has 20px icon, no `Semantics` label, no tooltip | **6/10** |
| `AhviHomeText` | none | static | `color`, `fontSize`, `letterSpacing`, `fontWeight` | tappable but no `Semantics`, no tooltip; min size unknown | **4/10** |
| `AhviChatPromptBar` | none | press / hover / listening (mic) | 3 internal buttons, compact mode | no `Semantics` on the 3 buttons; 38×38 hit area = below 48dp | **4/10** |
| `AhviLensSheet` | none | overlay open/dismiss | none | tap-outside dismiss; no `Semantics` on tiles, no focus trap | **3/10** |
| `AhviStylistChat` (3.5k LOC, screen-level not a primitive) | minimal | many | many; really a screen | no `Semantics` | **3/10** |
| `OfflineImage` | none | loading / error | `fit`, `alignment`, `errorBuilder`, `placeholderBuilder`, `fadeInDuration` | **no `semanticLabel` parameter at all** — every cached image is invisible to screen readers | **3/10** |
| `style_board/saved_board_thumb` | none | static | none | no a11y | **3/10** |
| `style_board/editorial_board_widgets` | none | static | several | no a11y | **3/10** |

**Findings:**
- No primitive component library. There is no `AhviButton`, `AhviCard`, `AhviTile`, `AhviTextField`, `AhviChip`, or `AhviModalSheet`. Every screen rolls its own. This is the largest single contributor to the violation count: each screen reproduces the same card/button/tile patterns from scratch, each time with slightly different padding/radius/text style.
- 0 of 6 widgets wrap their tappable elements in `Semantics`. 0 expose a `semanticLabel`-style param.
- `AhviChatPromptBar` is duplicating press-state logic (`_ChatPromptPressable`) that should be a shared `AhviPressable` primitive — `AhviStylistChat` and `home.dart` re-implement the same press-scale animation.

**Recommended additions:**
- `AhviButton` (primary / secondary / ghost; sm / md / lg)
- `AhviCard` (with `panel`/`card`/`accent` variants, default radius from tokens)
- `AhviTile` (icon + title + subtitle + trailing — used everywhere in home/wardrobe/profile)
- `AhviPressable` (extract press-scale logic)
- `AhviTextField` (consolidate the 5+ TextField patterns in chat / wardrobe / signin / profile)
- `AhviSectionHeader` (title + optional action — repeated in wardrobe, boards, profile)

---

## 5. Naming Consistency

- **File naming.** All 44 audited Dart files are `snake_case.dart`. ✅ Clean.
- **Class naming — `Ahvi*` prefix.** Only **8 of 100 public classes** start with `Ahvi`, all in `lib/widgets/` (`AhviHeader`, `AhviHomeText`, `AhviChatPromptBar`, `AhviLensSheet`/`showAhviLensSheet`, `AhviStylistChat` and a couple of helpers). Screen classes drop the prefix (`HomeUtilitiesScreen`, `OfficeFitScreen`, `ContactsScreen`, `ProfileScreen`, etc.). This is OK as a convention if articulated ("`Ahvi*` = shared component, `*Screen` = route-level"), but it isn't articulated anywhere. Document it in `lib/widgets/README` or as a doc comment in `theme_tokens.dart`.
- **Token naming.** Mixed.
  - Surface tokens are named by role (`backgroundPrimary`, `panel`, `card`, `phoneShell`) — good.
  - Text tokens use a mix: `textPrimary` (good) vs `tileText` (component-specific, leaks the implementation) vs `mutedText` (states "muted" rather than role).
  - Accent palette uses positional names (`primary`/`secondary`/`tertiary`) instead of semantic roles. Result: every consumer has to know which palette slot serves which intent — a screen using `accent.tertiary` for "info" ties it to whatever `tertiary` happens to be in `coolBlue` vs `sunsetPop`.
  - Base constants in `BaseTheme` (`darkBgPrimary`, `lightPhoneShellInner`) duplicate what's in tokens, but with a different naming convention (camelCase prefix) — ideally `BaseTheme` should be private, only `AppThemeTokens` exposed.
- **Profile theme names.** `coolBlue`, `sunsetPop`, `futureCandy` are descriptive but not consistent in style (one color name + adjective + meaningless word). Minor.

---

## 6. Accessibility

**Hard numbers across `lib/`:**
- `Semantics(...)` widget instances: **0** in non-theme files (the search returned 0 matches).
- `semanticLabel:` usage on `Image`/`Icon`: **0**.
- `tooltip:` on `IconButton` / `IconTheme`: **1** (in `chat.dart`).
- `IconButton(...)`: 7 occurrences across 5 files. Most icon-tap interactions are custom `GestureDetector`s instead.
- `GestureDetector(...)`: **272** — many of these wrap small targets without enforcing minimum hit area.

**Touch-target findings:**
- `AhviChatPromptBar`: the plus / mic / send circles are `width: 38, height: 38` (`ahvi_chat_prompt_bar.dart:143-144, 198-199, 255-256`). WCAG 2.5.5 AAA wants 44×44pt; Material wants 48×48dp. Below standard.
- `AhviLensSheet` `_LensTile` rows: roughly 44dp tall (10px top + 10px bottom + ~24px content), borderline OK, but the inner icon is 20×20 with no extra hit padding.
- `AhviHeader` back button: a 20px icon inside `EdgeInsets.only(right: 8)` — total target ~28×28. Below standard.

**Image accessibility:**
- `OfflineImage` has no `semanticLabel` parameter at all. Every avatar / wardrobe item / board thumbnail in the app is therefore unannounced to screen readers. This is the single highest-leverage a11y fix.

**Color contrast (theme-token level):**
- Light: `textPrimary = #1A1D26` on `card = #FFFFFF` → ~16:1. ✅
- Light: `mutedText = #66708A` on `card = #FFFFFF` → ~4.6:1. ✅ (just above 4.5:1 AA for normal text)
- Light: `mutedText = #66708A` on `backgroundPrimary` (≈ `#E2EAF8` lerped 5% with accent) → ~3.9:1. ⚠ Below 4.5:1 AA for body text. Recommend darkening `lightMuted` to ~`#566180`.
- Dark: `mutedText = rgba(230,235,255,0.72)` on `darkBgPrimary = #08111F` — alpha-blends to roughly `#A6AFD0`, ~7:1. ✅
- Dark: `tileText = #10131B` on `panel = rgba(255,255,255,0.08)` over a dark bg — `panel` is essentially still dark, so dark text on dark panel is roughly **2:1**. ❌ Failing AA. Either remove `tileText` from dark theme paths or lighten it for dark mode.
- Light: `phoneShellInner = #EEF3FF` paired with `mutedText = #66708A` → ~4.4:1. ⚠ Just under AA for normal body text.
- Light: `cardBorder` is `lerp(#CDD5F0, accent.primary, 0.25)` — fine for borders (no text contrast requirement) but flag if used for hairline icons.
- The "listening" red gradient `[Colors.redAccent #FF5252, #B71C1C]` with white icon: ~5.3:1. ✅

**Recommendations:**
1. Add `semanticLabel` param to `OfflineImage`, plumb through 50+ call sites — biggest single a11y win.
2. Wrap interactive `GestureDetector`s in `Semantics(button: true, label: ...)` (or migrate to `Material` `InkWell` / `IconButton` which already do this).
3. Bump tap targets in `AhviChatPromptBar` to 44×44 (current 38×38).
4. Fix the dark-mode `tileText` contrast issue.
5. Lighten or darken `lightMuted` to clear AA on `backgroundPrimary` and `phoneShellInner`.

---

## 7. Priority Actions (top 5)

1. **Add a typography ThemeExtension (~8 named styles).** Replaces ~882 inline `TextStyle(...)` literals across 32 files. Highest impact: every screen does its own type, and 70% of fontSize/fontWeight pairs cluster on ~8 actual values. Effort: ~1 day to define + iterative migration. Suggested API: `context.appText.body`, `context.appText.title`, etc., or extend `TextTheme` and use `Theme.of(context).textTheme.titleLarge!`.

2. **Add spacing + radius tokens to `AppThemeTokens`.** Replaces ~836 `EdgeInsets`, ~782 `SizedBox`, and ~776 `BorderRadius.circular(...)` literals — collectively the largest violation block (≈2,400 occurrences). The data above gives you the scale (s4/s8/s12/s16/s24/s32 + radiusXs/Sm/Md/Lg/Xl/Pill). Effort: ~half a day to add tokens, then incremental migration. Even partial migration dissolves dozens of "is it 12 or 14 here?" decisions.

3. **Build a primitive component library: `AhviButton`, `AhviCard`, `AhviTile`, `AhviTextField`, `AhviPressable`.** This is the structural fix that prevents recurrence — without primitives, every new screen will re-introduce literals. The 6.4k-line `wardrobe.dart`, 5.1k `home.dart`, 4.3k `chat.dart` would each shrink by 30–40%. The press-scale animation in `_ChatPromptPressable` is already duplicated in 3+ places and is the obvious first extraction. Effort: 3–5 days for the primitive set, then an ongoing refactor.

4. **Plumb `semanticLabel` through `OfflineImage` (and add `Semantics` wrappers around the 6 shared widgets).** Single biggest a11y improvement: every cached image in the app is currently invisible to screen readers, and 0 of the 6 shared widgets expose accessibility labels. Touch-target bumps on `AhviChatPromptBar` (38→44dp) ride along on the same change. Effort: 1 day for `OfflineImage` + widgets, 1–2 days to thread labels through the 50+ call sites.

5. **Migrate onboarding + signin + profile off raw `Color(0xFF...)` and delete `profile.dart`'s private `ThemeColors`.** Five files (`onboarding1.dart`, `onboarding2.dart`, `onboarding3.dart`, `signin.dart`, `profile.dart`) hold **242 of the 485** raw color literals (49%) and don't read `themeTokens` at all. `profile.dart` even ships a parallel `ThemeColors` class that is invisible to the rest of the app. Effort: ~2 days; quick wins per file.

---

## 8. What Works Well

- **`AppThemeTokens` ThemeExtension is well-structured.** Implements `copyWith` and `lerp` correctly, supports smooth theme transitions, accent-aware (lerps surface colors with the active accent palette so the whole UI shifts when the user switches profile theme). The `context.themeTokens` extension keeps call sites short.
- **The accent-palette + profile-theme system is genuinely clever.** Three named palettes pluggable at runtime, persisted to SharedPreferences, integrated into both light and dark variants. Few small Flutter codebases bother with this.
- **23 of ~30 visual files do read the theme.** Adoption is real, not aspirational — the gap is in *what* the theme exposes (only colors), not in whether the theme is connected.
- **File naming is 100% consistent (`snake_case.dart`).**
- **Color tokens cover surfaces well.** `panel`, `card`, `phoneShell`, `phoneShellInner` distinguish usefully between surface depths — most design systems stop at one or two surface tokens.
- **Static-by-design header (`AhviHeader`).** The doc block explicitly explains why it's a `StatelessWidget` and uses `MediaQuery.sizeOf` instead of `MediaQuery.of` to avoid keyboard-driven rebuilds. Solid engineering, well-commented.
- **Gradient helpers live in `gradients.dart` and take an `AccentPalette` argument.** Right shape — they consume tokens rather than re-defining colors.
- **Light/dark mode is implemented end-to-end** (controller, storage, persistence, theme extension lerping), which is more than many Flutter apps in the wild.
