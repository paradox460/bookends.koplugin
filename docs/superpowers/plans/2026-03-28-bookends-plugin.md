# Bookends Plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a KOReader plugin that renders configurable text overlays at 6 screen positions with token expansion, smart ellipsis overlap prevention, and a Nerd Font icon picker.

**Architecture:** Four Lua modules — token expansion engine, widget renderer with overlap prevention, icon picker UI, and main plugin class (settings/events/menu). The main class registers as a ReaderView view module and paints overlays via `paintTo`. Each position has an independent format string; a shared token engine expands `%`-tokens at paint time.

**Tech Stack:** Lua 5.1 (KOReader runtime), KOReader widget framework (TextWidget, VerticalGroup, containers), G_reader_settings for persistence, Nerd Font PUA codepoints for icons.

**Spec:** `docs/superpowers/specs/2026-03-28-customoverlay-plugin-design.md`

---

## File Structure

```
plugins/bookends.koplugin/
├── _meta.lua          -- plugin metadata
├── main.lua           -- Bookends class: init, settings, events, menu, paintTo
├── tokens.lua         -- expandTokens(format_str, ui) → string
├── overlay_widget.lua -- buildPositionWidgets(), overlap prevention, coordinate calc
└── icon_picker.lua    -- showIconPicker(callback) → inserts glyph via callback
```

| File | Responsibility | Depends on |
|------|---------------|------------|
| `_meta.lua` | Plugin name/description for KOReader loader | nothing |
| `tokens.lua` | Pure function: takes format string + ui reference, returns expanded string | KOReader APIs (document, toc, powerd) |
| `overlay_widget.lua` | Creates TextWidgets per position, measures, truncates for overlap, computes coordinates, paints | `tokens.lua`, KOReader TextWidget/VerticalGroup |
| `icon_picker.lua` | Shows scrollable icon list, calls back with selected glyph | KOReader Menu widget |
| `main.lua` | Plugin lifecycle, settings load/save, event handlers, menu tree, delegates painting to `overlay_widget` | all above |

---

### Task 1: Plugin skeleton and metadata

**Files:**
- Create: `plugins/bookends.koplugin/_meta.lua`
- Create: `plugins/bookends.koplugin/main.lua`

- [ ] **Step 1: Create _meta.lua**

```lua
local _ = require("gettext")
return {
    name = "bookends",
    fullname = _("Bookends"),
    description = _([[Configurable text overlays at screen corners and edges with token expansion and icon support.]]),
}
```

- [ ] **Step 2: Create main.lua with minimal plugin class**

This is the entry point. Start with just init, settings loading, and view module registration — no menu or painting yet.

```lua
local Device = require("device")
local Font = require("ui/font")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")
local Screen = Device.screen

local Bookends = WidgetContainer:extend{
    name = "bookends",
    is_doc_only = true,
}

-- Position keys and their properties
Bookends.POSITIONS = {
    { key = "tl", label = _("Top-left"),      row = "top",    h_anchor = "left",   v_anchor = "top" },
    { key = "tc", label = _("Top-center"),     row = "top",    h_anchor = "center", v_anchor = "top" },
    { key = "tr", label = _("Top-right"),      row = "top",    h_anchor = "right",  v_anchor = "top" },
    { key = "bl", label = _("Bottom-left"),    row = "bottom", h_anchor = "left",   v_anchor = "bottom" },
    { key = "bc", label = _("Bottom-center"),  row = "bottom", h_anchor = "center", v_anchor = "bottom" },
    { key = "br", label = _("Bottom-right"),   row = "bottom", h_anchor = "right",  v_anchor = "bottom" },
}

function Bookends:init()
    self:loadSettings()
    self.ui.menu:registerToMainMenu(self)
    self.ui.view:registerViewModule("bookends", self)
    self.session_start_time = os.time()
    self.dirty = true
    self.position_cache = {} -- cached expanded text per position key
end

function Bookends:loadSettings()
    local footer_settings = self.ui.view.footer.settings
    self.enabled = G_reader_settings:readSetting("bookends_enabled", false)

    -- Global defaults
    self.defaults = {
        font_face = G_reader_settings:readSetting("bookends_font_face", Font.fontmap["ffont"]),
        font_size = G_reader_settings:readSetting("bookends_font_size", footer_settings.text_font_size),
        font_bold = G_reader_settings:readSetting("bookends_font_bold", false),
        v_offset  = G_reader_settings:readSetting("bookends_v_offset", 35),
        h_offset  = G_reader_settings:readSetting("bookends_h_offset", 10),
        overlap_gap = G_reader_settings:readSetting("bookends_overlap_gap", 10),
    }

    -- Per-position settings (table with format, font_face, font_size, etc.)
    self.positions = {}
    for _, pos in ipairs(self.POSITIONS) do
        self.positions[pos.key] = G_reader_settings:readSetting("bookends_pos_" .. pos.key, {
            format = "",
        })
    end
end

function Bookends:savePositionSetting(key)
    G_reader_settings:saveSetting("bookends_pos_" .. key, self.positions[key])
end

function Bookends:getPositionSetting(key, field)
    local pos = self.positions[key]
    if pos[field] ~= nil then
        return pos[field]
    end
    return self.defaults[field]
end

function Bookends:isPositionActive(key)
    return self.enabled and self.positions[key].format ~= ""
end

function Bookends:markDirty()
    self.dirty = true
    UIManager:setDirty(self.ui, "ui")
end

-- Event handlers
function Bookends:onPageUpdate() self:markDirty() end
function Bookends:onPosUpdate() self:markDirty() end
function Bookends:onReaderFooterVisibilityChange() self:markDirty() end
function Bookends:onSetDimensions() self:markDirty() end
function Bookends:onResume() self:markDirty() end

function Bookends:paintTo(bb, x, y)
    if not self.enabled then return end
    -- Will delegate to overlay_widget in Task 4
end

function Bookends:onCloseWidget()
    -- Will free widgets in Task 4
end

function Bookends:addToMainMenu(menu_items)
    -- Will be implemented in Task 5
    menu_items.bookends = {
        text = _("Bookends"),
        sorting_hint = "setting",
        sub_item_table = {},
    }
end

return Bookends
```

- [ ] **Step 3: Verify the plugin loads**

Copy the plugin to your KOReader installation's `plugins/` directory and open a book. Check the settings menu for the "Bookends" entry. It should appear with an empty submenu. No crashes in the log.

- [ ] **Step 4: Commit**

```bash
git add plugins/bookends.koplugin/_meta.lua plugins/bookends.koplugin/main.lua
git commit -m "feat(bookends): add plugin skeleton with settings and event handlers"
```

---

### Task 2: Token expansion engine

**Files:**
- Create: `plugins/bookends.koplugin/tokens.lua`

- [ ] **Step 1: Create tokens.lua**

A single module-level function that takes a format string, the plugin's `ui` reference, and the session start time, and returns the expanded string. All tokens return `""` when unavailable.

```lua
local Device = require("device")
local datetime = require("datetime")

local Tokens = {}

function Tokens.expand(format_str, ui, session_start_time)
    -- Fast path: no tokens
    if not format_str:find("%%") then
        return format_str
    end

    local pageno = ui.view.state.page
    local doc = ui.document

    -- Page numbers (respects hidden flows + pagemap)
    local currentpage
    if ui.pagemap and ui.pagemap:wantsPageLabels() then
        currentpage = ui.pagemap:getCurrentPageLabel(true) or ""
    elseif pageno and doc:hasHiddenFlows() then
        currentpage = doc:getPageNumberInFlow(pageno)
    else
        currentpage = pageno or 0
    end

    local totalpages
    if ui.pagemap and ui.pagemap:wantsPageLabels() then
        totalpages = ui.pagemap:getLastPageLabel(true) or ""
    elseif pageno and doc:hasHiddenFlows() then
        local flow = doc:getPageFlow(pageno)
        totalpages = doc:getTotalPagesInFlow(flow)
    else
        totalpages = doc:getPageCount()
    end

    -- Book percentage
    local percent = ""
    if type(currentpage) == "number" and type(totalpages) == "number" and totalpages > 0 then
        percent = math.floor(currentpage / totalpages * 100)
    end

    -- Chapter progress
    local chapter_pct = ""
    local chapter_pages_done = ""
    local chapter_pages_left = ""
    local chapter_title = ""
    if pageno and ui.toc then
        local done = ui.toc:getChapterPagesDone(pageno)
        local total = ui.toc:getChapterPageCount(pageno)
        if done and total and total > 0 then
            chapter_pages_done = done + 1 -- +1 to include current page
            chapter_pct = math.floor(chapter_pages_done / total * 100)
        end
        local left = ui.toc:getChapterPagesLeft(pageno)
        if left then
            chapter_pages_left = left
        end
        local title = ui.toc:getTocTitleByPage(pageno)
        if title and title ~= "" then
            chapter_title = title
        end
    end

    -- Pages left in book
    local pages_left_book = ""
    if pageno then
        local left = doc:getTotalPagesLeft(pageno)
        if left then
            pages_left_book = left
        end
    end

    -- Time left in chapter / document
    local time_left_chapter = ""
    local time_left_doc = ""
    local footer = ui.view.footer
    local avg_time = footer and footer.getAvgTimePerPage and footer:getAvgTimePerPage()
    if avg_time and avg_time == avg_time and pageno then
        local user_duration_format = G_reader_settings:readSetting("duration_format", "classic")
        local ch_left = ui.toc:getChapterPagesLeft(pageno)
            or doc:getTotalPagesLeft(pageno)
        if ch_left then
            time_left_chapter = datetime.secondsToClockDuration(
                user_duration_format, ch_left * avg_time, true)
        end
        local doc_left = doc:getTotalPagesLeft(pageno)
        if doc_left then
            time_left_doc = datetime.secondsToClockDuration(
                user_duration_format, doc_left * avg_time, true)
        end
    end

    -- Clock
    local time_12h = os.date("%I:%M %p")
    local time_24h = os.date("%H:%M")

    -- Session reading time
    local session_time = ""
    if session_start_time then
        local elapsed = os.time() - session_start_time
        local user_duration_format = G_reader_settings:readSetting("duration_format", "classic")
        session_time = datetime.secondsToClockDuration(user_duration_format, elapsed, true)
    end

    -- Document metadata
    local props = doc:getProps()
    local title = props.display_title or ""
    local authors = props.authors or ""
    local series = props.series or ""
    if series ~= "" and props.series_index then
        series = series .. " #" .. props.series_index
    end

    -- Battery
    local powerd = Device:getPowerDevice()
    local batt_lvl = powerd:getCapacity()
    local batt_symbol = ""
    if batt_lvl then
        batt_symbol = powerd:getBatterySymbol(powerd:isCharged(), powerd:isCharging(), batt_lvl) or ""
    else
        batt_lvl = ""
    end

    local replace = {
        -- Page/Progress
        ["%c"] = tostring(currentpage),
        ["%t"] = tostring(totalpages),
        ["%p"] = tostring(percent),
        ["%P"] = tostring(chapter_pct),
        ["%g"] = tostring(chapter_pages_done),
        ["%l"] = tostring(chapter_pages_left),
        ["%L"] = tostring(pages_left_book),
        -- Time/Reading
        ["%h"] = tostring(time_left_chapter),
        ["%H"] = tostring(time_left_doc),
        ["%k"] = time_12h,
        ["%K"] = time_24h,
        ["%R"] = session_time,
        -- Metadata
        ["%T"] = tostring(title),
        ["%A"] = tostring(authors),
        ["%S"] = tostring(series),
        ["%C"] = tostring(chapter_title),
        -- Device
        ["%b"] = tostring(batt_lvl),
        ["%B"] = tostring(batt_symbol),
        -- Formatting
        ["%r"] = " | ",
    }
    return format_str:gsub("(%%%a)", replace)
end

return Tokens
```

- [ ] **Step 2: Verify token expansion works**

Temporarily add a test call in `main.lua`'s `paintTo`:

```lua
function Bookends:paintTo(bb, x, y)
    if not self.enabled then return end
    local Tokens = require("tokens")
    local result = Tokens.expand("Page %c of %t (%p%%)", self.ui, self.session_start_time)
    print("BOOKENDS TEST:", result)
end
```

Open a book with bookends enabled. Check KOReader's log output for the expanded string. Verify page numbers, percentages, and clock tokens produce correct values. Remove the test code after verification.

- [ ] **Step 3: Commit**

```bash
git add plugins/bookends.koplugin/tokens.lua
git commit -m "feat(bookends): add token expansion engine with 18 tokens"
```

---

### Task 3: Overlay widget — rendering and overlap prevention

**Files:**
- Create: `plugins/bookends.koplugin/overlay_widget.lua`

- [ ] **Step 1: Create overlay_widget.lua**

This module handles building TextWidgets for each position, measuring them, applying smart ellipsis truncation, and painting them at the correct screen coordinates.

```lua
local Font = require("ui/font")
local TextWidget = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local Device = require("device")
local Screen = Device.screen

local OverlayWidget = {}

--- Build a TextWidget or VerticalGroup for a single line or multi-line string.
-- @param text string: the expanded text (may contain literal \n sequences)
-- @param face font face object
-- @param bold boolean
-- @param h_anchor string: "left", "center", or "right" — controls VerticalGroup alignment
-- @param max_width number or nil: if set, truncate lines to this pixel width
-- @return widget, width, height
function OverlayWidget.buildTextWidget(text, face, bold, h_anchor, max_width)
    -- Split on literal \n (the two-character sequence backslash-n in the format string)
    local lines = {}
    for line in text:gmatch("([^\n]*)\n?") do
        if line ~= "" or #lines > 0 then
            table.insert(lines, line)
        end
    end
    -- Remove trailing empty entry from gmatch
    if #lines > 1 and lines[#lines] == "" then
        table.remove(lines)
    end
    if #lines == 0 then
        return nil, 0, 0
    end

    local align = "center"
    if h_anchor == "left" then
        align = "left"
    elseif h_anchor == "right" then
        align = "right"
    end

    if #lines == 1 then
        local tw = TextWidget:new{
            text = lines[1],
            face = face,
            bold = bold,
            max_width = max_width,
            truncate_with_ellipsis = max_width ~= nil,
        }
        local size = tw:getSize()
        return tw, size.w, size.h
    end

    -- Multi-line: VerticalGroup of TextWidgets
    local group = VerticalGroup:new{ align = align }
    local max_w = 0
    local total_h = 0
    for _, line in ipairs(lines) do
        local tw = TextWidget:new{
            text = line,
            face = face,
            bold = bold,
            max_width = max_width,
            truncate_with_ellipsis = max_width ~= nil,
        }
        table.insert(group, tw)
        local size = tw:getSize()
        if size.w > max_w then max_w = size.w end
        total_h = total_h + size.h
    end
    return group, max_w, total_h
end

--- Measure the width of the widest line in a text string, without building a persistent widget.
-- Used for overlap calculation before truncation is applied.
-- @param text string
-- @param face font face
-- @param bold boolean
-- @return number: pixel width of widest line
function OverlayWidget.measureTextWidth(text, face, bold)
    local max_w = 0
    for line in text:gmatch("([^\n]*)") do
        if line ~= "" then
            local tw = TextWidget:new{
                text = line,
                face = face,
                bold = bold,
            }
            local w = tw:getSize().w
            tw:free()
            if w > max_w then max_w = w end
        end
    end
    return max_w
end

--- Calculate max_width for each position in a row, applying overlap prevention.
-- Center gets priority. Returns a table { left=max_w|nil, center=max_w|nil, right=max_w|nil }.
-- nil means no truncation needed.
-- @param left_w number or nil: measured width of left text (nil if position inactive)
-- @param center_w number or nil: measured width of center text
-- @param right_w number or nil: measured width of right text
-- @param screen_w number: screen width in pixels
-- @param gap number: minimum gap between texts in pixels
-- @param h_offset number: horizontal offset for corner positions
-- @return table { left=number|nil, center=number|nil, right=number|nil }
function OverlayWidget.calculateRowLimits(left_w, center_w, right_w, screen_w, gap, h_offset)
    local limits = { left = nil, center = nil, right = nil }

    -- Center gets priority: only truncate if it exceeds full screen width minus margins
    if center_w then
        local center_max = screen_w - 2 * gap
        if center_w > center_max then
            limits.center = center_max
            center_w = center_max
        end
    end

    if center_w then
        -- Side positions share the space not used by center
        local available_side = math.floor((screen_w - center_w) / 2) - gap
        if left_w and left_w > available_side - h_offset then
            limits.left = math.max(0, available_side - h_offset)
        end
        if right_w and right_w > available_side - h_offset then
            limits.right = math.max(0, available_side - h_offset)
        end
    else
        -- No center: left and right split the screen
        if left_w and right_w then
            local half = math.floor(screen_w / 2) - math.floor(gap / 2)
            if left_w > half - h_offset then
                limits.left = math.max(0, half - h_offset)
            end
            if right_w > half - h_offset then
                limits.right = math.max(0, half - h_offset)
            end
        end
        -- If only one side active, it gets full width minus its offset
        if left_w and not right_w then
            local max = screen_w - h_offset
            if left_w > max then
                limits.left = max
            end
        end
        if right_w and not left_w then
            local max = screen_w - h_offset
            if right_w > max then
                limits.right = max
            end
        end
    end

    return limits
end

--- Compute the (x, y) paint coordinates for a position.
-- @param h_anchor string: "left", "center", "right"
-- @param v_anchor string: "top", "bottom"
-- @param text_w number: widget width
-- @param text_h number: widget height
-- @param screen_w number
-- @param screen_h number
-- @param v_offset number: pixels inward from edge
-- @param h_offset number: pixels inward from edge (corners only)
-- @return x, y
function OverlayWidget.computeCoordinates(h_anchor, v_anchor, text_w, text_h, screen_w, screen_h, v_offset, h_offset)
    local x, y

    if h_anchor == "left" then
        x = h_offset
    elseif h_anchor == "center" then
        x = math.floor((screen_w - text_w) / 2)
    else -- "right"
        x = screen_w - text_w - h_offset
    end

    if v_anchor == "top" then
        y = v_offset
    else -- "bottom"
        y = screen_h - text_h - v_offset
    end

    return x, y
end

--- Free all widgets in a cache table.
-- @param widget_cache table: keyed by position key, values are widgets
function OverlayWidget.freeWidgets(widget_cache)
    for key, entry in pairs(widget_cache) do
        if entry.widget and entry.widget.free then
            entry.widget:free()
        end
        widget_cache[key] = nil
    end
end

return OverlayWidget
```

- [ ] **Step 2: Wire overlay_widget into main.lua paintTo**

Replace the placeholder `paintTo` and `onCloseWidget` in `main.lua`:

```lua
-- Add at top of main.lua:
local Tokens = require("tokens")
local OverlayWidget = require("overlay_widget")

-- Replace paintTo:
function Bookends:paintTo(bb, x, y)
    if not self.enabled then return end

    local screen_size = Screen:getSize()
    local screen_w = screen_size.w
    local screen_h = screen_size.h

    -- Phase 1: Expand tokens for all active positions
    local expanded = {} -- key -> expanded text string
    for _, pos in ipairs(self.POSITIONS) do
        if self:isPositionActive(pos.key) then
            local fmt = self.positions[pos.key].format
            -- Convert literal backslash-n to real newline for line splitting
            fmt = fmt:gsub("\\n", "\n")
            expanded[pos.key] = Tokens.expand(fmt, self.ui, self.session_start_time)
        end
    end

    -- Check if anything changed
    if not self.dirty then
        local changed = false
        for key, text in pairs(expanded) do
            if text ~= self.position_cache[key] then
                changed = true
                break
            end
        end
        if not changed then
            -- Repaint existing widgets at their cached positions
            for _, pos in ipairs(self.POSITIONS) do
                local entry = self.widget_cache and self.widget_cache[pos.key]
                if entry then
                    entry.widget:paintTo(bb, x + entry.x, y + entry.y)
                end
            end
            return
        end
    end

    -- Phase 2: Measure all active positions (no truncation yet)
    local measurements = {} -- key -> { width, face, bold }
    for key, text in pairs(expanded) do
        local pos_def = nil
        for _, p in ipairs(self.POSITIONS) do
            if p.key == key then pos_def = p; break end
        end
        local face = Font:getFace(
            self:getPositionSetting(key, "font_face"),
            self:getPositionSetting(key, "font_size"))
        local bold = self:getPositionSetting(key, "font_bold")
        local w = OverlayWidget.measureTextWidth(text, face, bold)
        measurements[key] = { width = w, face = face, bold = bold }
    end

    -- Phase 3: Calculate overlap limits per row
    local gap = self.defaults.overlap_gap
    local h_offset = self.defaults.h_offset

    -- Free old widgets
    if self.widget_cache then
        OverlayWidget.freeWidgets(self.widget_cache)
    end
    self.widget_cache = {}

    for _, row in ipairs({"top", "bottom"}) do
        local left_key = row == "top" and "tl" or "bl"
        local center_key = row == "top" and "tc" or "bc"
        local right_key = row == "top" and "tr" or "br"

        local left_w = measurements[left_key] and measurements[left_key].width or nil
        local center_w = measurements[center_key] and measurements[center_key].width or nil
        local right_w = measurements[right_key] and measurements[right_key].width or nil

        local left_h_offset = self:getPositionSetting(left_key, "h_offset")
        local right_h_offset = self:getPositionSetting(right_key, "h_offset")
        -- Use the larger h_offset for overlap calc to be safe
        local max_h_offset = math.max(left_h_offset or h_offset, right_h_offset or h_offset)

        local limits = OverlayWidget.calculateRowLimits(
            left_w, center_w, right_w, screen_w, gap, max_h_offset)

        -- Phase 4: Build widgets with truncation limits applied
        local row_keys = {
            { key = left_key, limit_key = "left" },
            { key = center_key, limit_key = "center" },
            { key = right_key, limit_key = "right" },
        }
        for _, rk in ipairs(row_keys) do
            local key = rk.key
            if expanded[key] then
                local m = measurements[key]
                local pos_def = nil
                for _, p in ipairs(self.POSITIONS) do
                    if p.key == key then pos_def = p; break end
                end

                local max_width = limits[rk.limit_key] -- nil if no truncation needed
                local widget, w, h = OverlayWidget.buildTextWidget(
                    expanded[key], m.face, m.bold, pos_def.h_anchor, max_width)

                if widget then
                    local v_off = self:getPositionSetting(key, "v_offset")
                    local h_off = self:getPositionSetting(key, "h_offset")
                    local px, py = OverlayWidget.computeCoordinates(
                        pos_def.h_anchor, pos_def.v_anchor,
                        w, h, screen_w, screen_h, v_off, h_off)

                    self.widget_cache[key] = { widget = widget, x = px, y = py }
                    widget:paintTo(bb, x + px, y + py)
                end
            end
        end
    end

    -- Update cache
    self.position_cache = {}
    for key, text in pairs(expanded) do
        self.position_cache[key] = text
    end
    self.dirty = false
end

-- Replace onCloseWidget:
function Bookends:onCloseWidget()
    if self.widget_cache then
        OverlayWidget.freeWidgets(self.widget_cache)
        self.widget_cache = nil
    end
end
```

- [ ] **Step 3: Test rendering**

Temporarily hardcode a format string for testing. In `loadSettings`, after loading positions, add:

```lua
-- TEMP: test overlay rendering
self.enabled = true
self.positions["tl"] = { format = "%k" }
self.positions["tc"] = { format = "%T" }
self.positions["tr"] = { format = "%b%%  %B" }
self.positions["bl"] = { format = "Ch: %g/%l" }
self.positions["bc"] = { format = "Page %c of %t (%p%%)" }
self.positions["br"] = { format = "%h left" }
```

Open a book. Verify:
- All 6 positions render text at the correct screen locations
- Text is anchored correctly (left-aligned at left edge, right-aligned at right edge, centered)
- Long titles are truncated with ellipsis when they'd overlap corner text

Remove the temporary hardcoded values after testing.

- [ ] **Step 4: Commit**

```bash
git add plugins/bookends.koplugin/overlay_widget.lua plugins/bookends.koplugin/main.lua
git commit -m "feat(bookends): add overlay widget rendering with overlap prevention"
```

---

### Task 4: Icon picker UI

**Files:**
- Create: `plugins/bookends.koplugin/icon_picker.lua`

- [ ] **Step 1: Create icon_picker.lua**

A scrollable list of Nerd Font icons organized by category. When the user taps an icon, it calls back with the Unicode character.

```lua
local Menu = require("ui/widget/menu")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local IconPicker = {}

-- Icon catalog: { category_label, { {glyph, description}, ... } }
-- Codepoints reference Nerd Fonts PUA range + standard Unicode
IconPicker.CATALOG = {
    { _("Battery"), {
        { "\u{E790}", _("Battery") },
        { "\u{EDA3}", _("Battery charged") },
        { "\u{E783}", _("Battery charging") },
        { "\u{E782}", _("Battery critical") },
    }},
    { _("Connectivity"), {
        { "\u{ECA8}", _("Wi-Fi on") },
        { "\u{ECA9}", _("Wi-Fi off") },
    }},
    { _("Status"), {
        { "\u{F097}", _("Bookmark") },
        { "\u{EA5A}", _("Memory") },
    }},
    { _("Time"), {
        { "\u{231A}", _("Watch") },
        { "\u{23F3}", _("Hourglass") },
    }},
    { _("Symbols"), {
        { "\u{263C}", _("Sun / brightness") },
        { "\u{1F4A1}", _("Light bulb") },
        { "\u{1F4D6}", _("Open book") },
        { "\u{1F4D1}", _("Bookmark tabs") },
    }},
    { _("Arrows"), {
        { "\u{21C4}", _("Arrows left-right") },
        { "\u{21C9}", _("Arrows right") },
        { "\u{21A2}", _("Arrow left with tail") },
        { "\u{21A3}", _("Arrow right with tail") },
        { "\u{291F}", _("Arrow left to bar") },
        { "\u{2920}", _("Arrow right to bar") },
    }},
    { _("Separators"), {
        { "|",       _("Vertical bar") },
        { "\u{2022}", _("Bullet") },
        { "\u{00B7}", _("Middle dot") },
        { "\u{25C6}", _("Diamond") },
        { "\u{2014}", _("Em dash") },
        { "\u{2013}", _("En dash") },
    }},
}

--- Build the flat item list for the Menu widget, with category headers.
function IconPicker:buildItemTable()
    local items = {}
    for _, category in ipairs(self.CATALOG) do
        local label = category[1]
        local icons = category[2]
        -- Category header (non-selectable)
        table.insert(items, {
            text = "── " .. label .. " ──",
            dim = true,
            callback = function() end, -- no-op
        })
        for _, icon_entry in ipairs(icons) do
            local glyph = icon_entry[1]
            local desc = icon_entry[2]
            table.insert(items, {
                text = glyph .. "   " .. desc,
                glyph = glyph,
            })
        end
    end
    return items
end

--- Show the icon picker. When user selects an icon, on_select(glyph) is called.
-- @param on_select function(glyph_string)
function IconPicker:show(on_select)
    local item_table = self:buildItemTable()

    local menu
    menu = Menu:new{
        title = _("Insert icon"),
        item_table = item_table,
        width = math.floor(require("device").screen:getWidth() * 0.8),
        height = math.floor(require("device").screen:getHeight() * 0.8),
        items_per_page = 14,
        onMenuChoice = function(_, item)
            if item.glyph then
                on_select(item.glyph)
            end
        end,
        close_callback = function()
            UIManager:close(menu)
        end,
    }
    UIManager:show(menu)
end

return IconPicker
```

- [ ] **Step 2: Test the icon picker standalone**

Temporarily add a menu item in `main.lua`'s `addToMainMenu` to test:

```lua
{
    text = _("Test icon picker"),
    callback = function()
        local IconPicker = require("icon_picker")
        IconPicker:show(function(glyph)
            local InfoMessage = require("ui/widget/infomessage")
            UIManager:show(InfoMessage:new{ text = "Selected: " .. glyph })
        end)
    end,
},
```

Open the menu, tap "Test icon picker", browse categories, select an icon. Verify the glyph renders in the confirmation dialog. Remove the test menu item after.

- [ ] **Step 3: Commit**

```bash
git add plugins/bookends.koplugin/icon_picker.lua
git commit -m "feat(bookends): add icon picker UI with categorized Nerd Font glyphs"
```

---

### Task 5: Menu system

**Files:**
- Modify: `plugins/bookends.koplugin/main.lua`

- [ ] **Step 1: Implement the full menu tree**

Replace the placeholder `addToMainMenu` in `main.lua` with the complete menu. This includes the master enable toggle, per-position submenus (format string editor with icon picker integration, optional font/size/offset overrides), and global default settings.

```lua
function Bookends:addToMainMenu(menu_items)
    menu_items.bookends = {
        text = _("Bookends"),
        sorting_hint = "setting",
        sub_item_table = self:buildMainMenu(),
    }
end

function Bookends:buildMainMenu()
    local menu = {
        {
            text = _("Enable bookends"),
            checked_func = function()
                return self.enabled
            end,
            callback = function()
                self.enabled = not self.enabled
                G_reader_settings:saveSetting("bookends_enabled", self.enabled)
                self:markDirty()
            end,
        },
    }

    -- Per-position submenus
    for _, pos in ipairs(self.POSITIONS) do
        table.insert(menu, {
            text_func = function()
                local fmt = self.positions[pos.key].format
                if fmt == "" then
                    return pos.label
                else
                    return pos.label .. ": " .. fmt
                end
            end,
            enabled_func = function() return self.enabled end,
            sub_item_table_func = function()
                return self:buildPositionMenu(pos)
            end,
        })
    end

    -- Separator
    table.insert(menu, {
        text = "──────────",
        enabled_func = function() return false end,
    })

    -- Global defaults
    table.insert(menu, {
        text = _("Default font"),
        enabled_func = function() return self.enabled end,
        sub_item_table = self:buildFontMenu(function() return self.defaults.font_face end,
            function(face)
                self.defaults.font_face = face
                G_reader_settings:saveSetting("bookends_font_face", face)
                self:markDirty()
            end),
    })
    table.insert(menu, {
        text = _("Default font size"),
        keep_menu_open = true,
        enabled_func = function() return self.enabled end,
        callback = function()
            self:showSpinner(_("Default font size"), self.defaults.font_size, 8, 36,
                self.ui.view.footer.settings.text_font_size,
                function(val)
                    self.defaults.font_size = val
                    G_reader_settings:saveSetting("bookends_font_size", val)
                    self:markDirty()
                end)
        end,
    })
    table.insert(menu, {
        text = _("Default vertical offset"),
        keep_menu_open = true,
        enabled_func = function() return self.enabled end,
        callback = function()
            self:showSpinner(_("Default vertical offset (px)"), self.defaults.v_offset, 0, 200, 35,
                function(val)
                    self.defaults.v_offset = val
                    G_reader_settings:saveSetting("bookends_v_offset", val)
                    self:markDirty()
                end)
        end,
    })
    table.insert(menu, {
        text = _("Default horizontal offset"),
        keep_menu_open = true,
        enabled_func = function() return self.enabled end,
        callback = function()
            self:showSpinner(_("Default horizontal offset (px)"), self.defaults.h_offset, 0, 200, 10,
                function(val)
                    self.defaults.h_offset = val
                    G_reader_settings:saveSetting("bookends_h_offset", val)
                    self:markDirty()
                end)
        end,
    })
    table.insert(menu, {
        text = _("Overlap gap"),
        keep_menu_open = true,
        enabled_func = function() return self.enabled end,
        callback = function()
            self:showSpinner(_("Minimum gap between texts (px)"), self.defaults.overlap_gap, 0, 100, 10,
                function(val)
                    self.defaults.overlap_gap = val
                    G_reader_settings:saveSetting("bookends_overlap_gap", val)
                    self:markDirty()
                end)
        end,
    })

    return menu
end

function Bookends:buildPositionMenu(pos)
    local is_corner = pos.h_anchor ~= "center"
    local menu = {
        {
            text = _("Edit format string"),
            keep_menu_open = true,
            callback = function()
                self:editFormatString(pos.key)
            end,
        },
        {
            text_func = function()
                if self.positions[pos.key].font_face then
                    return _("Override font (active)")
                end
                return _("Override font")
            end,
            sub_item_table_func = function()
                local items = self:buildFontMenu(
                    function() return self:getPositionSetting(pos.key, "font_face") end,
                    function(face)
                        self.positions[pos.key].font_face = face
                        self:savePositionSetting(pos.key)
                        self:markDirty()
                    end)
                -- Add "Reset to default" at the top
                table.insert(items, 1, {
                    text = _("Reset to default"),
                    callback = function()
                        self.positions[pos.key].font_face = nil
                        self:savePositionSetting(pos.key)
                        self:markDirty()
                    end,
                })
                return items
            end,
        },
        {
            text_func = function()
                if self.positions[pos.key].font_size then
                    return _("Override font size") .. " (" .. self.positions[pos.key].font_size .. ")"
                end
                return _("Override font size")
            end,
            keep_menu_open = true,
            callback = function()
                self:showSpinner(_("Font size for " .. pos.label),
                    self:getPositionSetting(pos.key, "font_size"), 8, 36,
                    self.defaults.font_size,
                    function(val)
                        self.positions[pos.key].font_size = val
                        self:savePositionSetting(pos.key)
                        self:markDirty()
                    end)
            end,
        },
        {
            text_func = function()
                if self.positions[pos.key].v_offset then
                    return _("Override vertical offset") .. " (" .. self.positions[pos.key].v_offset .. ")"
                end
                return _("Override vertical offset")
            end,
            keep_menu_open = true,
            callback = function()
                self:showSpinner(_("Vertical offset for " .. pos.label),
                    self:getPositionSetting(pos.key, "v_offset"), 0, 200,
                    self.defaults.v_offset,
                    function(val)
                        self.positions[pos.key].v_offset = val
                        self:savePositionSetting(pos.key)
                        self:markDirty()
                    end)
            end,
        },
    }

    -- Horizontal offset only for corners
    if is_corner then
        table.insert(menu, {
            text_func = function()
                if self.positions[pos.key].h_offset then
                    return _("Override horizontal offset") .. " (" .. self.positions[pos.key].h_offset .. ")"
                end
                return _("Override horizontal offset")
            end,
            keep_menu_open = true,
            callback = function()
                self:showSpinner(_("Horizontal offset for " .. pos.label),
                    self:getPositionSetting(pos.key, "h_offset"), 0, 200,
                    self.defaults.h_offset,
                    function(val)
                        self.positions[pos.key].h_offset = val
                        self:savePositionSetting(pos.key)
                        self:markDirty()
                    end)
            end,
        })
    end

    -- Reset all overrides
    table.insert(menu, {
        text = _("Reset all overrides"),
        callback = function()
            local fmt = self.positions[pos.key].format
            self.positions[pos.key] = { format = fmt }
            self:savePositionSetting(pos.key)
            self:markDirty()
        end,
    })

    return menu
end

function Bookends:editFormatString(pos_key)
    local InputDialog = require("ui/widget/inputdialog")
    local InfoMessage = require("ui/widget/infomessage")
    local IconPicker = require("icon_picker")

    local format_dialog
    format_dialog = InputDialog:new{
        title = _("Format string"),
        input = self.positions[pos_key].format,
        buttons = {
            {
                {
                    text = _("Cancel"),
                    id = "close",
                    callback = function()
                        UIManager:close(format_dialog)
                    end,
                },
                {
                    text = _("Icons"),
                    callback = function()
                        IconPicker:show(function(glyph)
                            format_dialog:addTextToInput(glyph)
                        end)
                    end,
                },
                {
                    text = _("Tokens"),
                    callback = function()
                        UIManager:show(InfoMessage:new{
                            text = _([[
Tokens:
%c  current page       %t  total pages
%p  book % read        %P  chapter % read
%g  pages read in ch.  %l  pages left in ch.
%L  pages left in book
%h  time left (ch.)    %H  time left (book)
%k  12h clock          %K  24h clock
%R  session reading time
%T  title              %A  author(s)
%S  series             %C  chapter title
%b  battery level      %B  battery icon
%r  separator ( | )
\n  line break]]),
                        })
                    end,
                },
                {
                    text = _("Save"),
                    is_enter_default = true,
                    callback = function()
                        self.positions[pos_key].format = format_dialog:getInputText()
                        self:savePositionSetting(pos_key)
                        UIManager:close(format_dialog)
                        self:markDirty()
                    end,
                },
            },
        },
    }
    UIManager:show(format_dialog)
    format_dialog:onShowKeyboard()
end

function Bookends:buildFontMenu(get_current, on_select)
    local cre = require("document/credocument"):engineInit()
    local FontList = require("fontlist")
    local face_list = cre.getFontFaces()
    local menu = {}
    for _, face_name in ipairs(face_list) do
        local font_filename, font_faceindex = cre.getFontFaceFilenameAndFaceIndex(face_name)
        if not font_filename then
            font_filename, font_faceindex = cre.getFontFaceFilenameAndFaceIndex(face_name, nil, true)
        end
        if font_filename then
            local display_name = FontList:getLocalizedFontName(font_filename, font_faceindex) or face_name
            table.insert(menu, {
                text = display_name,
                checked_func = function()
                    return get_current() == font_filename
                end,
                callback = function()
                    on_select(font_filename)
                end,
            })
        end
    end
    return menu
end

function Bookends:showSpinner(title, value, min, max, default, on_set)
    local SpinWidget = require("ui/widget/spinwidget")
    UIManager:show(SpinWidget:new{
        value = value,
        value_min = min,
        value_max = max,
        default_value = default,
        title_text = title,
        ok_text = _("Set"),
        callback = function(spin)
            on_set(spin.value)
        end,
    })
end
```

- [ ] **Step 2: Test the full menu**

Open a book, go to Settings > Bookends. Verify:
- Master enable toggle works
- Each position submenu opens
- Format string editor shows with Cancel/Icons/Tokens/Save buttons
- Tokens info button shows the full token reference
- Icons button opens the picker and inserts a glyph into the input field
- Font, font size, offset spinners all work
- Per-position overrides show "(active)" or the value when set
- "Reset all overrides" clears overrides but keeps the format string
- Global default settings persist across menu reopens

- [ ] **Step 3: Test end-to-end**

Set up format strings for multiple positions:
- TL: `%k`
- TC: `%T`
- TR: `%B %b%%`
- BL: `Ch. %g/%l`
- BC: `Page %c of %t`
- BR: `%h left`

Navigate pages. Verify:
- All positions update on page turn
- Clock updates when resuming from sleep
- Long titles truncate with ellipsis rather than overlapping corner text
- Multi-line format strings with `\n` render correctly
- Empty positions don't render anything

- [ ] **Step 4: Commit**

```bash
git add plugins/bookends.koplugin/main.lua
git commit -m "feat(bookends): add full menu system with format editor and icon picker"
```

---

### Task 6: Final cleanup and documentation

**Files:**
- Modify: `plugins/bookends.koplugin/main.lua` (remove any leftover test code)

- [ ] **Step 1: Clean up any remaining test code**

Review all files for any temporary test code added during development. Remove it.

- [ ] **Step 2: Test fresh install**

Delete any saved `bookends_*` settings from G_reader_settings (or test on a fresh KOReader profile). Verify:
- Plugin starts disabled by default
- Enabling it with no format strings shows nothing (no errors)
- Setting a format string for one position renders correctly
- All defaults are sensible

- [ ] **Step 3: Final commit**

```bash
git add -A plugins/bookends.koplugin/
git commit -m "feat(bookends): complete plugin ready for use"
```
