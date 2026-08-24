# title-slides

Two habits from beamer, brought to a Quarto deck:

- **carry the last `##` title** onto untitled continuation slides, and
- **put an index slide before every section**, with the section coming next in bold.

The two are independent — switch on either, or both.

```sh
quarto add gortazar/title-slides@v0.2
```

## Carried titles

In a Quarto deck, a slide is started either by a heading or by a horizontal rule `---`.
A rule gives you a slide with no title, so a long section forces a choice: repeat
`## Introduction` by hand on every continuation slide, or let those slides render
untitled.

`title-slides` removes the choice. Write this:

````markdown
---
title: "My deck"
format: revealjs
filters:
  - title-slides
title-slides: true
---

## Introduction

blabla

---

more blabla

---

still more
````

and get the deck you would have got by typing the title out three times:

````markdown
## Introduction

blabla

---

## Introduction

more blabla

---

## Introduction

still more
````

The second slide of `example/deck.qmd`, which is started by a `---` and has no heading
of its own. With `title-slides: true` it carries the title of the slide before it:

![A continuation slide titled "Introduction"](screenshots/with-title-slides.png)

The same slide of the same deck with the extension switched off:

![The same slide, with no title at all](screenshots/without-title-slides.png)

## An index before every section

`show-index: true` puts an index slide in front of each of the deck's sections — the
`#` headings Quarto renders as section slides. Every index lists every section, and
emboldens the one it introduces, so the audience always knows where the deck is and
where it is going. This is beamer's `\AtBeginSection` habit.

````markdown
---
title: "My deck"
format: revealjs
filters:
  - title-slides
show-index: true
---

# Beginnings

## First slide

...

# Middles

## Second slide

...
````

Before `# Beginnings` and again before `# Middles`, you get:

![An index slide with the first section in bold](screenshots/index-first-section.png)

![The same index, with the next section in bold instead](screenshots/index-second-section.png)

## Usage

Loading the extension never changes how a document renders. `filters: [title-slides]`
loads it; each feature then has its own key, and you can set either or both:

| key | what it does |
| --- | --- |
| `title-slides: true` | carries the last `##` onto untitled continuation slides |
| `show-index: true` | puts an index slide before every section |

## The carry rule, exactly

Let *S* be the slide level (`slide-level` if you set it, otherwise 2). Walking the
top-level blocks in order, the filter tracks `current`, the most recent heading of
level *S*:

- a heading of level *S* sets `current`;
- a heading of a level **above** *S* — a section slide, `#` by default — clears it, so a
  section's title never leaks into what follows;
- for each top-level `---`: if the next block is a heading of level *S* or above, the
  slide already has its own title and is left alone. Otherwise, if `current` is set and
  some content follows, a copy of `current` is inserted right after the rule.

The inserted heading keeps the original's text and level. It gets a fresh identifier
derived from the original (`introduction`, then `introduction-cont-1`, …) so in-deck
links and the reveal menu keep working, and carries the class
`title-slides-continuation` so you can style or hide it:

```css
.title-slides-continuation h2 { opacity: 0.6; }
```

Cross-references to the original heading still point at the original slide.

`slide-level` is honoured: set `slide-level: 1` and it is `#` headings that are carried,
`slide-level: 3` and it is `###`. With `slide-level: 0` no heading starts a slide at all,
so there is no slide title to carry and the filter does nothing.

Attributes written on the original heading — `## Intro {.smaller background-color="red"}`
— are **not** copied onto continuations; only the text and the level are.

## The index rule, exactly

A **section** is a top-level heading *below* the slide level — `#` by default, which is
what Quarto renders as a section slide. Before each one, the filter inserts a heading at
the slide level followed by a bullet list of every section in the deck.

- **The heading** is the document's own `title:`, or `Outline` if it has none.
- **Every section is listed**, in document order — not just the ones still to come — so
  the same list appears each time with the emphasis in a different place.
- **The entry for the section that follows** is wrapped in `Strong` *and* in a span with
  the class `title-slides-index-current`, so it is emphasised in any renderer and can be
  restyled from CSS.
- **Entries are plain text**, not links.
- **Hidden sections are left out.** A `#` heading marked `.unlisted` or
  `visibility="hidden"` is neither listed nor given an index slide of its own, so
  `show-index` cannot leak the title of a slide you suppressed.
- **Identifiers** follow the same scheme as continuations: `<section>-index-<n>`, skipping
  any name already used. Index headings are also `unlisted`, so repeating them never
  fills up a table of contents.

Style them with the two classes:

```css
.title-slides-index h2 { font-size: 1.5em; }
.title-slides-index-current { color: #b5121b; }
```

`slide-level` applies here too. The index heading is emitted at the slide level, and at
`slide-level: 1` or `slide-level: 0` **no heading is below the slide level**, so the deck
has no sections and `show-index` does nothing.

## Caveats

**Leave a blank line before `---`.** In markdown, a line of text followed immediately by
`---` is a *setext heading*, not a horizontal rule:

```markdown
blabla
---
```

parses as a level-2 heading titled "blabla" — the rule never reaches the filter, and you
get a slide titled `blabla` instead of a continuation slide. The filter warns when it
finds one in a `title-slides: true` document. (It only affects the carry; `show-index`
does not look at rules at all.)

**Rules nested inside content are content.** A `---` inside a `:::` div, a `.columns`
block, a callout, speaker notes or a block quote is an ordinary horizontal rule and is
left alone; only top-level rules start slides. Likewise, only a top-level `#` counts as
a section: one nested inside a div is not indexed.

**An index slide joins the preceding section's vertical stack.** Reveal groups the
slide-level slides that follow a `#` into a vertical stack, and an index slide is a
slide-level slide sitting just before the next `#`, so that is where it lands in the
DOM — the first index, which precedes any `#`, is the exception. With Quarto's default
`navigationMode: linear` this makes no difference to reading the deck: the index appears
immediately before its section, in order. It does show up in the overview grid, where
the index sits under the previous section's column rather than starting its own.

**Supported format: `revealjs`.** That is where `---` breaks and `##` titles behave as
described.

**Quarto version.** The extension declares `quarto-required: >=1.4.0`, and falls back to
reading plain metadata where `quarto.metadata.get` is not available. It is tested against
Quarto 1.8.27, which is what the flake pins and what CI runs.

## Development

```sh
nix develop            # the pinned quarto, its pandoc, and the test runners
tests/run-unit.sh      # unit tests over the AST, under `pandoc lua`
tests/run-golden.sh    # filtered deck vs. the same deck written out by hand
tests/run-smoke.sh     # render example/deck.qmd and check the slides that come out
nix flake check        # everything CI runs
```

`example/deck.qmd` is a working deck using both features; every screenshot above comes
from it.
