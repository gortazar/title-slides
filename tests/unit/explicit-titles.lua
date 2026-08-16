-- A slide that already says what it is called must be left exactly as written, and a
-- section slide must not leak its title into the slides that follow it.

local t = dofile(debug.getinfo(1, "S").source:sub(2):gsub("[^/]*$", "") .. "../harness.lua")

local function H(level, text) return pandoc.Header(level, { pandoc.Str(text) }) end
local function P(text) return pandoc.Para({ pandoc.Str(text) }) end
local HR = pandoc.HorizontalRule()

t.case("a rule followed by its own ## is left alone", function()
  local doc = t.doc({ H(2, "Intro"), P("a"), HR, H(2, "Other"), P("b") }, t.on())
  t.shape_eq(t.apply(doc), "H2(Intro) P(a) HR H2(Other) P(b)")
end)

t.case("a rule followed by a # section slide is left alone", function()
  local doc = t.doc({ H(2, "Intro"), P("a"), HR, H(1, "Part two"), P("b") }, t.on())
  t.shape_eq(t.apply(doc), "H2(Intro) P(a) HR H1(Part two) P(b)")
end)

t.case("an explicit ## becomes the title carried onward", function()
  local doc = t.doc({ H(2, "Intro"), P("a"), HR, H(2, "Other"), P("b"), HR, P("c") }, t.on())
  t.shape_eq(t.apply(doc), "H2(Intro) P(a) HR H2(Other) P(b) HR H2(Other) P(c)")
end)

t.case("a # section slide clears the carried title", function()
  local doc = t.doc({ H(2, "Intro"), P("a"), H(1, "Part two"), HR, P("b") }, t.on())
  t.shape_eq(t.apply(doc), "H2(Intro) P(a) H1(Part two) HR P(b)")
end)

t.case("a heading below the slide level neither sets nor clears the title", function()
  local doc = t.doc({ H(2, "Intro"), H(3, "Detail"), P("a"), HR, P("b") }, t.on())
  t.shape_eq(t.apply(doc), "H2(Intro) H3(Detail) P(a) HR H2(Intro) P(b)")
end)

t.case("a rule followed by a ### still gets a title, since ### starts no slide", function()
  local doc = t.doc({ H(2, "Intro"), P("a"), HR, H(3, "Detail"), P("b") }, t.on())
  t.shape_eq(t.apply(doc), "H2(Intro) P(a) HR H2(Intro) H3(Detail) P(b)")
end)

t.case("a trailing rule gets no title, having no slide to title", function()
  local doc = t.doc({ H(2, "Intro"), P("a"), HR }, t.on())
  t.shape_eq(t.apply(doc), "H2(Intro) P(a) HR")
end)

t.run()
