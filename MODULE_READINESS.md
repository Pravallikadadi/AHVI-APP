# AHVI Module Readiness

## Demo Priority

The May 1 demo should lead with:

- Login as the demo user.
- Chat and style mode through the backend `/api/text` route.
- Wardrobe-aware styling with seeded wardrobe data.
- Optional visual intelligence only after `/api/wardrobe/capture/analyze` passes a real env smoke test.

## Environment Gate

Before the demo, fill `.env` with:

- Appwrite endpoint, project id, database id.
- Collection ids for outfits, users, saved boards, skincare, workout outfits, bills, coupons, meds, med logs, meal plans, life goals, and plans.
- `EXPO_PUBLIC_BACKEND_API_URL` pointing at the running FastAPI backend.

The `.env` file is intentionally a blank scaffold in this workspace. Do not put R2, RunPod, Anthropic, or other secret keys in Flutter.

## Module Checklist

| Module | Entry | Data Source | AI Context | Demo Status | Notes |
| --- | --- | --- | --- | --- | --- |
| Chat | `lib/chat.dart` | Backend `/api/text` | `widget.moduleContext` | Show | Uses normalized backend response. |
| Style Sheet | `lib/widgets/ahvi_stylist_chat.dart` | Backend `/api/text` | screen-specific | Show | Backend first, local fallback. |
| Daily Wear | `lib/daily_wear.dart` | Backend `/api/text` | `style` | Show | Direct Anthropic removed. |
| Wardrobe | `lib/wardrobe.dart` | Appwrite + backend vision | `wardrobe` | Show | `userId` first, `user_id` fallback. |
| Bills | `lib/bills_page.dart` | AppwriteService | `bills` | Show as UI/Data | AHVI sheet uses backend. |
| Skincare | `lib/skincare.dart` | AppwriteService + backend chat | `skincare` | Show as UI/Data | Direct Anthropic removed. |
| Calendar | `lib/calendar.dart` | Local plans + backend chat | `calendar` | Show as UI | Chat uses backend first, local save logic retained. |
| Diet | `lib/diet_page.dart` | Local plans + backend chat | `diet` | Show as UI | Backend first, deterministic plan fallback retained. |
| Fitness | `lib/fitness_page.dart` | Local outfits + backend chat | `fitness` | Show as UI | Backend first, local fallback retained. |
| Medi Tracker | `lib/medi_tracker.dart` | AppwriteService | `medi` | Show as UI/Data | AHVI sheet uses backend. |
| Boards | `lib/boards.dart` | AppwriteService/backend boards | `boards` | Show as UI/Data | Needs manual route smoke. |
| Profile | `lib/profile.dart` | Local/ProfileController/Appwrite auth | none | Show | Avoid delete-account flow during demo. |
| Onboarding/Signin | `lib/signin.dart`, onboarding screens | Appwrite auth | none | Show | Requires real Appwrite env. |

## Manual Smoke Script

1. Start backend with real Appwrite env and `AUTH_REQUIRED=true`.
2. Run the Flutter app with filled `.env`.
3. Login as the demo user.
4. Open each module from navigation.
5. Confirm empty state and seeded-data state.
6. Send one AHVI prompt in every module with an assistant button.
7. Create/delete only disposable demo data.

## Known Guardrails

- Appwrite direct calls remain short-term for speed.
- Backend-owned `/api/data/*` migration should happen after the demo.
- Visual upload is optional unless RunPod/R2/Appwrite env is tested live.
- Do not demo account deletion.
