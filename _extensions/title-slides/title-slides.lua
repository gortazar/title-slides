-- title-slides — carry the last slide-level heading onto untitled continuation slides.
--
-- Slides are split by the writer, long after filters run, but the `---` that starts an
-- untitled slide is still plain `HorizontalRule` in the AST. So we walk the top-level
-- block list, remember the most recent slide-level heading, and insert a copy of it
-- after every rule that does not already introduce a title of its own.

-- Resolved from this file's own path rather than PANDOC_SCRIPT_FILE, so that the
-- sibling module is found whether pandoc is running the filter or a test is loading it.
local setext = dofile(debug.getinfo(1, "S").source:sub(2):gsub("[^/\\]*$", "") .. "setext.lua")

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
        local message = setext.message(path, finding)
        if quarto and quarto.log and quarto.log.warning then
          quarto.log.warning(message)
        else
          io.stderr:write("[WARNING] title-slides: ", message, "\n")
        end
      end
    end
  end
end

--- Is the extension switched on for this document?
-- Under Quarto the flag is available through `quarto.metadata.get`; under a bare
-- `pandoc --lua-filter` there is no `quarto` global, so fall back to the raw metadata.
local function enabled(meta)
  local value = meta["title-slides"]
  if quarto and quarto.metadata and quarto.metadata.get then
    local from_quarto = quarto.metadata.get("title-slides")
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

--- A fresh identifier derived from `header`, of the form `<original>-cont-<n>`.
-- Headings normally arrive with an identifier pandoc derived from their text; when one
-- has been blanked out, fall back to slugifying the text the same way.
local function continuation_identifier(header, taken)
  local base = header.identifier
  if base == "" then
    base = pandoc.utils.stringify(header.content):lower():gsub("%s+", "-"):gsub("[^%w%-_]", "")
  end
  if base == "" then return "" end

  local n = 1
  while taken[base .. "-cont-" .. n] do n = n + 1 end
  local identifier = base .. "-cont-" .. n
  taken[identifier] = true
  return identifier
end

--- A copy of `header` fit to stand at the top of a continuation slide.
-- `title-slides-continuation` is there to be styled or hidden; `unlisted` is pandoc's
-- and Quarto's own marker for "keep this out of the table of contents and listings",
-- which is what stops the repeated title from filling the TOC.
local function continuation_of(header, taken)
  local attr = pandoc.Attr(
    continuation_identifier(header, taken),
    { "title-slides-continuation", "unlisted" },
    {})
  return pandoc.Header(header.level, header.content, attr)
end

--- The transform itself: a pure function over a top-level block list.
local function carry_titles(blocks, slide_level, taken)
  local out = pandoc.List()
  local current = nil

  for i, block in ipairs(blocks) do
    out:insert(block)

    if block.t == "Header" then
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
      if not enabled(doc.meta) then return nil end
      warn_about_setext_headings()
      doc.blocks = carry_titles(doc.blocks, slide_level_of(doc.meta), taken_identifiers(doc))
      return doc
    end,
  },
}
