-- Reduce a rendered revealjs deck to the part the golden tests compare: the sequence of
-- slides, their classes and their content.
--
-- Two things are deliberately normalised away. Identifiers, because a continuation is
-- `introduction-cont-1` where a hand-written duplicate heading is `introduction-1` —
-- different names for the same slide, and the whole point of the scheme is that they do
-- not collide. And the two marker classes the extension adds, which are what a reader
-- would use to tell a continuation from a hand-typed repeat.
--
-- Usage: pandoc lua normalise-deck.lua deck.html

local path = arg[1]
if not path then
  io.stderr:write("usage: pandoc lua normalise-deck.lua <deck.html>\n")
  os.exit(2)
end

local handle = assert(io.open(path, "r"))
local html = handle:read("a")
handle:close()

-- Everything before the slides and after the last one is boilerplate: the reveal
-- scaffolding, script tags, and the configuration block naming the output file.
local start = html:find('<div class="slides">', 1, true)
local stop = html:find("</section>[^<]*</div>")
if not start or not stop then
  io.stderr:write(path, ": no slides found\n")
  os.exit(1)
end
local slides = html:sub(start, stop + #"</section>" - 1)

slides = slides:gsub(' id="[^"]*"', "")
slides = slides:gsub('class="([^"]*)"', function(classes)
  local kept = {}
  for class in classes:gmatch("%S+") do
    if class ~= "title-slides-continuation" and class ~= "unlisted" then
      kept[#kept + 1] = class
    end
  end
  return 'class="' .. table.concat(kept, " ") .. '"'
end)

-- Collapse runs of whitespace so that indentation differences never fail a comparison.
for line in slides:gmatch("[^\n]+") do
  local trimmed = line:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
  if trimmed ~= "" then print(trimmed) end
end
