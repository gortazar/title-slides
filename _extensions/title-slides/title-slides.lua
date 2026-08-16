-- title-slides — carry the last slide-level heading onto untitled continuation slides.
--
-- Slides are split by the writer, long after filters run, but the `---` that starts an
-- untitled slide is still plain `HorizontalRule` in the AST. So we walk the top-level
-- block list, remember the most recent slide-level heading, and insert a copy of it
-- after every rule that does not already introduce a title of its own.

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
      doc.blocks = carry_titles(doc.blocks, 2, taken_identifiers(doc))
      return doc
    end,
  },
}
