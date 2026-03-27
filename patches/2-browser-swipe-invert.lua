-- Inverts swipe direction in the file browser so that swiping in
-- the reading direction (right to left) goes to the next page,
-- matching the page-turn convention used in the reader.
--
-- Stock behavior: swipe left = next page (scroll metaphor)
-- Patched behavior: swipe right-to-left = previous page, swipe left-to-right = next page (page-turn metaphor)

local BD = require("ui/bidi")
local FileManager = require("apps/filemanager/filemanager")

function FileManager:onSwipeFM(ges)
    local direction = BD.flipDirectionIfMirroredUILayout(ges.direction)
    if direction == "west" then
        self.file_chooser:onPrevPage()
    elseif direction == "east" then
        self.file_chooser:onNextPage()
    end
    return true
end
