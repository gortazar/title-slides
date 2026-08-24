-- `show-index: true` puts an index slide before every section: a slide-level heading
-- followed by a bullet list of every section in the deck, with the one that comes next
-- in bold. This is beamer's \AtBeginSection habit, brought to a Quarto deck.

local t = dofile(debug.getinfo(1, "S").source:sub(2):gsub("[^/]*$", "") .. "../harness.lua")

local function H(level, text, attr)
  return pandoc.Header(level, { pandoc.Str(text) }, attr)
end
local function P(text) return pandoc.Para({ pandoc.Str(text) }) end
local HR = pandoc.HorizontalRule()

--- The index slides of a document: each heading marked as an index, with the list that
--- follows it.
local function index_slides(doc)
  local found = {}
  for i, block in ipairs(doc.blocks) do
    if block.t == "Header" and block.classes:includes("title-slides-index") then
      found[#found + 1] = { at = i, heading = block, list = doc.blocks[i + 1] }
    end
  end
  return found
end

--- The entries of an index's bullet list, with the bold one wrapped in asterisks.
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

local function three_sections()
  return {
    H(1, "One", pandoc.Attr("one")), P("a"),
    H(1, "Two", pandoc.Attr("two")), P("b"),
    H(1, "Three", pandoc.Attr("three")), P("c"),
  }
end

t.case("one index slide per section", function()
  local doc = t.apply(t.doc(three_sections(), t.index_on()))
  t.eq(#index_slides(doc), 3, "index slides")
end)

t.case("the index slide comes immediately before its section", function()
  local doc = t.apply(t.doc({ H(1, "One", pandoc.Attr("one")), P("a") }, t.index_on()))
  t.shape_eq(doc, "H2(Outline) BulletList H1(One) P(a)")
end)

t.case("every index lists every section, in document order", function()
  local doc = t.apply(t.doc(three_sections(), t.index_on()))
  for _, index in ipairs(index_slides(doc)) do
    local text = entries(index.list):gsub("%*", "")
    t.eq(text, "One | Two | Three", "entries")
  end
end)

t.case("the section the index precedes is the bold one", function()
  local doc = t.apply(t.doc(three_sections(), t.index_on()))
  local found = index_slides(doc)
  t.eq(entries(found[1].list), "*One* | Two | Three", "first index")
  t.eq(entries(found[2].list), "One | *Two* | Three", "second index")
  t.eq(entries(found[3].list), "One | Two | *Three*", "third index")
end)

t.case("exactly one entry per index is bold", function()
  local doc = t.apply(t.doc(three_sections(), t.index_on()))
  for _, index in ipairs(index_slides(doc)) do
    local _, bolds = entries(index.list):gsub("%*(.-)%*", "")
    t.eq(bolds, 1, "bold entries")
  end
end)

t.case("the bold entry carries the current-entry span class", function()
  local doc = t.apply(t.doc(three_sections(), t.index_on()))
  local marked = 0
  pandoc.Div(index_slides(doc)[2].list):walk({
    Span = function(span)
      if span.classes:includes("title-slides-index-current") then marked = marked + 1 end
    end,
  })
  t.eq(marked, 1, "spans marked as the current entry")
end)

t.case("the index heading is the document title", function()
  local meta = t.index_on({ title = pandoc.Inlines({ pandoc.Str("My deck") }) })
  local doc = t.apply(t.doc(three_sections(), meta))
  t.eq(pandoc.utils.stringify(index_slides(doc)[1].heading.content), "My deck")
end)

t.case("with no title, the index heading is Outline", function()
  local doc = t.apply(t.doc(three_sections(), t.index_on()))
  t.eq(pandoc.utils.stringify(index_slides(doc)[1].heading.content), "Outline")
end)

t.case("an empty title falls back to Outline", function()
  local meta = t.index_on({ title = pandoc.Inlines({}) })
  local doc = t.apply(t.doc(three_sections(), meta))
  t.eq(pandoc.utils.stringify(index_slides(doc)[1].heading.content), "Outline")
end)

t.case("index headings get derived, unique identifiers", function()
  local doc = t.apply(t.doc(three_sections(), t.index_on()))
  local ids = {}
  for _, index in ipairs(index_slides(doc)) do ids[#ids + 1] = index.heading.identifier end
  t.eq(table.concat(ids, " "), "one-index-1 two-index-1 three-index-1")
end)

t.case("an identifier already taken is skipped", function()
  local blocks = {
    H(1, "One", pandoc.Attr("one")), P("a"),
    H(2, "Taken", pandoc.Attr("one-index-1")), P("b"),
  }
  local doc = t.apply(t.doc(blocks, t.index_on()))
  t.eq(index_slides(doc)[1].heading.identifier, "one-index-2")
end)

t.case("a section with no identifier yields one from its text", function()
  local doc = t.apply(t.doc({ H(1, "My Part", pandoc.Attr("")), P("a") }, t.index_on()))
  t.eq(index_slides(doc)[1].heading.identifier, "my-part-index-1")
end)

t.case("index headings are unlisted, so repeats do not fill the table of contents", function()
  local doc = t.apply(t.doc(three_sections(), t.index_on()))
  for _, index in ipairs(index_slides(doc)) do
    t.eq(index.heading.classes:includes("unlisted"), true, "unlisted")
  end
end)

t.case("the index heading is emitted at the slide level", function()
  local doc = t.apply(t.doc({ H(2, "Part", pandoc.Attr("part")), P("a") },
    t.index_on({ ["slide-level"] = 3 })))
  t.eq(index_slides(doc)[1].heading.level, 3, "heading level")
end)

t.case("a section marked unlisted is neither indexed nor listed", function()
  local hidden = H(1, "Secret", pandoc.Attr("secret", { "unlisted" }, {}))
  local blocks = { H(1, "One", pandoc.Attr("one")), P("a"), hidden, P("b") }
  local doc = t.apply(t.doc(blocks, t.index_on()))
  local found = index_slides(doc)
  t.eq(#found, 1, "index slides")
  t.eq(entries(found[1].list), "*One*", "entries")
end)

t.case("a section hidden with visibility is neither indexed nor listed", function()
  local hidden = H(1, "Secret", pandoc.Attr("secret", {}, { { "visibility", "hidden" } }))
  local blocks = { H(1, "One", pandoc.Attr("one")), P("a"), hidden, P("b") }
  local doc = t.apply(t.doc(blocks, t.index_on()))
  local found = index_slides(doc)
  t.eq(#found, 1, "index slides")
  t.eq(entries(found[1].list), "*One*", "entries")
end)

t.case("a deck with no sections is untouched", function()
  local blocks = { H(2, "Intro", pandoc.Attr("intro")), P("a"), HR, P("b") }
  local doc = t.apply(t.doc(blocks, t.index_on()))
  t.shape_eq(doc, "H2(Intro) P(a) HR P(b)")
end)

t.case("a single section still gets its index", function()
  local doc = t.apply(t.doc({ H(1, "Only", pandoc.Attr("only")), P("a") }, t.index_on()))
  t.eq(entries(index_slides(doc)[1].list), "*Only*", "entries")
end)

t.case("a section as the very first block gets an index before it", function()
  local doc = t.apply(t.doc({ H(1, "One", pandoc.Attr("one")), P("a") }, t.index_on()))
  t.eq(index_slides(doc)[1].at, 1, "the index heading is the first block")
end)

t.case("an empty trailing section still gets its index", function()
  local blocks = { H(1, "One", pandoc.Attr("one")), P("a"), H(1, "Two", pandoc.Attr("two")) }
  local doc = t.apply(t.doc(blocks, t.index_on()))
  t.eq(#index_slides(doc), 2, "index slides")
  t.shape_eq(doc,
    "H2(Outline) BulletList H1(One) P(a) H2(Outline) BulletList H1(Two)")
end)

t.case("sections below the slide level are the ones indexed, not slide headings", function()
  local blocks = {
    H(1, "Part", pandoc.Attr("part")), H(2, "A slide", pandoc.Attr("a-slide")), P("a"),
  }
  local doc = t.apply(t.doc(blocks, t.index_on()))
  t.eq(entries(index_slides(doc)[1].list), "*Part*", "only the # heading is a section")
end)

t.case("slide-level 1 leaves show-index inert, no heading being below it", function()
  local doc = t.apply(t.doc({ H(1, "Part", pandoc.Attr("part")), P("a") },
    t.index_on({ ["slide-level"] = 1 })))
  t.shape_eq(doc, "H1(Part) P(a)")
end)

t.case("slide-level 0 leaves show-index inert", function()
  local doc = t.apply(t.doc({ H(1, "Part", pandoc.Attr("part")), P("a") },
    t.index_on({ ["slide-level"] = 0 })))
  t.shape_eq(doc, "H1(Part) P(a)")
end)

t.case("a heading nested in a div is not a section", function()
  local div = pandoc.Div({ H(1, "Inside", pandoc.Attr("inside")), P("a") })
  local doc = t.apply(t.doc({ div }, t.index_on()))
  t.shape_eq(doc, "Div")
end)

t.run()
