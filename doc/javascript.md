## Tree-sitter's JavaScript

According to [these
docs](https://tree-sitter.github.io/tree-sitter/creating-parsers#dependencies):

> Tree-sitter grammars are written in JavaScript, and Tree-sitter uses
> Node.js to interpret JavaScript files. It requires the node command
> to be in one of the directories in your PATH. You’ll need Node.js
> version 6.0 or greater.

I think it turns out in practice that one may need to try various
different Node.js versions to get something that works.  For example,
[in this case](https://github.com/tree-sitter/tree-sitter/issues/409),
at the time, Node.js 12.x was "too recent".

## What's Different?

### Regular Expression Support

Regular expression support differs in at least two sorts of ways:

* Some standard constructs (e.g. assertions such as `^` and `$` are
  not supported).

* Some non-standard constructs (e.g. character class binary
  operations) are supported.

See
[here](https://github.com/sogaiu/ts-questions/blob/943286abf49bdc621ee6466c2ca0dd75d2a76606/questions/what-regex-features-are-supported/README.md)
for more details.

### Property Order

According to the [docs on conflicting
tokens](https://tree-sitter.github.io/tree-sitter/creating-parsers#conflicting-tokens):

> 7. Rule Order - If none of the above criteria can be used to select
>    one token over another, Tree-sitter will prefer the token that
>    appears earlier in the grammar.

IIUC, that means order of properties can matter within the main object
typically representing the rules of the grammar.

That includes the "start symbol" rule.  If it isn't the first rule,
things may not work as expected.  AFAIK, this isn't spelled out
explicitly, though one could argue it is implied.

Technically speaking, older versions of JavaScript didn't guarantee an
order, though in more recent versions things may be different...don't
really want to know [the
details](https://stackoverflow.com/a/30919039) :)

