-- Minimal assertion harness for the unit tests, which run under `pandoc lua`.
--
-- Each test file requires this module, registers cases with `t.case`, and ends with
-- `t.run()`, which exits non-zero if anything failed so the shell runner notices.

local M = { cases = {} }

function M.case(name, fn)
  M.cases[#M.cases + 1] = { name = name, fn = fn }
end

--- Load the filter under test and return the single filter table it contributes.
-- The extension file returns a list of filters, as Quarto expects.
function M.filter()
  local here = debug.getinfo(1, "S").source:sub(2):gsub("[^/]*$", "")
  local filters = dofile(here .. "../_extensions/title-slides/title-slides.lua")
  return filters[1]
end

--- Apply the filter to a document, the way pandoc would.
function M.apply(doc)
  return doc:walk(M.filter())
end

--- Build a document from a block list plus optional metadata.
function M.doc(blocks, meta)
  return pandoc.Pandoc(blocks, pandoc.Meta(meta or {}))
end

--- Metadata that switches the extension on.
function M.on(extra)
  local meta = { ["title-slides"] = true }
  for k, v in pairs(extra or {}) do meta[k] = v end
  return meta
end

function M.eq(actual, expected, what)
  if actual ~= expected then
    error(string.format("%s: expected %s, got %s",
      what or "value", tostring(expected), tostring(actual)), 2)
  end
end

--- Describe a block list compactly, so failures say what the AST actually looked like.
function M.shape(blocks)
  local parts = {}
  for _, b in ipairs(blocks) do
    if b.t == "Header" then
      parts[#parts + 1] = string.format("H%d(%s)", b.level, pandoc.utils.stringify(b.content))
    elseif b.t == "HorizontalRule" then
      parts[#parts + 1] = "HR"
    elseif b.t == "Para" then
      parts[#parts + 1] = string.format("P(%s)", pandoc.utils.stringify(b.content))
    else
      parts[#parts + 1] = b.t
    end
  end
  return table.concat(parts, " ")
end

function M.shape_eq(doc, expected, what)
  local actual = M.shape(doc.blocks)
  if actual ~= expected then
    error(string.format("%s:\n  expected: %s\n  actual:   %s",
      what or "shape", expected, actual), 2)
  end
end

function M.run()
  local failed = 0
  for _, c in ipairs(M.cases) do
    local ok, err = pcall(c.fn)
    if ok then
      io.write("  ok   ", c.name, "\n")
    else
      failed = failed + 1
      io.write("  FAIL ", c.name, "\n       ", tostring(err), "\n")
    end
  end
  if failed > 0 then
    io.write(string.format("%d of %d failed\n", failed, #M.cases))
    os.exit(1)
  end
  io.write(string.format("%d passed\n", #M.cases))
end

return M
