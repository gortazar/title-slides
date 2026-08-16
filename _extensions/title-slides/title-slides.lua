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

--- The transform itself: a pure function over a top-level block list.
local function carry_titles(blocks, slide_level)
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
        out:insert(pandoc.Header(current.level, current.content))
      end
    end
  end

  return out
end

return {
  {
    Pandoc = function(doc)
      if not enabled(doc.meta) then return nil end
      doc.blocks = carry_titles(doc.blocks, 2)
      return doc
    end,
  },
}
