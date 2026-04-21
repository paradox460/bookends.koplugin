# Bookends 4.2.0 — release notes

## New: metro progress bar has a visible read portion

A new **Metro read color** setting (under Colors → Progress bar colors and tick marks) paints the part of the metro trunk the reader has passed in a distinct colour, recolours the chapter ticks already reached, and applies the same colour to the start-cap ring. Metro's track colour is preserved as before.

When unset (default), metro renders identically to 4.1.0 — no visual change for existing users.

The setting is also available per-bar, under Progress bars → Bar N → Colors → Metro read color, so individual bars can use different metro read colours. Existing presets continue to work unchanged; they simply lack the new field and fall back to the uniform-trunk rendering.

## New: halos behind ReaderFlipping icons

KOReader's top-left status icons — the page-flip indicator, bookmark-flip dog-ear, highlight-select marker, long-hold cue, and the CRe re-render spinner — now paint over a page-coloured halo with a thin grey border. The icon is repainted on top so it stays legible when a Bookends overlay or full-width progress bar would otherwise sit underneath and clash with the line-art glyph.

The halo is drawn from a UIManager-level toast so it survives other view modules painting after Bookends, and is suppressed automatically when a fullscreen widget (TouchMenu, TOC) is open.

## New: Bulgarian localisation

Complete Bulgarian (bg_BG) translation, 464/464 strings. Thanks to @d0nizam.

## Fix: missing-font crash

A latent crash when a configured font failed to load at the freetype level — surfacing as `font.lua:386` errors when `getAdjustedFace` was called with a nil face — is now avoided by falling back to the default `cfont` face during overlay measurement and config lookup.
