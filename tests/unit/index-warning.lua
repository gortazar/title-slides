-- `show-index: true` must never silently do nothing.
--
-- The report that prompted this was a deck that asked for an index in good faith, got no
-- index, and got no explanation either. The deck had fourteen `##` headings and no `#`, so
-- it had no sections and there was nothing to index — which is correct behaviour, but
-- indistinguishable from a broken extension.
--
-- The decision (this entry's first open question) is that **no agenda is invented** for
-- such a deck: nothing is inserted. What changes is that the filter says so.

local t = dofile(debug.getinfo(1, "S").source:sub(2):gsub("[^/]*$", "") .. "../harness.lua")

local function H(level, text, attr)
  return pandoc.Header(level, { pandoc.Str(text) }, attr)
end
local function P(text) return pandoc.Para({ pandoc.Str(text) }) end
local HR = pandoc.HorizontalRule()

--- A deck shaped like the reporter's: slide-level headings only, no sections.
local function section_less()
  return {
    H(2, "Definición", pandoc.Attr("definicion")), P("a"),
    H(2, "Llamado", pandoc.Attr("llamado")), P("b"),
  }
end

local function sectioned()
  return { H(1, "Part", pandoc.Attr("part")), H(2, "Slide", pandoc.Attr("slide")), P("a") }
end

local function only(warnings)
  t.eq(#warnings, 1, "exactly one warning")
  return warnings[1]
end

t.case("a deck with no sections is warned about", function()
  local _, warnings = t.apply_capturing_warnings(t.doc(section_less(), t.index_on()))
  t.eq(#warnings, 1, "one warning")
end)

t.case("the warning names the key that did nothing", function()
  local _, warnings = t.apply_capturing_warnings(t.doc(section_less(), t.index_on()))
  t.eq(only(warnings):match("show%-index") ~= nil, true, "names show-index")
end)

t.case("the warning gives the reason: the deck has no section headings", function()
  local _, warnings = t.apply_capturing_warnings(t.doc(section_less(), t.index_on()))
  local message = only(warnings)
  t.eq(message:match("no section") ~= nil, true, "says there are no sections")
  t.eq(message:match("#") ~= nil, true, "names the heading level that makes one")
end)

t.case("nothing at all is inserted — no agenda is invented", function()
  local doc = t.apply_capturing_warnings(t.doc(section_less(), t.index_on()))
  t.shape_eq(doc, "H2(Definición) P(a) H2(Llamado) P(b)")
end)

t.case("it warns once for the document, not once per slide", function()
  local blocks = {
    H(2, "One", pandoc.Attr("one")), P("a"),
    H(2, "Two", pandoc.Attr("two")), P("b"),
    H(2, "Three", pandoc.Attr("three")), P("c"),
  }
  local _, warnings = t.apply_capturing_warnings(t.doc(blocks, t.index_on()))
  t.eq(#warnings, 1, "one warning for the whole document")
end)

t.case("a deck with sections is not warned about", function()
  local _, warnings = t.apply_capturing_warnings(t.doc(sectioned(), t.index_on()))
  t.eq(#warnings, 0, "no warning")
end)

t.case("a deck with no headings at all is still warned about", function()
  local _, warnings = t.apply_capturing_warnings(t.doc({ P("just text") }, t.index_on()))
  t.eq(#warnings, 1, "one warning")
end)

t.case("show-index off means no warning, however empty the deck", function()
  local _, warnings = t.apply_capturing_warnings(t.doc(section_less(), t.on()))
  t.eq(#warnings, 0, "the carry does not warn about the index")
end)

t.case("neither key set means no warning", function()
  local _, warnings = t.apply_capturing_warnings(t.doc(section_less(), {}))
  t.eq(#warnings, 0, "an untouched document says nothing")
end)

t.case("all sections hidden is reported as such, not as having none", function()
  local blocks = {
    H(1, "Secret", pandoc.Attr("secret", { "unlisted" }, {})), P("a"),
    H(1, "Also secret", pandoc.Attr("also", {}, { { "visibility", "hidden" } })), P("b"),
  }
  local _, warnings = t.apply_capturing_warnings(t.doc(blocks, t.index_on()))
  local message = only(warnings)
  t.eq(message:match("hidden") ~= nil, true, "says the sections are hidden")
end)

t.case("one visible section among hidden ones is indexed, and does not warn", function()
  local blocks = {
    H(1, "Secret", pandoc.Attr("secret", { "unlisted" }, {})), P("a"),
    H(1, "Shown", pandoc.Attr("shown")), P("b"),
  }
  local doc, warnings = t.apply_capturing_warnings(t.doc(blocks, t.index_on()))
  t.eq(#warnings, 0, "no warning")
  t.eq(#t.marked(doc, "title-slides-index"), 1, "the visible section got its index")
end)

t.case("slide-level 1 is reported as the reason it has no sections", function()
  local blocks = { H(1, "Part", pandoc.Attr("part")), P("a") }
  local _, warnings = t.apply_capturing_warnings(
    t.doc(blocks, t.index_on({ ["slide-level"] = 1 })))
  t.eq(only(warnings):match("slide%-level") ~= nil, true, "names slide-level")
end)

t.case("slide-level 0 is reported the same way", function()
  local blocks = { H(1, "Part", pandoc.Attr("part")), P("a") }
  local _, warnings = t.apply_capturing_warnings(
    t.doc(blocks, t.index_on({ ["slide-level"] = 0 })))
  t.eq(only(warnings):match("slide%-level") ~= nil, true, "names slide-level")
end)

t.case("a single slide-level heading and nothing else still warns", function()
  local _, warnings = t.apply_capturing_warnings(
    t.doc({ H(2, "Only", pandoc.Attr("only")) }, t.index_on()))
  t.eq(#warnings, 1, "one warning")
end)

t.case("both features on together: the carry still works and the index warns", function()
  local blocks = { H(2, "Intro", pandoc.Attr("intro")), P("a"), HR, P("b") }
  local meta = t.on({ ["show-index"] = true })
  local doc, warnings = t.apply_capturing_warnings(t.doc(blocks, meta))
  t.eq(#t.marked(doc, "title-slides-continuation"), 1, "the title was carried")
  t.eq(#warnings, 1, "and the index explained itself")
end)

t.run()
