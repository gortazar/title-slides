# A real deck, kept as a test

`T4-funciones.qmd` is a lecture deck from a Python course that failed to render with this
extension installed. It is here **byte for byte as it failed**, because editing the
frontmatter to make it convenient for testing would throw away the only thing that makes
it valuable: it is the file that broke.

## Provenance and licence

- **Author:** Francisco Gortázar
- **Licence:** CC-BY-4.0, as declared in the document's own frontmatter
  (`license: CC-BY-4.0`)

Redistributed here with attribution, which is what that licence asks for.

## What it is a test of

The reported failure was not a bug in the filter — it was Quarto never finding the
extension, so the filter never ran. See the troubleshooting section of the top-level
`README.md`. This deck is kept as the regression net for that: it renders through an
extension resolved **by name** from an installed `_extensions/`, exactly as a user's
document does.

What it pins about the extension's behaviour is that it *changes nothing*:

- 14 `##` headings, no top-level `---` and no `#`, so both features are structurally
  inert on it — nothing to carry a title across, no sections to index. It asks for both
  keys in good faith and must get a clean render and an unchanged deck.
- Repeated and case-colliding headings — `Definición` twice, `Parámetros por defecto`
  three times (one with a trailing space), `Retorno de Valores` against
  `Retorno de valores` — so the deck already contains duplicate anchors before the
  extension touches it.
- Accented titles, which must survive to the HTML.

## codigus.png

The deck's `logo:` names an image we do not have the rights to redistribute, so
`codigus.png` here is a 115-byte placeholder of the right name. It exists so the
frontmatter can stay untouched and the logo still resolves; deleting the `logo:` line
would have meant editing the evidence.
