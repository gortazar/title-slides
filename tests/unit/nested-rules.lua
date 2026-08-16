-- Only a rule at the top level of the document starts a slide. A `---` written inside a
-- div, a callout, a column layout, a block quote or speaker notes is a horizontal rule
-- in the ordinary sense — decoration inside a slide — and must survive untouched.

local t = dofile(debug.getinfo(1, "S").source:sub(2):gsub("[^/]*$", "") .. "../harness.lua")

local function H(level, text) return pandoc.Header(level, { pandoc.Str(text) }) end
local function P(text) return pandoc.Para({ pandoc.Str(text) }) end
local HR = pandoc.HorizontalRule()

--- Count the blocks of a given type anywhere in the document, however deeply nested.
local function count(doc, tag)
  local n = 0
  doc:walk({ Block = function(b) if b.t == tag then n = n + 1 end end })
  return n
end

t.case("a rule inside a plain div is left as a rule", function()
  local div = pandoc.Div({ P("a"), HR, P("b") })
  local doc = t.doc({ H(2, "Intro"), div }, t.on())
  local got = t.apply(doc)
  t.shape_eq(got, "H2(Intro) Div", "top level is untouched")
  t.eq(count(got, "Header"), 1, "no heading was inserted inside the div")
  t.eq(count(got, "HorizontalRule"), 1, "the nested rule survives")
end)

t.case("a rule inside a callout is left as a rule", function()
  local callout = pandoc.Div({ P("a"), HR, P("b") },
    pandoc.Attr("", { "callout-note" }, {}))
  local doc = t.doc({ H(2, "Intro"), callout }, t.on())
  t.eq(count(t.apply(doc), "Header"), 1, "no heading was inserted inside the callout")
end)

t.case("a rule inside a column layout is left as a rule", function()
  local column = pandoc.Div({ P("a"), HR }, pandoc.Attr("", { "column" }, {}))
  local columns = pandoc.Div({ column }, pandoc.Attr("", { "columns" }, {}))
  local doc = t.doc({ H(2, "Intro"), columns }, t.on())
  t.eq(count(t.apply(doc), "Header"), 1, "no heading was inserted inside the columns")
end)

t.case("a rule inside speaker notes is left as a rule", function()
  local notes = pandoc.Div({ P("a"), HR, P("b") }, pandoc.Attr("", { "notes" }, {}))
  local doc = t.doc({ H(2, "Intro"), notes }, t.on())
  t.eq(count(t.apply(doc), "Header"), 1, "no heading was inserted inside the notes")
end)

t.case("a rule inside a block quote is left as a rule", function()
  local quote = pandoc.BlockQuote({ P("a"), HR, P("b") })
  local doc = t.doc({ H(2, "Intro"), quote }, t.on())
  t.eq(count(t.apply(doc), "Header"), 1, "no heading was inserted inside the quote")
end)

t.case("a nested heading does not become the carried title", function()
  -- The `## Aside` is inside a div, so it starts no slide and must not be picked up
  -- as the title to carry: the top-level `## Intro` is still the current one.
  local div = pandoc.Div({ H(2, "Aside"), P("a") })
  local doc = t.doc({ H(2, "Intro"), div, HR, P("b") }, t.on())
  t.shape_eq(t.apply(doc), "H2(Intro) Div HR H2(Intro) P(b)")
end)

t.run()
