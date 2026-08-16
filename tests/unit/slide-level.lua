-- Which heading level starts a slide is the document's choice. Quarto passes it to the
-- writer, so `PANDOC_WRITER_OPTIONS.slide_level` is the authoritative answer; under a
-- bare `pandoc --lua-filter` there is none, and the metadata is the fallback.

local t = dofile(debug.getinfo(1, "S").source:sub(2):gsub("[^/]*$", "") .. "../harness.lua")

local function H(level, text) return pandoc.Header(level, { pandoc.Str(text) }) end
local function P(text) return pandoc.Para({ pandoc.Str(text) }) end
local HR = pandoc.HorizontalRule()

--- Run `fn` with the writer options pandoc would hand a filter mid-render.
local function with_slide_level(level, fn)
  local saved = PANDOC_WRITER_OPTIONS
  PANDOC_WRITER_OPTIONS = { slide_level = level }
  local ok, err = pcall(fn)
  PANDOC_WRITER_OPTIONS = saved
  if not ok then error(err, 0) end
end

t.case("slide level 1 carries a # onto continuation slides", function()
  with_slide_level(1, function()
    local doc = t.doc({ H(1, "Part"), P("a"), HR, P("b") }, t.on())
    t.shape_eq(t.apply(doc), "H1(Part) P(a) HR H1(Part) P(b)")
  end)
end)

t.case("slide level 1 ignores a ##, which starts no slide", function()
  with_slide_level(1, function()
    local doc = t.doc({ H(1, "Part"), H(2, "Sub"), P("a"), HR, P("b") }, t.on())
    t.shape_eq(t.apply(doc), "H1(Part) H2(Sub) P(a) HR H1(Part) P(b)")
  end)
end)

t.case("slide level 1 leaves a rule followed by its own # alone", function()
  with_slide_level(1, function()
    local doc = t.doc({ H(1, "Part"), P("a"), HR, H(1, "Next"), P("b") }, t.on())
    t.shape_eq(t.apply(doc), "H1(Part) P(a) HR H1(Next) P(b)")
  end)
end)

t.case("slide level 3 carries a ### and is reset by a ##", function()
  with_slide_level(3, function()
    local doc = t.doc({ H(3, "Topic"), P("a"), HR, P("b"), H(2, "Section"), HR, P("c") }, t.on())
    t.shape_eq(t.apply(doc), "H3(Topic) P(a) HR H3(Topic) P(b) H2(Section) HR P(c)")
  end)
end)

t.case("slide level 0 carries nothing, since no heading starts a slide", function()
  with_slide_level(0, function()
    local doc = t.doc({ H(2, "Intro"), P("a"), HR, P("b") }, t.on())
    t.shape_eq(t.apply(doc), "H2(Intro) P(a) HR P(b)")
  end)
end)

t.case("the writer's slide level wins over the metadata", function()
  with_slide_level(1, function()
    local doc = t.doc({ H(1, "Part"), P("a"), HR, P("b") }, t.on({ ["slide-level"] = 2 }))
    t.shape_eq(t.apply(doc), "H1(Part) P(a) HR H1(Part) P(b)")
  end)
end)

t.case("the metadata is used when the writer offers no slide level", function()
  local doc = t.doc({ H(1, "Part"), P("a"), HR, P("b") }, t.on({ ["slide-level"] = 1 }))
  t.shape_eq(t.apply(doc), "H1(Part) P(a) HR H1(Part) P(b)")
end)

t.case("the slide level defaults to 2", function()
  local doc = t.doc({ H(2, "Intro"), P("a"), HR, P("b") }, t.on())
  t.shape_eq(t.apply(doc), "H2(Intro) P(a) HR H2(Intro) P(b)")
end)

t.run()
