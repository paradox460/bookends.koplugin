--- Single Presets menu entry — opens the Preset Manager modal.
local UIManager = require("ui/uimanager")
local _ = require("i18n").gettext

return function(Bookends)

function Bookends:buildPresetsMenu()
    return {
        {
            text = _("Preset Manager…"),
            keep_menu_open = true,
            callback = function(touchmenu_instance)
                if touchmenu_instance then
                    UIManager:close(touchmenu_instance)
                end
                local PresetManagerModal = require("menu/preset_manager_modal")
                PresetManagerModal.show(self)
            end,
        },
    }
end

end
