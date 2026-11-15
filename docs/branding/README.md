# Bruce artwork

The app uses Bruce’s established illustrated country-butler portrait, supplied for this
branding update. `bruce-portrait.png` is the canonical, unmodified 1254 × 1254 source.
It contains no household photographs or identifying property details.

- Standard: the portrait, without lettering or extra badges.
- Full Bruce: the same portrait with a gold edge (`#FFCB18`).
- iOS: opaque square artwork; the system applies the final mask.
- macOS: rounded artwork inset by 10%, with transparent outer padding.

Regenerate every asset on macOS from the repository root:

```sh
swift scripts/generate-brand-icons.swift
```

`--carplay-only` regenerates only the existing CarPlay sizes. No asset names,
catalogue slots, runtime selection logic or app functionality change.

The [contact sheet](icon-preview.png) shows the committed iOS and Mac variants at
large and small sizes. Regenerated PNG bytes may differ by renderer; dimensions,
alpha handling, portrait framing and variant treatment should remain consistent.
