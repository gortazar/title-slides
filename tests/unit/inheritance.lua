-- The core contract: the last slide-level heading becomes the default title of every
-- following slide started by a `---`, and the filter does nothing at all unless the
-- document asks for it.

local t = dofile(debug.getinfo(1, "S").source:sub(2):gsub("[^/]*$", "") .. "../harness.lua")

local function H(level, text) return pandoc.Header(level, { pandoc.Str(text) }) end
local function P(text) return pandoc.Para({ pandoc.Str(text) }) end
local HR = pandoc.HorizontalRule()

t.case("carries the last ## onto an untitled continuation slide", function()
  local doc = t.doc({ H(2, "Introduction"), P("blabla"), HR, P("more") }, t.on())
  t.shape_eq(t.apply(doc),
    "H2(Introduction) P(blabla) HR H2(Introduction) P(more)")
end)

t.case("carries the same title onto every following untitled slide", function()
  local doc = t.doc({ H(2, "Intro"), P("a"), HR, P("b"), HR, P("c") }, t.on())
  t.shape_eq(t.apply(doc),
    "H2(Intro) P(a) HR H2(Intro) P(b) HR H2(Intro) P(c)")
end)

t.case("is a no-op when title-slides is absent from the metadata", function()
  local doc = t.doc({ H(2, "Introduction"), P("blabla"), HR, P("more") })
  t.shape_eq(t.apply(doc), "H2(Introduction) P(blabla) HR P(more)")
end)

t.case("is a no-op when title-slides is false", function()
  local doc = t.doc({ H(2, "Introduction"), P("blabla"), HR, P("more") },
    { ["title-slides"] = false })
  t.shape_eq(t.apply(doc), "H2(Introduction) P(blabla) HR P(more)")
end)

t.case("does nothing before the first heading", function()
  local doc = t.doc({ P("preamble"), HR, P("more") }, t.on())
  t.shape_eq(t.apply(doc), "P(preamble) HR P(more)")
end)

t.run()
