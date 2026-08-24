-- The extension now does two independent things, each with its own frontmatter key:
-- `title-slides` carries titles onto continuation slides, `show-index` puts an index
-- slide before every section. Either key switches the filter on; neither implies the
-- other. This file pins the gating, whatever the two features go on to do.

local t = dofile(debug.getinfo(1, "S").source:sub(2):gsub("[^/]*$", "") .. "../harness.lua")

local function H(level, text) return pandoc.Header(level, { pandoc.Str(text) }) end
local function P(text) return pandoc.Para({ pandoc.Str(text) }) end
local HR = pandoc.HorizontalRule()

-- A document with both a section to index and a rule to carry a title onto.
local function blocks()
  return { H(1, "Part one"), H(2, "Intro"), P("a"), HR, P("b") }
end

local function carried(doc) return #t.marked(doc, "title-slides-continuation") end
local function indexes(doc) return #t.marked(doc, "title-slides-index") end

t.case("neither key: the document is untouched", function()
  local doc = t.apply(t.doc(blocks(), {}))
  t.shape_eq(doc, "H1(Part one) H2(Intro) P(a) HR P(b)")
end)

t.case("title-slides alone carries titles", function()
  local doc = t.apply(t.doc(blocks(), t.on()))
  t.eq(carried(doc), 1, "continuation headings")
end)

t.case("title-slides alone injects no index", function()
  local doc = t.apply(t.doc(blocks(), t.on()))
  t.eq(indexes(doc), 0, "index headings")
end)

t.case("show-index alone does not carry titles", function()
  local doc = t.apply(t.doc(blocks(), t.index_on()))
  t.eq(carried(doc), 0, "continuation headings")
end)

t.case("both keys: titles are carried", function()
  local doc = t.apply(t.doc(blocks(), t.on({ ["show-index"] = true })))
  t.eq(carried(doc), 1, "continuation headings")
end)

t.case("show-index: false is off", function()
  local doc = t.apply(t.doc(blocks(), { ["show-index"] = false }))
  t.eq(indexes(doc), 0, "index headings")
  t.shape_eq(doc, "H1(Part one) H2(Intro) P(a) HR P(b)")
end)

t.case("title-slides: false with show-index: true carries nothing", function()
  local doc = t.apply(t.doc(blocks(), { ["title-slides"] = false, ["show-index"] = true }))
  t.eq(carried(doc), 0, "continuation headings")
end)

t.run()
