-- Print how many entries the first index slide of a rendered deck lists.
--
-- The count is what the collapsing rule is about: a deck that repeats a `##` across
-- several slides lists that title once, so the number of entries is smaller than the
-- number of slides.
--
-- Usage: pandoc lua index-entries.lua deck.html

local path = arg[1]
if not path then
  io.stderr:write("usage: pandoc lua index-entries.lua <deck.html>\n")
  os.exit(2)
end

local handle = assert(io.open(path, "r"))
local html = handle:read("a")
handle:close()

local at = html:find('class="[^"]*title%-slides%-index[^"]*"')
if not at then
  io.stderr:write(path, ": no index slide found\n")
  os.exit(1)
end

-- The list belongs to the index slide, so stop at the end of that <section>.
local section_end = html:find("</section>", at, true) or #html
local list = html:sub(at, section_end)

local entries = 0
for _ in list:gmatch("<li>") do entries = entries + 1 end
print(entries)
