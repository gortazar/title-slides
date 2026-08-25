-- Repeated titles on the index.
--
-- A deck that continues a topic across several slides repeats the `##`, so a verbatim
-- list reads `Definición, Definición, Parámetros por defecto, Parámetros por defecto,
-- Parámetros por defecto` — a faithful list of slides and a poor agenda. The decision for
-- this entry is to **collapse a run of identical adjacent titles into one entry**, kept
-- emphasised for every slide in the run.
--
-- Only *adjacent* ones: a title that comes back later in the deck is a separate entry, in
-- its own place in the running order.

local t = dofile(debug.getinfo(1, "S").source:sub(2):gsub("[^/]*$", "") .. "../harness.lua")

local function H(text) return pandoc.Header(2, { pandoc.Str(text) }) end
local function P(text) return pandoc.Para({ pandoc.Str(text) }) end

--- Build a deck of `##` slides from a list of titles.
local function deck(titles)
  local blocks = {}
  for i, title in ipairs(titles) do
    blocks[#blocks + 1] = H(title)
    blocks[#blocks + 1] = P("body " .. i)
  end
  return blocks
end

local function index_lists(doc)
  local found = {}
  for i, block in ipairs(doc.blocks) do
    if block.t == "Header" and block.classes:includes("title-slides-index") then
      found[#found + 1] = doc.blocks[i + 1]
    end
  end
  return found
end

local function entries(list)
  local out = {}
  for _, item in ipairs(list.content) do
    local text = pandoc.utils.stringify(item)
    local bold = false
    pandoc.Div(item):walk({ Strong = function() bold = true end })
    out[#out + 1] = bold and ("*" .. text .. "*") or text
  end
  return table.concat(out, " | ")
end

t.case("a run of identical adjacent titles becomes one entry", function()
  local doc = t.apply(t.doc(deck({ "Definición", "Definición", "Llamado" }), t.index_on()))
  t.eq((entries(index_lists(doc)[1]):gsub("%*", "")), "Definición | Llamado")
end)

t.case("the collapsed entry is emphasised for every slide in the run", function()
  local doc = t.apply(t.doc(deck({ "Definición", "Definición", "Llamado" }), t.index_on()))
  local lists = index_lists(doc)
  t.eq(entries(lists[1]), "*Definición* | Llamado", "before the first of the run")
  t.eq(entries(lists[2]), "*Definición* | Llamado", "before the second of the run")
  t.eq(entries(lists[3]), "Definición | *Llamado*", "and moves on afterwards")
end)

t.case("every slide still gets its own index slide", function()
  local doc = t.apply(t.doc(deck({ "A", "A", "A" }), t.index_on()))
  t.eq(#index_lists(doc), 3, "one index per slide, not one per entry")
end)

t.case("a run of three collapses to one entry", function()
  local titles = { "Parámetros por defecto", "Parámetros por defecto", "Parámetros por defecto" }
  local doc = t.apply(t.doc(deck(titles), t.index_on()))
  t.eq(entries(index_lists(doc)[2]), "*Parámetros por defecto*")
end)

t.case("titles that differ only in case are not identical", function()
  local doc = t.apply(t.doc(deck({ "Retorno de Valores", "Retorno de valores" }), t.index_on()))
  t.eq(entries(index_lists(doc)[1]), "*Retorno de Valores* | Retorno de valores")
end)

t.case("a repeat that is not adjacent keeps its own entry", function()
  local doc = t.apply(t.doc(deck({ "A", "B", "A" }), t.index_on()))
  local lists = index_lists(doc)
  t.eq(entries(lists[1]), "*A* | B | A", "the first A")
  t.eq(entries(lists[3]), "A | B | *A*", "and the later one is its own entry")
end)

t.case("a hidden slide does not join two runs together", function()
  -- `A, hidden A, A` is one run as far as the index is concerned, because the hidden
  -- slide is not listed at all — but the two visible A's are adjacent *in the list*.
  local blocks = {
    H("A"), P("x"),
    pandoc.Header(2, { pandoc.Str("A") }, pandoc.Attr("", { "unlisted" }, {})), P("y"),
    H("A"), P("z"),
  }
  local doc = t.apply(t.doc(blocks, t.index_on()))
  t.eq(entries(index_lists(doc)[1]), "*A*", "one entry, and the hidden slide has no index")
  t.eq(#index_lists(doc), 2, "two index slides, for the two visible slides")
end)

t.case("collapsing is by the title's text, ignoring how it is marked up", function()
  local plain = pandoc.Header(2, { pandoc.Str("Lambda") })
  local coded = pandoc.Header(2, { pandoc.Code("Lambda") })
  local doc = t.apply(t.doc({ plain, P("a"), coded, P("b") }, t.index_on()))
  t.eq((entries(index_lists(doc)[1]):gsub("%*", "")), "Lambda", "one entry")
end)

t.case("the reporter's deck collapses fourteen slides to nine entries", function()
  local titles = {
    "Definición", "Definición", "Llamado",
    "Retorno de Valores", "Retorno de valores",
    "Argumentos nombrados", "Argumentos nombrados",
    "Parámetros por defecto", "Parámetros por defecto", "Parámetros por defecto",
    "Parámetros opcionales", "Parámetros opcionales",
    "Paso de funciones a funciones", "Funciones lambda",
  }
  local doc = t.apply(t.doc(deck(titles), t.index_on()))
  local lists = index_lists(doc)
  t.eq(#lists, 14, "an index before each of the fourteen slides")
  local listed = select(2, entries(lists[1]):gsub(" | ", ""))
  t.eq(listed + 1, 9, "nine entries")
end)

t.run()
