--- Preset loading/saving menus and edit-preset dialog.
local ConfirmBox = require("ui/widget/confirmbox")
local InfoMessage = require("ui/widget/infomessage")
local InputDialog = require("ui/widget/inputdialog")
local UIManager = require("ui/uimanager")
local _ = require("i18n").gettext
local T = require("ffi/util").template

return function(Bookends)

function Bookends:buildPresetsMenu()
    local items = {
        {
            text = _("Built-in presets"),
            enabled_func = function() return false end,
            separator = true,
        },
    }

    -- Built-in presets (sorted alphabetically)
    local sorted_builtins = {}
    for _, bp in ipairs(self.BUILT_IN_PRESETS) do
        table.insert(sorted_builtins, bp)
    end
    table.sort(sorted_builtins, function(a, b) return a.name < b.name end)
    for _i, bp in ipairs(sorted_builtins) do
        table.insert(items, {
            text = bp.name,
            keep_menu_open = true,
            callback = function()
                self:loadPreset(bp.preset)
                UIManager:show(InfoMessage:new{
                    text = T(_("Preset '%1' loaded."), bp.name),
                    timeout = 2,
                })
            end,
        })
    end
    items[#items].separator = true

    -- Custom presets (file-based)
    table.insert(items, {
        text = _("Custom presets"),
        sub_item_table_func = function()
            return self:buildCustomPresetsMenu()
        end,
    })

    return items
end

function Bookends:buildCustomPresetsMenu()
    local items = {
        {
            text = _("Save current as preset…"),
            keep_menu_open = true,
            callback = function(touchmenu_instance)
                local restoreMenu = self:hideMenu(touchmenu_instance)
                local input_dialog
                input_dialog = InputDialog:new{
                    title = _("Enter preset name"),
                    buttons = {
                        {
                            {
                                text = _("Cancel"),
                                id = "close",
                                callback = function()
                                    UIManager:close(input_dialog)
                                    restoreMenu()
                                end,
                            },
                            {
                                text = _("Save"),
                                is_enter_default = true,
                                callback = function()
                                    local name = input_dialog:getInputText()
                                    if name == "" or name:match("^%s*$") then
                                        UIManager:show(InfoMessage:new{
                                            text = _("Please enter a name for the preset."),
                                            timeout = 2,
                                        })
                                        return
                                    end
                                    local preset_data = self:buildPreset()
                                    self:writePresetFile(name, preset_data)
                                    UIManager:close(input_dialog)
                                    if touchmenu_instance then
                                        touchmenu_instance.item_table = self:buildCustomPresetsMenu()
                                    end
                                    restoreMenu()
                                    UIManager:show(InfoMessage:new{
                                        text = T(_("Preset '%1' saved."), name),
                                        timeout = 2,
                                    })
                                end,
                            },
                        },
                    },
                }
                UIManager:show(input_dialog)
                input_dialog:onShowKeyboard()
            end,
            separator = true,
        },
    }

    -- Load preset files from directory
    local presets = self:readPresetFiles()
    for _i, entry in ipairs(presets) do
        table.insert(items, {
            text = entry.name,
            keep_menu_open = true,
            callback = function()
                local load_ok, load_err = pcall(self.loadPreset, self, entry.preset)
                if not load_ok then
                    UIManager:show(InfoMessage:new{
                        text = T(_("Failed to load preset '%1':\n%2"), entry.name, tostring(load_err)),
                    })
                    return
                end
                UIManager:show(InfoMessage:new{
                    text = T(_("Preset '%1' loaded."), entry.name),
                    timeout = 2,
                })
            end,
            hold_callback = function(touchmenu_instance)
                self:showPresetEditDialog(entry, touchmenu_instance)
            end,
        })
    end

    if #presets > 0 then
        table.insert(items, {
            text = _("Long press presets to edit"),
            enabled_func = function() return false end,
        })
    end

    -- Show presets folder path
    table.insert(items, {
        text = _("Open presets folder"),
        keep_menu_open = true,
        callback = function()
            self:ensurePresetDir()
            UIManager:show(InfoMessage:new{
                text = T(_("Preset files are stored in:\n%1\n\nCopy .lua files here to import presets from other users."), self:presetDir()),
            })
        end,
        separator = true,
    })

    return items
end

function Bookends:showPresetEditDialog(entry, touchmenu_instance)
    UIManager:show(ConfirmBox:new{
        text = T(_("What would you like to do with preset '%1'?"), entry.name),
        icon = "notice-question",
        ok_text = _("Update"),
        ok_callback = function()
            UIManager:show(ConfirmBox:new{
                text = T(_("Overwrite preset '%1' with current settings?"), entry.name),
                ok_callback = function()
                    self:updatePresetFile(entry.filename, entry.name)
                    if touchmenu_instance then
                        touchmenu_instance.item_table = self:buildCustomPresetsMenu()
                        touchmenu_instance:updateItems()
                    end
                    UIManager:show(InfoMessage:new{
                        text = T(_("Preset '%1' updated."), entry.name),
                        timeout = 2,
                    })
                end,
            })
        end,
        other_buttons_first = true,
        other_buttons = {
            {
                {
                    text = _("Delete"),
                    callback = function()
                        UIManager:show(ConfirmBox:new{
                            text = T(_("Delete preset '%1'? This cannot be undone."), entry.name),
                            ok_text = _("Delete"),
                            ok_callback = function()
                                self:deletePresetFile(entry.filename)
                                if touchmenu_instance then
                                    touchmenu_instance.item_table = self:buildCustomPresetsMenu()
                                    touchmenu_instance:updateItems()
                                end
                                UIManager:show(InfoMessage:new{
                                    text = T(_("Preset '%1' deleted."), entry.name),
                                    timeout = 2,
                                })
                            end,
                        })
                    end,
                },
                {
                    text = _("Rename"),
                    callback = function()
                        local input_dialog
                        input_dialog = InputDialog:new{
                            title = _("Enter new preset name"),
                            input = entry.name,
                            buttons = {
                                {
                                    {
                                        text = _("Cancel"),
                                        id = "close",
                                        callback = function()
                                            UIManager:close(input_dialog)
                                        end,
                                    },
                                    {
                                        text = _("Rename"),
                                        is_enter_default = true,
                                        callback = function()
                                            local new_name = input_dialog:getInputText()
                                            if new_name == "" or new_name:match("^%s*$") or new_name == entry.name then
                                                UIManager:close(input_dialog)
                                                return
                                            end
                                            self:renamePresetFile(entry.filename, new_name)
                                            UIManager:close(input_dialog)
                                            if touchmenu_instance then
                                                touchmenu_instance.item_table = self:buildCustomPresetsMenu()
                                                touchmenu_instance:updateItems()
                                            end
                                            UIManager:show(InfoMessage:new{
                                                text = T(_("Preset renamed to '%1'."), new_name),
                                                timeout = 2,
                                            })
                                        end,
                                    },
                                },
                            },
                        }
                        UIManager:show(input_dialog)
                        input_dialog:onShowKeyboard()
                    end,
                },
            },
        },
    })
end

end
