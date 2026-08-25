-- `show-index: true` puts an index slide before every slide-level heading — `##` at
-- Quarto's default — listing the headings that start slides, with the one it introduces
-- in bold.
--
-- Until 0.4 the index was keyed off headings *below* the slide level (`#`), which is the
-- one level guaranteed not to start a slide: `#` is the deck's title page. A deck of `##`
-- slides therefore got no index at all, which is what was reported. From 0.5 the index
-- lists the headings that start slides, and `#` is neither listed nor given an index.

local t = dofile(debug.getinfo(1, "S").source:sub(2):gsub("[^/]*$", "") .. "../harness.lua")

local function H(level, text, attr)
  return pandoc.Header(level, { pandoc.Str(text) }, attr)
end
local function P(text) return pandoc.Para({ pandoc.Str(text) }) end
local HR = pandoc.HorizontalRule()

--- The index slides of a document: each marked heading with the list that follows it.
local function index_slides(doc)
  local found = {}
  for i, block in ipairs(doc.blocks) do
    if block.t == "Header" and block.classes:includes("title-slides-index") then
      found[#found + 1] = { at = i, heading = block, list = doc.blocks[i + 1] }
    end
  end
  return found
end

--- The entries of an index's bullet list, the bold one wrapped in asterisks.
local function entries(list)
  if list == nil or list.t ~= "BulletList" then return "(no list)" end
  local out = {}
  for _, item in ipairs(list.content) do
    local text = pandoc.utils.stringify(item)
    local bold = false
    pandoc.Div(item):walk({ Strong = function() bold = true end })
    out[#out + 1] = bold and ("*" .. text .. "*") or text
  end
  return table.concat(out, " | ")
end

local function three_slides()
  return {
    H(2, "One", pandoc.Attr("one")), P("a"),
    H(2, "Two", pandoc.Attr("two")), P("b"),
    H(2, "Three", pandoc.Attr("three")), P("c"),
  }
end

t.case("one index slide per slide-level heading", function()
  local doc = t.apply(t.doc(three_slides(), t.index_on()))
  t.eq(#index_slides(doc), 3, "index slides")
end)

t.case("the index slide comes immediately before its slide", function()
  local doc = t.apply(t.doc({ H(2, "One", pandoc.Attr("one")), P("a") }, t.index_on()))
  t.shape_eq(doc, "H2(Outline) BulletList H2(One) P(a)")
end)

t.case("every index lists every slide-level heading, in document order", function()
  local doc = t.apply(t.doc(three_slides(), t.index_on()))
  for _, index in ipairs(index_slides(doc)) do
    t.eq((entries(index.list):gsub("%*", "")), "One | Two | Three", "entries")
  end
end)

t.case("the heading the index precedes is the bold one", function()
  local doc = t.apply(t.doc(three_slides(), t.index_on()))
  local found = index_slides(doc)
  t.eq(entries(found[1].list), "*One* | Two | Three", "first index")
  t.eq(entries(found[2].list), "One | *Two* | Three", "second index")
  t.eq(entries(found[3].list), "One | Two | *Three*", "third index")
end)

t.case("the bold entry carries the current-entry span class", function()
  local doc = t.apply(t.doc(three_slides(), t.index_on()))
  local marked = 0
  pandoc.Div(index_slides(doc)[2].list):walk({
    Span = function(span)
      if span.classes:includes("title-slides-index-current") then marked = marked + 1 end
    end,
  })
  t.eq(marked, 1, "spans marked as the current entry")
end)

-- `#` is the deck's title page, which is the whole reason the level moved.
t.case("a # heading is never listed on an index", function()
  local blocks = { H(1, "Deck title", pandoc.Attr("deck")), H(2, "One", pandoc.Attr("one")), P("a") }
  local doc = t.apply(t.doc(blocks, t.index_on()))
  t.eq(entries(index_slides(doc)[1].list), "*One*", "only the ## heading is listed")
end)

t.case("a # heading gets no index slide of its own", function()
  local blocks = { H(1, "Deck title", pandoc.Attr("deck")), H(2, "One", pandoc.Attr("one")), P("a") }
  local doc = t.apply(t.doc(blocks, t.index_on()))
  t.shape_eq(doc, "H1(Deck title) H2(Outline) BulletList H2(One) P(a)")
end)

t.case("a title page followed by several slides indexes only the slides", function()
  local blocks = {
    H(1, "Deck", pandoc.Attr("deck")),
    H(2, "One", pandoc.Attr("one")), P("a"),
    H(2, "Two", pandoc.Attr("two")), P("b"),
  }
  local doc = t.apply(t.doc(blocks, t.index_on()))
  t.eq(#index_slides(doc), 2, "index slides")
  t.eq((entries(index_slides(doc)[1].list):gsub("%*", "")), "One | Two", "entries")
end)

t.case("the index heading is the document title", function()
  local meta = t.index_on({ title = pandoc.Inlines({ pandoc.Str("My deck") }) })
  local doc = t.apply(t.doc(three_slides(), meta))
  t.eq(pandoc.utils.stringify(index_slides(doc)[1].heading.content), "My deck")
end)

t.case("with no title, the index heading is Outline", function()
  local doc = t.apply(t.doc(three_slides(), t.index_on()))
  t.eq(pandoc.utils.stringify(index_slides(doc)[1].heading.content), "Outline")
end)

t.case("index headings get derived, unique identifiers", function()
  local doc = t.apply(t.doc(three_slides(), t.index_on()))
  local ids = {}
  for _, index in ipairs(index_slides(doc)) do ids[#ids + 1] = index.heading.identifier end
  t.eq(table.concat(ids, " "), "one-index-1 two-index-1 three-index-1")
end)

t.case("an identifier already taken is skipped", function()
  local blocks = {
    H(2, "One", pandoc.Attr("one")), P("a"),
    H(3, "Taken", pandoc.Attr("one-index-1")), P("b"),
  }
  local doc = t.apply(t.doc(blocks, t.index_on()))
  t.eq(index_slides(doc)[1].heading.identifier, "one-index-2")
end)

t.case("index headings are unlisted, so repeats do not fill the table of contents", function()
  local doc = t.apply(t.doc(three_slides(), t.index_on()))
  for _, index in ipairs(index_slides(doc)) do
    t.eq(index.heading.classes:includes("unlisted"), true, "unlisted")
  end
end)

t.case("the index heading is emitted at the slide level", function()
  local blocks = { H(3, "Topic", pandoc.Attr("topic")), P("a") }
  local doc = t.apply(t.doc(blocks, t.index_on({ ["slide-level"] = 3 })))
  t.eq(index_slides(doc)[1].heading.level, 3, "heading level")
end)

t.case("at slide-level 3 it is ### that is indexed, not ##", function()
  local blocks = {
    H(2, "Section", pandoc.Attr("section")),
    H(3, "Topic", pandoc.Attr("topic")), P("a"),
  }
  local doc = t.apply(t.doc(blocks, t.index_on({ ["slide-level"] = 3 })))
  t.eq(entries(index_slides(doc)[1].list), "*Topic*", "only the ### heading is listed")
end)

t.case("at slide-level 1 it is # that is indexed", function()
  local blocks = { H(1, "Part", pandoc.Attr("part")), P("a"), H(1, "Other", pandoc.Attr("other")), P("b") }
  local doc = t.apply(t.doc(blocks, t.index_on({ ["slide-level"] = 1 })))
  t.eq(#index_slides(doc), 2, "index slides")
  t.eq(index_slides(doc)[1].heading.level, 1, "its own heading is a #")
end)

t.case("a hidden slide keeps off the index and gets no index slide", function()
  local hidden = H(2, "Secret", pandoc.Attr("secret", { "unlisted" }, {}))
  local blocks = { H(2, "One", pandoc.Attr("one")), P("a"), hidden, P("b") }
  local doc = t.apply(t.doc(blocks, t.index_on()))
  t.eq(#index_slides(doc), 1, "index slides")
  t.eq(entries(index_slides(doc)[1].list), "*One*", "entries")
end)

t.case("a slide hidden with visibility is treated the same", function()
  local hidden = H(2, "Secret", pandoc.Attr("secret", {}, { { "visibility", "hidden" } }))
  local blocks = { H(2, "One", pandoc.Attr("one")), P("a"), hidden, P("b") }
  local doc = t.apply(t.doc(blocks, t.index_on()))
  t.eq(#index_slides(doc), 1, "index slides")
  t.eq(entries(index_slides(doc)[1].list), "*One*", "entries")
end)

t.case("a heading nested in a div starts no slide and is not indexed", function()
  local div = pandoc.Div({ H(2, "Inside", pandoc.Attr("inside")), P("a") })
  local doc, warnings = t.apply_capturing_warnings(t.doc({ div }, t.index_on()))
  t.shape_eq(doc, "Div")
  t.eq(#warnings, 1, "and the deck is told it has nothing to index")
end)

t.case("a deck with only # headings has nothing to index, and is told so", function()
  local blocks = { H(1, "Deck", pandoc.Attr("deck")), P("a") }
  local doc, warnings = t.apply_capturing_warnings(t.doc(blocks, t.index_on()))
  t.shape_eq(doc, "H1(Deck) P(a)")
  t.eq(#warnings, 1, "warned rather than silently doing nothing")
end)

t.case("slide-level 0 leaves show-index inert, and says why", function()
  local doc, warnings = t.apply_capturing_warnings(
    t.doc({ H(2, "One", pandoc.Attr("one")), P("a") }, t.index_on({ ["slide-level"] = 0 })))
  t.shape_eq(doc, "H2(One) P(a)")
  t.eq(#warnings, 1, "warned rather than silently doing nothing")
end)

t.case("a single slide still gets its index", function()
  local doc = t.apply(t.doc({ H(2, "Only", pandoc.Attr("only")), P("a") }, t.index_on()))
  t.eq(entries(index_slides(doc)[1].list), "*Only*", "entries")
end)

t.case("an empty trailing slide still gets its index", function()
  local blocks = { H(2, "One", pandoc.Attr("one")), P("a"), H(2, "Two", pandoc.Attr("two")) }
  local doc = t.apply(t.doc(blocks, t.index_on()))
  t.eq(#index_slides(doc), 2, "index slides")
  t.shape_eq(doc,
    "H2(Outline) BulletList H2(One) P(a) H2(Outline) BulletList H2(Two)")
end)

-- Generated headings sit at the slide level, which is exactly what the index now looks
-- for. In practice they also carry `unlisted`, so the hidden check would exclude them
-- anyway — this pins the rule that matters rather than relying on that coincidence, and
-- fails if the generated check is dropped.
t.case("a heading the extension generated is never indexed", function()
  local generated = pandoc.Header(2, { pandoc.Str("Intro") },
    pandoc.Attr("gen", { "title-slides-continuation" }, {}))
  local blocks = { H(2, "Intro", pandoc.Attr("intro")), P("a"), generated, P("b") }
  local doc = t.apply(t.doc(blocks, t.index_on()))
  t.eq(#index_slides(doc), 1, "only the author's heading got an index slide")
  t.eq(entries(index_slides(doc)[1].list), "*Intro*", "and only it is listed")
end)

t.case("a rule-started slide is not a heading and so is not indexed", function()
  local blocks = { H(2, "One", pandoc.Attr("one")), P("a"), HR, P("b") }
  local doc = t.apply(t.doc(blocks, t.index_on()))
  t.eq(entries(index_slides(doc)[1].list), "*One*", "only the heading is listed")
end)

t.run()
