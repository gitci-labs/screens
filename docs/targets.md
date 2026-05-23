# Targets

Targets are data, not renderer logic. The built-in catalog currently includes the canonical high-resolution App Store targets:

- `appstore.iphone.6_9.portrait`: `1320x2868`
- `appstore.ipad.13.portrait`: `2064x2752`
- `appstore.mac.16_10`: `2880x1800`

The accepted size lists follow Apple App Store Connect's screenshot specification reference. `displayGapPx` is not an upload requirement; it is an empirical preview/splitting value used when a single scene spans multiple App Store screenshot cards.

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
