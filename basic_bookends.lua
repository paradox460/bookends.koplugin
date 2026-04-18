-- Bookends preset: Basic bookends
return {
    name = "Basic bookends",
    description = "Minimal starter — page number and clock",
    author = "bookends",
    enabled = true,
    positions = {
        tl = { lines = {} },
        tc = { lines = {} },
        tr = { lines = { "%k" }, line_font_size = { [1] = 14 } },
        bl = { lines = {} },
        bc = { lines = { "Page %c of %t" }, line_font_size = { [1] = 14 } },
        br = { lines = {} },
    },
}
