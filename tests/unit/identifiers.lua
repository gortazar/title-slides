-- A copied heading must not copy the original's identifier: duplicate anchors break
-- in-deck links, the reveal menu and cross-references. Each continuation gets a fresh
-- identifier derived from the original, and is marked so it can be styled and kept out
-- of tables of contents.

local t = dofile(debug.getinfo(1, "S").source:sub(2):gsub("[^/]*$", "") .. "../harness.lua")

local function H(level, text, attr)
  return pandoc.Header(level, { pandoc.Str(text) }, attr)
end
local function P(text) return pandoc.Para({ pandoc.Str(text) }) end
local HR = pandoc.HorizontalRule()

--- The headings of a document, in order.
local function headings(doc)
  local hs = {}
  for _, b in ipairs(doc.blocks) do
    if b.t == "Header" then hs[#hs + 1] = b end
  end
  return hs
end

local function ids(doc)
  local out = {}
  for _, h in ipairs(headings(doc)) do out[#out + 1] = h.identifier end
  return table.concat(out, " ")
end

t.case("the original heading keeps its identifier", function()
  local doc = t.doc({ H(2, "Introduction", pandoc.Attr("introduction")), P("a"), HR, P("b") }, t.on())
  t.eq(headings(t.apply(doc))[1].identifier, "introduction")
end)

t.case("a continuation gets a derived identifier, not the original's", function()
  local doc = t.doc({ H(2, "Introduction", pandoc.Attr("introduction")), P("a"), HR, P("b") }, t.on())
  t.eq(ids(t.apply(doc)), "introduction introduction-cont-1")
end)

t.case("successive continuations are numbered", function()
  local doc = t.doc({
    H(2, "Introduction", pandoc.Attr("introduction")), P("a"), HR, P("b"), HR, P("c"),
  }, t.on())
  t.eq(ids(t.apply(doc)), "introduction introduction-cont-1 introduction-cont-2")
end)

t.case("numbering restarts for each heading", function()
  local doc = t.doc({
    H(2, "One", pandoc.Attr("one")), P("a"), HR, P("b"),
    H(2, "Two", pandoc.Attr("two")), P("c"), HR, P("d"),
  }, t.on())
  t.eq(ids(t.apply(doc)), "one one-cont-1 two two-cont-1")
end)

t.case("a derived identifier already taken elsewhere is skipped", function()
  local doc = t.doc({
    H(2, "Introduction", pandoc.Attr("introduction")), P("a"), HR, P("b"),
    H(2, "Taken", pandoc.Attr("introduction-cont-1")), P("c"),
  }, t.on())
  -- The first free name is used, so nothing collides with the hand-written heading.
  t.eq(ids(t.apply(doc)), "introduction introduction-cont-2 introduction-cont-1")
end)

t.case("a heading with no identifier yields one derived from its text", function()
  local doc = t.doc({ H(2, "My Slide", pandoc.Attr("")), P("a"), HR, P("b") }, t.on())
  t.eq(ids(t.apply(doc)), " my-slide-cont-1")
end)

t.case("a continuation carries the continuation class", function()
  local doc = t.doc({ H(2, "Introduction", pandoc.Attr("introduction")), P("a"), HR, P("b") }, t.on())
  local h = headings(t.apply(doc))[2]
  t.eq(h.classes:includes("title-slides-continuation"), true, "continuation class")
end)

t.case("a continuation is unlisted, so it stays out of tables of contents", function()
  local doc = t.doc({ H(2, "Introduction", pandoc.Attr("introduction")), P("a"), HR, P("b") }, t.on())
  local h = headings(t.apply(doc))[2]
  t.eq(h.classes:includes("unlisted"), true, "unlisted class")
end)

t.case("the original heading gains no classes", function()
  local doc = t.doc({ H(2, "Introduction", pandoc.Attr("introduction")), P("a"), HR, P("b") }, t.on())
  t.eq(#headings(t.apply(doc))[1].classes, 0, "original classes untouched")
end)

t.case("a continuation keeps the original's text and level", function()
  local doc = t.doc({ H(2, "Introduction", pandoc.Attr("introduction")), P("a"), HR, P("b") }, t.on())
  local h = headings(t.apply(doc))[2]
  t.eq(pandoc.utils.stringify(h.content), "Introduction")
  t.eq(h.level, 2)
end)

t.run()
