# footertext.koplugin - Design Spec

## Summary

A standalone KOReader plugin that renders a configurable text label centered at the bottom of the reading screen, independent of the status bar. Uses the same format tokens as the sleep screen message (`%c`, `%t`, `%T`, etc.). Default format: `"Page %c"`.

The label remains visible even when the status bar is hidden, and repositions vertically when the status bar toggles on/off.

## Plugin Identity

- **Name:** `footertext`
- **Directory:** `plugins/footertext.koplugin/`
- **Type:** `is_doc_only = true` (reader context only)
- **Files:**
  - `main.lua` - plugin class, widget rendering, event handlers, token expansion
  - `_meta.lua` - plugin metadata

## Format Token System

Reuses the same tokens as the sleep screen message, implemented as a self-contained `expandTokens()` function within the plugin (not calling into the Screensaver module, since we're always in an active reader context and don't need sidecar fallback logic).

### Tokens

| Token | Value | Source |
|-------|-------|--------|
| `%T` | Document title | `self.ui.document:getProps().display_title` |
| `%A` | Author(s) | `self.ui.document:getProps().authors` |
| `%S` | Series (with index) | `self.ui.document:getProps().series` + `series_index` |
| `%c` | Current page number | `self.ui.view.state.page` (respects hidden flows) |
| `%t` | Total pages | `self.ui.document:getPageCount()` (respects hidden flows) |
| `%p` | Percentage read (0-100) | Calculated from `%c / %t` |
| `%h` | Time left in chapter | Via `self.ui.document` reading stats |
| `%H` | Time left in document | Via `self.ui.document` reading stats |
| `%b` | Battery level | `powerd:getCapacity()` |
| `%B` | Battery symbol | `powerd:getBatterySymbol()` |

### Hidden Flows

For documents with hidden flows (EPUBs with non-linear content), `%c`, `%t`, and `%p` use flow-aware variants:
- `self.ui.document:getPageNumberInFlow(page)`
- `self.ui.document:getTotalPagesInFlow(flow)`

This matches the behavior of the status bar's `page_progress` mode.

### Page Labels (Stable Page Numbers)

When `self.ui.pagemap` exists and `self.ui.pagemap:wantsPageLabels()` returns true, `%c` uses `self.ui.pagemap:getCurrentPageLabel(true)` instead of the raw page number. This respects the user's "Stable page numbers" setting.

## Widget Architecture

### Structure

```
WidgetContainer (FooterText, registered as view module)
└── BottomContainer (positions content at screen bottom)
    └── CenterContainer (horizontally centers the text)
        └── TextWidget (renders the formatted string)
```

### Registration

Registered as a ReaderView view module:
```lua
self.ui.view:registerViewModule("footertext", self)
```

View modules are painted after the footer in ReaderView's `paintTo()`, so this layers on top if overlap occurs.

### Positioning

The `BottomContainer`'s `dimen.h` controls vertical position:

- **Footer visible:** `screen_height - footer_height - vertical_offset`
- **Footer hidden:** `screen_height - vertical_offset`

This places the text at the same vertical baseline as status bar text by default (offset=0), dropping to the screen bottom when the status bar is hidden.

## Settings

All persisted via `G_reader_settings`.

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `footertext_enabled` | boolean | `true` | Show/hide the label |
| `footertext_format` | string | `"Page %c"` | Format string with tokens |
| `footertext_font_size` | integer | (matches footer) | Font size in pixels |
| `footertext_font_face` | string | (matches footer) | Font face name |
| `footertext_vertical_offset` | integer | `0` | Pixels upward from baseline position |

### Font Defaults

The default font size and face are read from the ReaderFooter instance at init time:
- Size: `self.ui.view.footer.settings.text_font_size`
- Face: `self.ui.view.footer.settings.text_font_face`

If the user has not set custom values, these are read from the footer's current settings at plugin init time (not dynamically tracked).

## Event Handlers

| Event | Action |
|-------|--------|
| `onPageUpdate(page)` | Re-expand tokens, repaint |
| `onPosUpdate(pos)` | Re-expand tokens, repaint (rolling/scroll mode) |
| `onReaderFooterVisibilityChange` | Recalculate vertical position, repaint |
| `onSetDimensions` | Update screen dimensions, recalculate layout |
| `onCloseDocument` | Cleanup |

## Menu Integration

Added to the reader menu (bottom status bar section) as a submenu:

**"Footer text"** submenu containing:
1. **Enable/disable** - checkbox toggle
2. **Edit format string** - `InputDialog` with info button showing token reference
3. **Font size** - `SpinWidget` spinner
4. **Vertical offset** - `SpinWidget` spinner (pixels, can be negative)

## Painting

The `paintTo(bb, x, y)` method:
1. Returns immediately if `footertext_enabled` is false
2. Expands the format string with current token values
3. Updates the TextWidget text if changed
4. Delegates to the BottomContainer's `paintTo()` which handles positioning

Repainting is triggered by calling `UIManager:setDirty(self.ui, "ui")` after token values change (page turn, footer visibility change).

## File Layout

```
plugins/footertext.koplugin/
├── _meta.lua    -- name, fullname, description
└── main.lua     -- FooterText class (~200-250 lines)
```

Single-file plugin (main.lua) since the logic is straightforward. No separate menu or token modules needed.
