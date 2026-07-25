# App Store Release & TestFlight Deployment Checklist

## Overview
This document provides the step-by-step release checklist for deploying `PhalanxDuelClient` (`game-swiftui`) to TestFlight and promoting it to the Apple App Store for commercial availability.

---

## 1. App Store Connect & Identity Setup
- [x] **Bundle Identifier**: Registered `com.phalanxduel.client` in Apple Developer Portal.
- [x] **App Record**: Created `Phalanx Duel` application entry in App Store Connect.
- [x] **Privacy Manifest**: Included `PrivacyInfo.xcprivacy` with zero required reason API declarations (no tracking, privacy-preserving client architecture).

---

## 2. In-App Purchase & StoreKit Configuration
- [x] **Local StoreKit Testing**: `PhalanxStore.storekit` created and wired into scheme.
- [x] **In-App Products in App Store Connect**:
  - `com.phalanxduel.supporter_pass_v1` (Non-Consumable, $4.99)
  - `com.phalanxduel.skin_cyber_spades` (Non-Consumable, $2.99)
  - `com.phalanxduel.battle_pass_monthly` (Auto-Renewable Subscription, $1.99/mo)
- [x] **Server Receipt Verification**: Endpoint `POST /api/store/verify-purchase` operational on game server.

---

## 3. TestFlight Beta Distribution
- [x] **Archive Packaging Script**: Run `bin/archive-app.sh` to verify zero build errors.
- [x] **Build Upload**: Export `.xcarchive` or upload via Xcode (`Organizer -> Distribute App -> TestFlight & App Store`).
- [x] **Beta Groups**:
  - Internal QA Testers (Immediate access).
  - External Early Access Testers (Public TestFlight link).

---

## 4. Final App Store Submission Verification
- [x] Native card render fidelity verified (`PhxCardView`).
- [x] Tactical combat outcome banners verified (`CombatBannerView`).
- [x] CoreHaptics & audio feedback engine verified (`HapticAndAudioEngine`).
- [x] In-app cosmetic store & Founder pass purchase flow verified (`StoreView`).
- [x] Global ladder & player career dashboard verified (`LeaderboardView`, `ProfileView`).
- [x] Live ranked matchmaking queue UI verified (`MatchmakingQueueView`).
- [x] Turn-by-turn replay inspection viewer verified (`ReplayViewer`).
- [x] Friend & community activity feed verified (`SocialFeedView`).

---

## 5. Automated Build Command
To generate the production release archive locally:
```bash
bash bin/archive-app.sh
```
