-- Finding the trap: `blabla` followed immediately by `---`.
--
-- Markdown reads that as a *setext heading* titled "blabla", not as a paragraph and a
-- horizontal rule. The rule the filter would key on never exists, so the slide comes out
-- titled "blabla" and the author is left wondering why the extension did nothing. It
-- cannot be spotted in the AST — by then it is an ordinary `Header` — so it has to be
-- found in the source text.

local M = {}

local function is_blank(line)
  return line:match("^%s*$") ~= nil
end

-- A setext underline is a run of dashes on its own line, indented no more than three
-- spaces. Two dashes are enough: only *thematic breaks* need three.
local function is_dash_underline(line)
  return line:match("^ ? ? ?%-+%s*$") ~= nil
end

-- Lines that start a block of their own, so a following run of dashes is not underlining
-- a paragraph: headings, block quotes, list items, tables.
local function starts_other_block(line)
  return line:match("^ ? ? ?#")
    or line:match("^ ? ? ?>")
    or line:match("^ ? ? ?[%-%*%+]%s")
    or line:match("^ ? ? ?%d+[%.%)]%s")
    or line:match("^ ? ? ?|")
end

local function fence_of(line)
  return line:match("^ ? ? ?(```+)") or line:match("^ ? ? ?(~~~+)")
end

--- Every setext heading in `text` that was probably meant as a slide break.
-- Returns a list of `{ line = <1-based line number>, title = <the heading text> }`.
function M.find(text)
  local lines = {}
  for line in (text .. "\n"):gmatch("([^\n]*)\n") do
    lines[#lines + 1] = line
  end

  local found = {}
  local fence = nil
  local in_frontmatter = #lines > 0 and lines[1]:match("^%-%-%-%s*$") ~= nil

  for i, line in ipairs(lines) do
    if in_frontmatter then
      -- The closing delimiter is itself a run of dashes, so skip the whole block.
      if i > 1 and (line:match("^%-%-%-%s*$") or line:match("^%.%.%.%s*$")) then
        in_frontmatter = false
      end
    elseif fence then
      if line:match("^ ? ? ?" .. fence) then fence = nil end
    else
      local opening = fence_of(line)
      if opening then
        fence = opening
      elseif is_dash_underline(line) and i > 1 then
        local previous = lines[i - 1]
        if not is_blank(previous) and not starts_other_block(previous)
          and not is_dash_underline(previous) then
          found[#found + 1] = { line = i, title = previous:match("^%s*(.-)%s*$") }
        end
      end
    end
  end

  return found
end

--- The warning shown for one such heading.
function M.message(where, finding)
  return string.format(
    "%s:%d: \"%s\" followed immediately by a line of dashes is a setext heading, "
    .. "not a slide break — this slide will be titled \"%s\". "
    .. "Leave a blank line before the dashes to start an untitled slide.",
    where, finding.line, finding.title, finding.title)
end

return M
