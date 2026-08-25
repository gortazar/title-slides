-- `show-index: true` must never silently do nothing.
--
-- 0.4 warned that the reporter's deck had "no sections", because the index was keyed off
-- `#` headings and the deck had none. From 0.5 that deck is exactly what the index is
-- for — its fourteen `##` slides — so it gets an index and no warning at all. What is
-- left to warn about is a deck with no slide-starting headings: none written, all of them
-- hidden, or a `slide-level` under which no heading starts a slide.
--
-- Nothing is ever invented for such a deck; the warning is the whole of the response.

local t = dofile(debug.getinfo(1, "S").source:sub(2):gsub("[^/]*$", "") .. "../harness.lua")

local function H(level, text, attr)
  return pandoc.Header(level, { pandoc.Str(text) }, attr)
end
local function P(text) return pandoc.Para({ pandoc.Str(text) }) end
local HR = pandoc.HorizontalRule()

--- A deck of nothing but a title page: `#` starts no slide, so there is nothing to index.
local function title_page_only()
  return { H(1, "Deck title", pandoc.Attr("deck")), P("a") }
end

local function only(warnings)
  t.eq(#warnings, 1, "exactly one warning")
  return warnings[1]
end

-- The flip this entry is about: what used to warn now gets an index.
t.case("a deck of ## slides is indexed, not warned about", function()
  local blocks = {
    H(2, "Definición", pandoc.Attr("definicion")), P("a"),
    H(2, "Llamado", pandoc.Attr("llamado")), P("b"),
  }
  local doc, warnings = t.apply_capturing_warnings(t.doc(blocks, t.index_on()))
  t.eq(#warnings, 0, "no warning")
  t.eq(#t.marked(doc, "title-slides-index"), 2, "an index before each slide")
end)

t.case("a deck with no slide-level headings is warned about", function()
  local _, warnings = t.apply_capturing_warnings(t.doc(title_page_only(), t.index_on()))
  t.eq(#warnings, 1, "one warning")
end)

t.case("the warning names the key that did nothing", function()
  local _, warnings = t.apply_capturing_warnings(t.doc(title_page_only(), t.index_on()))
  t.eq(only(warnings):match("show%-index") ~= nil, true, "names show-index")
end)

t.case("the warning names the heading level an index lists", function()
  local _, warnings = t.apply_capturing_warnings(t.doc(title_page_only(), t.index_on()))
  t.eq(only(warnings):match("##") ~= nil, true, "names ## as the level that starts slides")
end)

t.case("nothing at all is inserted when there is nothing to index", function()
  local doc = t.apply_capturing_warnings(t.doc(title_page_only(), t.index_on()))
  t.shape_eq(doc, "H1(Deck title) P(a)")
end)

t.case("it warns once for the document, not once per heading", function()
  local blocks = {
    H(1, "One", pandoc.Attr("one")), P("a"),
    H(1, "Two", pandoc.Attr("two")), P("b"),
    H(1, "Three", pandoc.Attr("three")), P("c"),
  }
  local _, warnings = t.apply_capturing_warnings(t.doc(blocks, t.index_on()))
  t.eq(#warnings, 1, "one warning for the whole document")
end)

t.case("a deck with no headings at all is warned about", function()
  local _, warnings = t.apply_capturing_warnings(t.doc({ P("just text") }, t.index_on()))
  t.eq(#warnings, 1, "one warning")
end)

t.case("show-index off means no warning, however empty the deck", function()
  local _, warnings = t.apply_capturing_warnings(t.doc(title_page_only(), t.on()))
  t.eq(#warnings, 0, "the carry does not warn about the index")
end)

t.case("neither key set means no warning", function()
  local _, warnings = t.apply_capturing_warnings(t.doc(title_page_only(), {}))
  t.eq(#warnings, 0, "an untouched document says nothing")
end)

t.case("all slides hidden is reported as such, not as having none", function()
  local blocks = {
    H(2, "Secret", pandoc.Attr("secret", { "unlisted" }, {})), P("a"),
    H(2, "Also secret", pandoc.Attr("also", {}, { { "visibility", "hidden" } })), P("b"),
  }
  local _, warnings = t.apply_capturing_warnings(t.doc(blocks, t.index_on()))
  t.eq(only(warnings):match("hidden") ~= nil, true, "says the headings are hidden")
end)

t.case("one visible slide among hidden ones is indexed, and does not warn", function()
  local blocks = {
    H(2, "Secret", pandoc.Attr("secret", { "unlisted" }, {})), P("a"),
    H(2, "Shown", pandoc.Attr("shown")), P("b"),
  }
  local doc, warnings = t.apply_capturing_warnings(t.doc(blocks, t.index_on()))
  t.eq(#warnings, 0, "no warning")
  t.eq(#t.marked(doc, "title-slides-index"), 1, "the visible slide got its index")
end)

t.case("slide-level 1 indexes # headings rather than warning", function()
  local blocks = { H(1, "Part", pandoc.Attr("part")), P("a") }
  local doc, warnings = t.apply_capturing_warnings(
    t.doc(blocks, t.index_on({ ["slide-level"] = 1 })))
  t.eq(#warnings, 0, "no warning: at slide-level 1, # starts a slide")
  t.eq(#t.marked(doc, "title-slides-index"), 1, "and is indexed")
end)

t.case("slide-level 0 is reported as the reason nothing starts a slide", function()
  local blocks = { H(2, "One", pandoc.Attr("one")), P("a") }
  local _, warnings = t.apply_capturing_warnings(
    t.doc(blocks, t.index_on({ ["slide-level"] = 0 })))
  t.eq(only(warnings):match("slide%-level") ~= nil, true, "names slide-level")
end)

t.case("a deck whose only ## is nested in a div is warned about", function()
  local div = pandoc.Div({ H(2, "Inside", pandoc.Attr("inside")), P("a") })
  local _, warnings = t.apply_capturing_warnings(t.doc({ div }, t.index_on()))
  t.eq(#warnings, 1, "a nested heading starts no slide, so there is nothing to index")
end)

t.case("both features on together: the carry works and the deck is indexed", function()
  local blocks = { H(2, "Intro", pandoc.Attr("intro")), P("a"), HR, P("b") }
  local meta = t.on({ ["show-index"] = true })
  local doc, warnings = t.apply_capturing_warnings(t.doc(blocks, meta))
  t.eq(#t.marked(doc, "title-slides-continuation"), 1, "the title was carried")
  t.eq(#t.marked(doc, "title-slides-index"), 1, "and the one real slide got its index")
  t.eq(#warnings, 0, "with nothing to complain about")
end)

t.run()
