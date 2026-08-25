-- title-slides — carry the last slide-level heading onto untitled continuation slides.
--
-- Slides are split by the writer, long after filters run, but the `---` that starts an
-- untitled slide is still plain `HorizontalRule` in the AST. So we walk the top-level
-- block list, remember the most recent slide-level heading, and insert a copy of it
-- after every rule that does not already introduce a title of its own.

-- Resolved from this file's own path rather than PANDOC_SCRIPT_FILE, so that the
-- sibling module is found whether pandoc is running the filter or a test is loading it.
local setext = dofile(debug.getinfo(1, "S").source:sub(2):gsub("[^/\\]*$", "") .. "setext.lua")

--- Report a problem to whoever is building the document.
local function warn(message)
  if quarto and quarto.log and quarto.log.warning then
    quarto.log.warning(message)
  else
    io.stderr:write("[WARNING] title-slides: ", message, "\n")
  end
end

--- Warn about `blabla` immediately followed by `---`, which markdown reads as a heading.
-- The source is the only place this is visible. Prefer the document Quarto started from:
-- what pandoc is reading is an intermediate copy with the frontmatter stripped, so its
-- line numbers would not match the file the author has to edit.
local function warn_about_setext_headings()
  local sources = {}
  if quarto and quarto.doc and quarto.doc.input_file then
    sources[1] = quarto.doc.input_file
  else
    sources = PANDOC_STATE and PANDOC_STATE.input_files or {}
  end

  for _, path in ipairs(sources) do
    local handle = io.open(path, "r")
    if handle then
      local text = handle:read("a")
      handle:close()
      for _, finding in ipairs(setext.find(text)) do
        warn(setext.message(path, finding))
      end
    end
  end
end

--- Is a frontmatter flag switched on for this document?
-- Under Quarto the value is available through `quarto.metadata.get`; under a bare
-- `pandoc --lua-filter` there is no `quarto` global, so fall back to the raw metadata.
local function flag(meta, name)
  local value = meta[name]
  if quarto and quarto.metadata and quarto.metadata.get then
    local from_quarto = quarto.metadata.get(name)
    if from_quarto ~= nil then value = from_quarto end
  end
  if value == nil or value == false then return false end
  if type(value) == "table" then
    return pandoc.utils.stringify(value) ~= "false"
  end
  return value ~= "false"
end

--- Which heading level starts a slide.
-- Quarto resolves the document's `slide-level` and hands it to the writer, so the
-- writer options are the authoritative answer — including the `slide-level: 0` case,
-- where headings stop starting slides altogether and rules are the only break. Under a
-- bare `pandoc --lua-filter` there are no writer options yet, so fall back to the
-- metadata and finally to pandoc's own default of 2.
local function slide_level_of(meta)
  if PANDOC_WRITER_OPTIONS and type(PANDOC_WRITER_OPTIONS.slide_level) == "number" then
    return PANDOC_WRITER_OPTIONS.slide_level
  end
  local from_meta = meta["slide-level"]
  if from_meta ~= nil then
    local level = tonumber(pandoc.utils.stringify(from_meta))
    if level ~= nil then return level end
  end
  return 2
end

local function is_header(block, max_level)
  return block ~= nil and block.t == "Header" and block.level <= max_level
end

--- Every identifier already spoken for in the document.
-- Continuations must not reuse one: duplicate anchors break in-deck links, the reveal
-- menu, and any cross-reference pointing at the original slide.
local function taken_identifiers(doc)
  local taken = {}
  doc:walk({
    Block = function(block)
      if block.attr and block.attr.identifier ~= "" then
        taken[block.attr.identifier] = true
      end
    end,
    Inline = function(inline)
      if inline.attr and inline.attr.identifier ~= "" then
        taken[inline.attr.identifier] = true
      end
    end,
  })
  return taken
end

--- A fresh identifier derived from `header`, of the form `<original>-<kind>-<n>`.
-- Headings normally arrive with an identifier pandoc derived from their text; when one
-- has been blanked out, fall back to slugifying the text the same way. Both kinds of
-- generated heading draw from the same `taken` table, so a deck with continuations and
-- index slides cannot end up with two of anything.
local function derived_identifier(header, kind, taken)
  local base = header.identifier
  if base == "" then
    base = pandoc.utils.stringify(header.content):lower():gsub("%s+", "-"):gsub("[^%w%-_]", "")
  end
  if base == "" then return "" end

  local n = 1
  while taken[base .. "-" .. kind .. "-" .. n] do n = n + 1 end
  local identifier = base .. "-" .. kind .. "-" .. n
  taken[identifier] = true
  return identifier
end

--- A copy of `header` fit to stand at the top of a continuation slide.
-- `title-slides-continuation` is there to be styled or hidden; `unlisted` is pandoc's
-- and Quarto's own marker for "keep this out of the table of contents and listings",
-- which is what stops the repeated title from filling the TOC.
local function continuation_of(header, taken)
  local attr = pandoc.Attr(
    derived_identifier(header, "cont", taken),
    { "title-slides-continuation", "unlisted" },
    {})
  return pandoc.Header(header.level, header.content, attr)
end

--- Was this heading put there by the extension rather than by the author?
-- The carry must only ever adopt the author's own titles. An index heading sits at the
-- slide level, which is exactly what the carry looks for, so without this a continuation
-- after a section could inherit the index's title — silently, and only in decks using
-- both features. Today the carry runs first and never sees one; this keeps that from
-- being the only thing standing between the two features.
local function is_generated(header)
  return header.classes:includes("title-slides-index")
    or header.classes:includes("title-slides-continuation")
end

--- Has the author asked for this heading to be kept out of sight?
-- Both spellings Quarto understands: the `unlisted` class and `visibility="hidden"`. A
-- hidden slide must not be listed in an index, or `show-index` would leak the title of a
-- slide the author suppressed.
local function is_hidden(header)
  if header.classes:includes("unlisted") then return true end
  return header.attributes["visibility"] == "hidden"
end

--- Is this a heading the index should list?
-- The index lists the headings that **start slides** — level *S* exactly, `##` at
-- Quarto's default. Keying it off headings below the slide level, as 0.4 did, indexed the
-- one level guaranteed *not* to start a slide: `#` is where a deck's title page goes, so
-- a deck of `##` slides got no index at all.
--
-- Generated headings are excluded, and this is load-bearing: a continuation inserted by
-- the carry sits at the slide level too, so without it a deck using both features would
-- get an index slide before every continuation and its title repeated down the list.
local function is_indexed(block, slide_level)
  return block.t == "Header"
    and block.level == slide_level
    and not is_generated(block)
    and not is_hidden(block)
end

--- The entries an index lists, in document order.
-- A run of identical adjacent titles collapses into a single entry, which stays
-- emphasised for every slide in the run: a deck that continues a topic over three slides
-- repeats the `##`, and listing it three times makes a faithful list of slides but a poor
-- agenda. Only *adjacent* repeats collapse — a title that comes back later in the deck is
-- a separate entry, in its own place in the running order.
--
-- Each entry records the heading it shows and how many slides it covers, so the caller
-- can find the entry a given slide belongs to.
local function entries_of(blocks, slide_level)
  local entries = pandoc.List()
  local previous_title = nil

  for _, block in ipairs(blocks) do
    if is_indexed(block, slide_level) then
      local title = pandoc.utils.stringify(block.content)
      if title == previous_title then
        entries[#entries].slides = entries[#entries].slides + 1
      else
        entries:insert({ heading = block, slides = 1 })
      end
      previous_title = title
    end
  end

  return entries
end

--- What an index slide is titled: the deck's own title, or `Outline` without one.
local function index_title(meta)
  local title = meta.title
  if title ~= nil and pandoc.utils.stringify(title) ~= "" then
    local ok, inlines = pcall(pandoc.Inlines, title)
    if ok then return inlines end
    return pandoc.Inlines({ pandoc.Str(pandoc.utils.stringify(title)) })
  end
  return pandoc.Inlines({ pandoc.Str("Outline") })
end

--- The blocks of the index slide that goes before the slide belonging to entry `current`.
-- A slide-level heading is what starts a slide, so heading plus list lands as a slide of
-- its own and the author's slide follows unchanged. The entry for the slide coming next
-- is emboldened so it reads in any renderer, and wrapped in a span so it can be restyled
-- from CSS without touching the filter.
local function index_slide(entries, current, heading, slide_level, taken, meta)
  local items = pandoc.List()
  for i, entry in ipairs(entries) do
    local text = entry.heading.content
    if i == current then
      text = { pandoc.Span(pandoc.Strong(text), pandoc.Attr("", { "title-slides-index-current" }, {})) }
    end
    items:insert({ pandoc.Plain(text) })
  end

  local attr = pandoc.Attr(
    derived_identifier(heading, "index", taken),
    { "title-slides-index", "unlisted" },
    {})

  return { pandoc.Header(slide_level, index_title(meta), attr), pandoc.BulletList(items) }
end

--- Why a deck that asked for an index has nothing to list.
-- Returns the reason as a phrase, for a document where `entries_of` came back empty.
-- Being specific matters: "no `##` headings at all" and "every one of them is hidden" send
-- the author to completely different places, and getting neither is what made the original
-- report a bug rather than a question.
local function nothing_to_index_reason(blocks, slide_level)
  if slide_level < 1 then
    return string.format(
      "slide-level is %d, so no heading starts a slide and there is nothing to list",
      slide_level)
  end

  local marker = string.rep("#", slide_level)
  local total, hidden = 0, 0
  for _, block in ipairs(blocks) do
    if block.t == "Header" and block.level == slide_level and not is_generated(block) then
      total = total + 1
      if is_hidden(block) then hidden = hidden + 1 end
    end
  end

  if total == 0 then
    return string.format(
      "the deck has no `%s` headings — an index lists the headings that start slides, and there are none",
      marker)
  end
  return string.format(
    "all %d of the deck's `%s` headings are hidden, by `.unlisted` or `visibility=\"hidden\"`",
    total, marker)
end

--- Say so when `show-index` was asked for and there is nothing to index.
-- No index is invented for such a deck, so the warning is the whole of the response, and
-- without it the key looks broken.
local function warn_no_index(blocks, slide_level)
  local marker = slide_level >= 1 and string.rep("#", slide_level) or "##"
  warn(string.format(
    "show-index is set, but no index slide was added: %s. "
    .. "Give the deck `%s` headings, or remove `show-index`.",
    nothing_to_index_reason(blocks, slide_level), marker))
end

--- Put an index slide before every slide-level heading. A pure function over the blocks.
local function insert_indexes(blocks, slide_level, taken, meta)
  local entries = entries_of(blocks, slide_level)
  if #entries == 0 then
    warn_no_index(blocks, slide_level)
    return blocks
  end

  local out = pandoc.List()
  local entry, remaining = 0, 0
  for _, block in ipairs(blocks) do
    -- Inserted *before* the heading, unlike the carry, which appends after a rule.
    if is_indexed(block, slide_level) then
      if remaining == 0 then
        entry = entry + 1
        remaining = entries[entry].slides
      end
      remaining = remaining - 1
      out:extend(index_slide(entries, entry, block, slide_level, taken, meta))
    end
    out:insert(block)
  end

  return out
end

--- The transform itself: a pure function over a top-level block list.
local function carry_titles(blocks, slide_level, taken)
  local out = pandoc.List()
  local current = nil

  for i, block in ipairs(blocks) do
    out:insert(block)

    if block.t == "Header" and not is_generated(block) then
      if block.level == slide_level then
        current = block
      elseif block.level < slide_level then
        -- A section slide of its own; its title must not leak into what follows.
        current = nil
      end
    elseif block.t == "HorizontalRule" and current ~= nil then
      local following = blocks[i + 1]
      -- A rule that already introduces a title, or that ends the document, is left alone.
      if following ~= nil and not is_header(following, slide_level) then
        out:insert(continuation_of(current, taken))
      end
    end
  end

  return out
end

return {
  {
    Pandoc = function(doc)
      -- Two independent features, each on its own key. Either switches the filter on;
      -- a document setting neither renders exactly as it would without the extension.
      local carry = flag(doc.meta, "title-slides")
      local index = flag(doc.meta, "show-index")
      if not carry and not index then return nil end

      local slide_level = slide_level_of(doc.meta)
      local taken = taken_identifiers(doc)

      if carry then
        warn_about_setext_headings()
        doc.blocks = carry_titles(doc.blocks, slide_level, taken)
      end

      if index then
        doc.blocks = insert_indexes(doc.blocks, slide_level, taken, doc.meta)
      end

      return doc
    end,
  },
}
