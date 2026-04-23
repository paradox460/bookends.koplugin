# Bookends 4.3.0 — release notes

## New: radial progress bar styles

Two new styles — filled radial (pie chart) and hollow radial (donut) — alongside the existing metro, wavy, solid, rounded, and bordered styles. Both fill clockwise from 12 o'clock, honour chapter ticks, and respect the custom colour slots. Thanks to [@paradox460](https://github.com/paradox460) for the contribution.

## New: basic colour support on colour e-ink devices

Every colour setting now opens a curated palette picker (5×5 swatches plus a free-form `#RRGGBB` / `#RGB` hex input) instead of the greyscale percent nudge. Applies live as you tap; **Cancel** reverts, **Default** clears the field.

Inline hex colour tags in format strings work too — a line like `[c=#FF0000]WARNING[/c] %k` paints WARNING in red. Short-form CSS hex (`[c=#F00]`) is accepted.

Presets that use colour are marked with a small four-stripe flag in the top-right of their card in the Preset Library.

On greyscale devices the picker is hidden — the existing `% black` nudge is unchanged, and colour values in shared presets render as luminance.

## Changed: "Symbol color" renamed to "Icon color"

Better reflects what it actually affects — Nerd Font / FontAwesome icon glyphs, not arbitrary Unicode symbols. Existing settings and translations still work; only the on-screen label has changed.

## No visual change for existing users

Legacy presets render pixel-identically. Only presets explicitly authored with hex values show colour on colour-capable hardware.

---

## Known limitations

- Bookends colour only affects overlay text and icon glyphs — book body text goes through KOReader's own rendering and isn't affected.
- Kaleido colour-filter output is hardware-specific; the curated palette aims for saturated-enough CSS values, but fine-tune via the hex input if a colour looks muddier or brighter than expected on your device.
