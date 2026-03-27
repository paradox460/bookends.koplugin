-- patchfilechooser.lua — Display Mode Home Folder
-- Wraps FileChooser methods to apply per-context display mode and sort.
--
-- Sort: patches getCollate() to return the override collate when active.
-- The global "collate" setting in G_reader_settings is NEVER modified.
--
-- Display mode: calls CoverBrowser's setupFileManagerDisplayMode() on
-- context transitions. This does modify CoverBrowser's internal state,
-- so we save/restore it on teardown.
--
-- Assumes a single FileManager instance (KOReader's current architecture).

local Device = require("device")
local FileChooser = require("ui/widget/filechooser")
local FileManager = require("apps/filemanager/filemanager")
local BookInfoManager = require("bookinfomanager")
local ffiUtil = require("ffi/util")

local M = {}

-- State
local _current_context = nil         -- "home", "subfolder", or nil
local _orig_changeToPath = nil
local _orig_goHome = nil
local _orig_getCollate = nil
local _saved_display_mode = nil      -- CoverBrowser display mode before first override
local _display_overridden = false

-- Resolve the home directory path (with realpath normalization).
local function getHomeDir()
    local home = G_reader_settings:readSetting("home_dir") or Device.home_dir
    if home then
        home = ffiUtil.realpath(home) or home
    end
    return home
end

-- Determine context for a given path.
local function getContext(path)
    local home = getHomeDir()
    if not home then return "subfolder" end
    local real = ffiUtil.realpath(path) or path
    return real == home and "home" or "subfolder"
end

-- Read the override display mode for a context, or nil if unset.
-- Only subfolders have overrides; home always uses the global setting.
local function getDisplayModeOverride(context)
    if context ~= "subfolder" then return nil end
    return G_reader_settings:readSetting("subfolder_display_mode")
end

-- Read the override collate ID for the current context, or nil if unset.
-- Only subfolders have overrides; home always uses the global setting.
local function getActiveCollateOverride()
    if _current_context ~= "subfolder" then return nil end
    return G_reader_settings:readSetting("subfolder_collate")
end

-- Apply display mode via CoverBrowser if available.
local function applyDisplayMode(mode)
    local fm = FileManager.instance
    if not fm or not fm.coverbrowser then return end
    -- "classic" is our sentinel for the classic (filename-only) mode.
    -- CoverBrowser uses nil internally for classic mode.
    if mode == "classic" then mode = nil end
    fm.coverbrowser:setupFileManagerDisplayMode(mode)
end

-- Save the current CoverBrowser display mode before our first override.
local function captureDisplayMode()
    if _display_overridden then return end
    _saved_display_mode = BookInfoManager:getSetting("filemanager_display_mode")
    _display_overridden = true
end

-- Switch context if needed. Called before changeToPath/goHome runs.
local function switchContext(path)
    local ctx = getContext(path)
    if ctx == _current_context then
        return
    end

    local display_override = getDisplayModeOverride(ctx)

    -- Handle display mode transitions
    if display_override then
        captureDisplayMode()
        applyDisplayMode(display_override)
    elseif _display_overridden then
        -- No display override for this context; revert to user's global
        applyDisplayMode(_saved_display_mode)
    end

    -- Sort is handled by the getCollate patch — no action needed here.
    -- Just clear the sort cache so the next refreshPath picks up the new collate.
    local fm = FileManager.instance
    if fm and fm.file_chooser then
        fm.file_chooser:clearSortingCache()
    end

    _current_context = ctx
end

function M.apply()
    if _orig_changeToPath then return end -- already patched

    _orig_changeToPath = FileChooser.changeToPath
    _orig_goHome = FileChooser.goHome
    _orig_getCollate = FileChooser.getCollate

    -- Patch getCollate to return override when active.
    -- This is the cleanest approach: the global "collate" setting is never
    -- modified, so there's nothing to save/restore for sort order.
    FileChooser.getCollate = function(self)
        local override_id = getActiveCollateOverride()
        if override_id then
            local collate = self.collates[override_id]
            if collate then
                return collate, override_id
            end
        end
        return _orig_getCollate(self)
    end

    FileChooser.changeToPath = function(self, path, focused_path)
        local real = ffiUtil.realpath(path) or path
        switchContext(real)
        return _orig_changeToPath(self, path, focused_path)
    end

    FileChooser.goHome = function(self)
        local home = getHomeDir()
        if home then
            switchContext(home)
        end
        return _orig_goHome(self)
    end

end

function M.teardown()
    if _orig_changeToPath then
        FileChooser.changeToPath = _orig_changeToPath
        _orig_changeToPath = nil
    end
    if _orig_goHome then
        FileChooser.goHome = _orig_goHome
        _orig_goHome = nil
    end
    if _orig_getCollate then
        FileChooser.getCollate = _orig_getCollate
        _orig_getCollate = nil
    end
    -- Restore CoverBrowser display mode
    if _display_overridden then
        applyDisplayMode(_saved_display_mode)
    end
    _current_context = nil
    _saved_display_mode = nil
    _display_overridden = false
end

return M
