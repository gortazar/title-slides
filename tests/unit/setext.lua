-- The setext trap: text immediately followed by dashes is a heading, not a slide break.
-- The scanner has to find those in the source without crying wolf over the frontmatter,
-- real thematic breaks, tables or code samples.

local here = debug.getinfo(1, "S").source:sub(2):gsub("[^/]*$", "")
local t = dofile(here .. "../harness.lua")
local setext = dofile(here .. "../../_extensions/title-slides/setext.lua")

local function found_in(text)
  local out = {}
  for _, f in ipairs(setext.find(text)) do
    out[#out + 1] = f.line .. ":" .. f.title
  end
  return table.concat(out, ", ")
end

t.case("finds text followed immediately by dashes", function()
  t.eq(found_in("## Intro\n\nblabla\n---\n\nmore\n"), "4:blabla")
end)

t.case("accepts two dashes, which underline but do not break", function()
  t.eq(found_in("blabla\n--\n"), "2:blabla")
end)

t.case("ignores a rule with a blank line before it", function()
  t.eq(found_in("## Intro\n\nblabla\n\n---\n\nmore\n"), "")
end)

t.case("ignores the YAML frontmatter delimiters", function()
  t.eq(found_in("---\ntitle: t\nformat: revealjs\n---\n\n## Intro\n\na\n"), "")
end)

t.case("still finds a setext heading below the frontmatter", function()
  t.eq(found_in("---\ntitle: t\n---\n\n## Intro\n\nblabla\n---\n\nmore\n"), "8:blabla")
end)

t.case("ignores dashes inside a fenced code block", function()
  t.eq(found_in("## Intro\n\n```\nblabla\n---\n```\n\nmore\n"), "")
end)

t.case("ignores dashes inside a tilde-fenced block", function()
  t.eq(found_in("~~~\nblabla\n---\n~~~\n"), "")
end)

t.case("resumes scanning after a code block closes", function()
  t.eq(found_in("```\ncode\n```\n\nblabla\n---\n"), "6:blabla")
end)

t.case("ignores a table's header separator", function()
  t.eq(found_in("| a | b |\n|---|---|\n| 1 | 2 |\n"), "")
end)

t.case("ignores a dashed line under a list item", function()
  t.eq(found_in("- an item\n---\n"), "")
end)

t.case("ignores a dashed line under a heading", function()
  t.eq(found_in("## Intro\n---\n"), "")
end)

t.case("ignores a dashed line under a block quote", function()
  t.eq(found_in("> quoted\n---\n"), "")
end)

t.case("finds every occurrence", function()
  t.eq(found_in("a\n---\n\nb\n---\n"), "2:a, 5:b")
end)

t.case("the message names the file, the line and what will happen", function()
  local finding = setext.find("blabla\n---\n")[1]
  local message = setext.message("deck.qmd", finding)
  t.eq(message:match("deck%.qmd:2") ~= nil, true, "names file and line")
  t.eq(message:match("blank line") ~= nil, true, "says how to fix it")
end)

t.run()
