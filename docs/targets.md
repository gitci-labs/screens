# Targets

Targets are data, not renderer logic. The built-in catalog currently includes the canonical high-resolution App Store targets:

- `appstore.iphone.6_9.portrait`: `1320x2868`
- `appstore.ipad.13.portrait`: `2064x2752`
- `appstore.mac.16_10`: `2880x1800`

The accepted size lists follow Apple App Store Connect's screenshot specification reference. `displayGapPx` is not an upload requirement; it is an empirical preview/splitting value used when a single scene spans multiple App Store screenshot cards.

Verified against Apple's App Store Connect screenshot specification reference on 2026-05-23:

- iPhone 6.9-inch portrait accepts `1320x2868`, `1290x2796`, and `1260x2736`.
- iPad 13-inch portrait accepts `2064x2752` and `2048x2732`.
- Mac accepts 16:10 screenshots including `2880x1800`, `2560x1600`, `1440x900`, and `1280x800`.

Reference: <https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications>

Scene span math:

```text
(N * W + (N - 1) * G) / H >= R
N = ceil((R * H + G) / (W + G))
```

Where:

- `W`: target screenshot width
- `H`: target screenshot height
- `G`: preview gap between screenshot cards
- `R`: scene template minimum aspect ratio
- `N`: number of screenshot assets the scene spans
