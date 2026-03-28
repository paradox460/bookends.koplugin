local Menu = require("ui/widget/menu")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local IconPicker = {}

-- Icon catalog: { category_label, { {glyph, description}, ... } }
-- Codepoints reference Nerd Fonts PUA range + standard Unicode
-- All glyphs are encoded as UTF-8 byte sequences (LuaJIT does not support \u{} syntax)
IconPicker.CATALOG = {
    { _("Battery"), {
        { "\xEE\x9E\x90", _("Battery") },           -- U+E790
        { "\xEE\xB6\xA3", _("Battery charged") },   -- U+EDA3
        { "\xEE\x9E\x83", _("Battery charging") },  -- U+E783
        { "\xEE\x9E\x82", _("Battery critical") },  -- U+E782
    }},
    { _("Connectivity"), {
        { "\xEE\xB2\xA8", _("Wi-Fi on") },   -- U+ECA8
        { "\xEE\xB2\xA9", _("Wi-Fi off") },  -- U+ECA9
    }},
    { _("Status"), {
        { "\xEF\x82\x97", _("Bookmark") },  -- U+F097
        { "\xEE\xA9\x9A", _("Memory") },    -- U+EA5A
    }},
    { _("Time"), {
        { "\xE2\x8C\x9A", _("Watch") },     -- U+231A
        { "\xE2\x8F\xB3", _("Hourglass") }, -- U+23F3
    }},
    { _("Symbols"), {
        { "\xE2\x98\xBC", _("Sun / brightness") }, -- U+263C
        { "\xF0\x9F\x92\xA1", _("Light bulb") },   -- U+1F4A1
        { "\xF0\x9F\x93\x96", _("Open book") },    -- U+1F4D6
        { "\xF0\x9F\x93\x91", _("Bookmark tabs") },-- U+1F4D1
    }},
    { _("Arrows"), {
        { "\xE2\x87\x84", _("Arrows left-right") },     -- U+21C4
        { "\xE2\x87\x89", _("Arrows right") },          -- U+21C9
        { "\xE2\x86\xA2", _("Arrow left with tail") },  -- U+21A2
        { "\xE2\x86\xA3", _("Arrow right with tail") }, -- U+21A3
        { "\xE2\xA4\x9F", _("Arrow left to bar") },     -- U+291F
        { "\xE2\xA4\xA0", _("Arrow right to bar") },    -- U+2920
    }},
    { _("Separators"), {
        { "|",             _("Vertical bar") },  -- U+007C (ASCII)
        { "\xE2\x80\xA2", _("Bullet") },         -- U+2022
        { "\xC2\xB7",     _("Middle dot") },     -- U+00B7
        { "\xE2\x97\x86", _("Diamond") },        -- U+25C6
        { "\xE2\x80\x94", _("Em dash") },        -- U+2014
        { "\xE2\x80\x93", _("En dash") },        -- U+2013
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
            text = "\xE2\x94\x80\xE2\x94\x80 " .. label .. " \xE2\x94\x80\xE2\x94\x80",
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
