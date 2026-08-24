-- The two features have to stay out of each other's way.
--
-- An index heading is a slide-level heading, which is exactly what the title carry looks
-- for — so if the injection ran before the carry, or the carry ever saw a generated
-- heading, continuation slides after a section would quietly inherit the index's title
-- instead of the author's. The carry runs over the author's blocks and the injection
-- happens around it; these tests are what keeps that true.

local t = dofile(debug.getinfo(1, "S").source:sub(2):gsub("[^/]*$", "") .. "../harness.lua")

local function H(level, text, attr)
  return pandoc.Header(level, { pandoc.Str(text) }, attr)
end
local function P(text) return pandoc.Para({ pandoc.Str(text) }) end
local HR = pandoc.HorizontalRule()

local function both(extra)
  local meta = { ["title-slides"] = true, ["show-index"] = true }
  for k, v in pairs(extra or {}) do meta[k] = v end
  return meta
end

--- The title of every continuation heading, in order.
local function carried_titles(doc)
  local out = {}
  for _, header in ipairs(t.marked(doc, "title-slides-continuation")) do
    out[#out + 1] = pandoc.utils.stringify(header.content)
  end
  return table.concat(out, " | ")
end

t.case("a continuation inside a section carries the section's own ##", function()
  local blocks = {
    H(1, "Part", pandoc.Attr("part")),
    H(2, "Intro", pandoc.Attr("intro")), P("a"), HR, P("b"),
  }
  t.eq(carried_titles(t.apply(t.doc(blocks, both()))), "Intro")
end)

t.case("the index title is never carried onto a continuation", function()
  local blocks = {
    H(2, "Intro", pandoc.Attr("intro")), P("a"),
    H(1, "Part", pandoc.Attr("part")),
    H(2, "Later", pandoc.Attr("later")), P("b"), HR, P("c"),
  }
  local doc = t.apply(t.doc(blocks, both({ title = pandoc.Inlines({ pandoc.Str("My deck") }) })))
  t.eq(carried_titles(doc), "Later", "the author's heading, not the deck title")
end)

t.case("a rule right after a section still gets no title", function()
  -- The section cleared the carried title, and the index injected before that section
  -- must not put one back.
  local blocks = {
    H(2, "Intro", pandoc.Attr("intro")), P("a"),
    H(1, "Part", pandoc.Attr("part")), HR, P("b"),
  }
  t.eq(carried_titles(t.apply(t.doc(blocks, both()))), "", "no continuation at all")
end)

t.case("switching show-index on adds no continuations", function()
  local blocks = {
    H(1, "Part", pandoc.Attr("part")),
    H(2, "Intro", pandoc.Attr("intro")), P("a"), HR, P("b"), HR, P("c"),
  }
  local carry_only = carried_titles(t.apply(t.doc(blocks, t.on())))
  local with_index = carried_titles(t.apply(t.doc(blocks, both())))
  t.eq(with_index, carry_only, "the carry is unaffected by the index")
  t.eq(carry_only, "Intro | Intro", "and is still doing its job")
end)

t.case("index slides are not themselves given continuations", function()
  local blocks = { H(1, "Part", pandoc.Attr("part")), P("a"), HR, P("b") }
  local doc = t.apply(t.doc(blocks, both()))
  t.eq(carried_titles(doc), "", "the index heading was not adopted as a title")
end)

t.case("a deck with both keys comes out slide by slide as promised", function()
  local blocks = {
    H(2, "Intro", pandoc.Attr("intro")), P("a"), HR, P("b"),
    H(1, "Part two", pandoc.Attr("part-two")),
    H(2, "Later", pandoc.Attr("later")), P("c"), HR, P("d"),
  }
  local doc = t.apply(t.doc(blocks, both()))
  t.shape_eq(doc, table.concat({
    "H2(Intro) P(a) HR H2(Intro) P(b)",
    "H2(Outline) BulletList",
    "H1(Part two)",
    "H2(Later) P(c) HR H2(Later) P(d)",
  }, " "))
end)

t.case("a generated heading is never adopted as the title to carry", function()
  -- Fed a document that already contains an index heading — which is what the carry
  -- would see if the two passes were ever reordered. The rule must inherit the author's
  -- `## Intro`, not `Outline`.
  local generated = H(2, "Outline", pandoc.Attr("x", { "title-slides-index", "unlisted" }, {}))
  local blocks = { H(2, "Intro", pandoc.Attr("intro")), P("a"), generated, HR, P("b") }
  t.eq(carried_titles(t.apply(t.doc(blocks, t.on()))), "Intro")
end)

t.case("continuations and index slides get distinct identifiers", function()
  local blocks = {
    H(1, "Part", pandoc.Attr("part")),
    H(2, "Intro", pandoc.Attr("intro")), P("a"), HR, P("b"),
  }
  local doc = t.apply(t.doc(blocks, both()))
  local seen = {}
  for _, block in ipairs(doc.blocks) do
    if block.t == "Header" and block.identifier ~= "" then
      t.eq(seen[block.identifier], nil, "identifier " .. block.identifier .. " is unique")
      seen[block.identifier] = true
    end
  end
end)

t.run()
