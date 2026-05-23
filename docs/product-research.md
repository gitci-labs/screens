# Product Research Notes

Last reviewed: 2026-05-23.

## Current Market Signals

Best-in-class screenshot tools are converging on a few workflow promises:

- Design once, export every store/device/locale. AppScreens emphasizes responsive layouts, 150+ template sets, 500+ editable layouts, App Store/Google Play exports, localization, and direct App Store Connect / Google Play publishing: https://appscreens.com/
- Screenshot Pilot, LocalizeShots, Appure, Shotlingo, and LaunchShot all position localization and batch export as core workflow accelerators, not premium edge cases.
- Newer AI-first tools such as MagicScreenshots and Storeshots are pushing fast first drafts, headline generation, palette extraction, and screenshot reordering. GitCI Screens should use those ideas as optional helpers later, while keeping source-controlled deterministic output as the durable product advantage.
- Localization is a primary buying reason, not an edge feature. AppScreens, Screenshot Pilot, LocalizeShots, MakeAppShots, and several recent indie tools all lead with multi-language export because text expansion, repeated manual exports, and locale folder organization are the pain.
- Recent tools such as Appshots Studio, Screenshot Pilot, ScreenCraft, and Bezel Studio are positioning the workflow as raw screenshots to polished localized assets, often covering both App Store and Google Play sizes. Several now mention AI-assisted captions/layout ideas and preview-video reuse, which reinforces the value of making scenes animation-ready without making animation part of static screenshot generation yet.
- AI is being used for first-draft marketing copy, palette extraction, screenshot ordering, translation, and dynamic backgrounds. These are useful accelerators, but the durable value is deterministic regeneration from project state.
- CI and App Store Connect integration are differentiators for serious teams. Fastlane remains the automation baseline: `snapshot` captures raw app screenshots, `frameit`/`frame_screenshots` prepares framed assets, and `deliver`/ASC upload workflows expect predictable `fastlane/screenshots/<locale>/...` layout. The current Fastlane docs still describe `./fastlane/screenshots` as the default iOS screenshots location, so GitCI Screens should keep export paths unsurprising.
- Users want fast iteration across product-page experiments. AppScreens explicitly calls out custom product pages and product page optimization variants. GitCI Screens should treat scene set variants as first-class build outputs, not just editor options.
- Apple's App Store Connect screenshot specs and product-page optimization docs keep the need for data-driven target profiles, first-three screenshot ordering, and screenshot/app-preview experiments current: https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications and https://developer.apple.com/app-store/product-page-optimization/

## Product Implications For GitCI Screens

GitCI Screens should win by being reproducible and developer-native:

- Keep the source of truth in `gitci/screens`, not a proprietary cloud canvas.
- Make CLI/Docker/GitHub Actions output the same assets as the GUI.
- Keep every generated asset traceable to scene set, target, locale, slot, variant, and commit.
- Prefer responsive scene templates over hand-maintained per-device canvases.
- Make localization/pseudo-localization part of validation because text length breaks screenshot layouts before most other things.
- Keep Fastlane export and future App Store Connect upload paths boring and standard.

## Near-Term Priorities

1. Add visual overflow detection on top of the current `qps-overflow` long-string stress locale.
2. Improve variant groups into a reviewable experiment surface: all-groups validation, grouped Fastlane roots, and first-three gallery badges are in place; next add ZIP naming and custom product page packaging conventions.
3. Add direct App Store Connect upload as an optional exporter after the Fastlane layout is stable.
4. Improve gallery previews into a review surface: target tabs, locale tabs, first-three screenshot emphasis, and split-scene reconstruction with display gaps.
5. Add GUI import/build flow on macOS before editing: local directory bookmark, discovery, build button, gallery preview, reveal/share output.

## Guardrails

- Do not execute arbitrary remote template code in a privileged browser context.
- Do not store private screenshots, paid frames, fonts, or GLBs in public repos.
- Do not make AI-generated copy a dependency for deterministic builds.
- Do not hardcode store dimensions in renderer code; load target profiles as data.
