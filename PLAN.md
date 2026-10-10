# Hastify — Build Plan

Goal: Home Screen widget showing today's in-person Apple Pay spend. Free, sideloaded, built without a Mac.

How it works: Wallet tap → Shortcuts **Transaction** automation (Run Immediately) → app's **Log Spend** App Intent → JSON in App Group → widget reloads. Widget zeroes itself at midnight.

## Phase 1 — Get a build green (PC only)
- [ ] `git init`, commit scaffold, create **public** GitHub repo (`gh repo create hastify --public --source . --push`). Public = unlimited free macOS minutes.
- [ ] Watch Actions run (`gh run watch`). Fix compile errors until `Hastify.ipa` artifact uploads.
- [ ] Known risk: xcodebuild output path, XcodeGen Info.plist defaults, ad-hoc `codesign` step.

## Phase 2 — Get it on the phone (free Apple ID)
- [ ] Install SideStore on iPhone (one-time pairing from PC via its Windows setup tool / iloader).
- [ ] Download `Hastify.ipa` (`gh run download`), AirDrop/Files → install via SideStore.
- [ ] Enable SideStore background refresh (7-day signing).
- [ ] Add Hastify widget to Home Screen.

## Phase 3 — Wire the automation (one-time, ~1 min)
- [ ] Shortcuts → Automation → + → Transaction → all cards → Run Immediately.
- [ ] Action: **Log Spend** — Amount / Merchant / Card ← Shortcut Input fields.

## Phase 4 — Verify on device
- [ ] Tap-to-pay once → entry appears in app, widget total updates (may lag minutes).
- [ ] App Group works after SideStore re-sign (widget shows same total as app). If widget shows 0 while app shows taps → debug `ALTAppGroups` fallback in `Shared/SpendStore.swift`.
- [ ] Check amount format arriving from Shortcuts (number vs "$12.34") — parser handles both.
- [ ] Next day: confirm midnight reset.
- [ ] Apple Watch tap: does trigger fire?

## Phase 5 — Nice-to-haves (after MVP works)
- [ ] Ignore transit taps (merchant filter in app settings).
- [ ] Manual add button (cash / missed taps).
- [ ] Weekly total + daily budget bar on widget.
- [ ] Lock Screen widget polish.

## Risks
| Risk | Mitigation |
|---|---|
| Trigger flaky (timeouts, amount=0) | Intent skips zero; manual delete/add in app |
| App Group renamed by SideStore | `ALTAppGroups` fallback (untested) |
| 7-day expiry | SideStore background refresh; data survives |
| No Mac to debug | Logs via Actions build output; on-device testing only |
