-- Print the outline of a rendered revealjs deck: one line per slide, giving its level,
-- what kind of slide it is — one the author wrote, a continuation the extension titled,
-- or an index it injected — and its title. Index slides also report the entry that came
-- out emboldened, which is the part of `show-index` worth asserting on.
--
-- Usage: pandoc lua deck-outline.lua deck.html

local path = arg[1]
if not path then
  io.stderr:write("usage: pandoc lua deck-outline.lua <deck.html>\n")
  os.exit(2)
end

local handle = assert(io.open(path, "r"))
local html = handle:read("a")
handle:close()

-- A `#` section slide wraps its `##` slides in an outer <section>, so the openings have
-- to be walked by position: matching a whole <section>…</section> would swallow the
-- nested ones. Each slide's title is the first heading before the next <section> opens.
local openings = {}
for at, tag in html:gmatch("()<section([^>]*)>") do
  openings[#openings + 1] = { at = at, tag = tag }
end

for i, opening in ipairs(openings) do
  local stop = openings[i + 1] and openings[i + 1].at or #html
  local body = html:sub(opening.at, stop)

  local classes = opening.tag:match('class="([^"]*)"') or ""
  if classes:match("slide") then
    local level = classes:match("level(%d)") or "-"
    local kind = "slide"
    if classes:match("title%-slides%-continuation") then
      kind = "continuation"
    elseif classes:match("title%-slides%-index") then
      kind = "index"
    end

    local title = body:match("<h%d[^>]*>(.-)</h%d>") or ""
    title = title:gsub("<[^>]*>", ""):gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")

    if kind == "index" then
      -- Which entry is bold is the whole point of an index slide, so name it, and count
      -- them so a second bold entry cannot slip by unnoticed.
      local current, bolds = nil, 0
      for entry in body:gmatch("<strong>(.-)</strong>") do
        bolds = bolds + 1
        current = current or entry:gsub("<[^>]*>", "")
      end
      print(string.format("%s %s %s -> %s (%d bold)", level, kind, title,
        current or "(none)", bolds))
    else
      print(string.format("%s %s %s", level, kind, title))
    end
  end
end
