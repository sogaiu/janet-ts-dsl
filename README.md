# EDN / JDN Tree-sitter Grammar DSL

Support for converting a tree-sitter grammar expressed in
[EDN](https://github.com/edn-format/edn) or
[JDN](https://github.com/andrewchambers/janet-jdn) to `grammar.json`
and `grammar.js`.

Here's a bit of how it can look:

```clojure
 :rules
 [:source [:repeat [:choice :_form
                            :_gap]]

  :_gap [:choice :_ws
                 :comment
                 :dis_expr]

  :_ws :WHITESPACE

  :comment :COMMENT

  :dis_expr [:seq [:field "marker" "#_"]
                  [:repeat :_gap]
                  [:field "value" :_form]]
```

See the `data` directory for some examples.

## Background

The default DSL for expressing a grammar for tree-sitter is something
that is quite close to but [not quite a standard
JavaScript](./doc/javascript.md).

The TLDR is that I found working with JavaScript and existing
formatters for this particular endeavor to be unsatisfactory enough to
consider investigating alternatives.

Specifically, being able to work with EDN or JDN seems to reduce
enough some problems I experienced with `grammar.js`.

See [here](./doc/rationale.md) for detailed background.

## Status

It's possible to create `grammar.json` as well as `grammar.js`
starting from `grammar.edn` / `grammar.jdn`.

### `grammar.json`

The tooling here can do the left arrow portion of:

```
grammar.edn -> grammar.json -> parser.c
```

The right arrow portion can be accomplished by invoking `tree-sitter
generate grammar.json`.

The resulting `parser.c` is the same as if one used a typical
`tree-sitter generate` invocation that does:

```
grammar.js -> (grammar.json ->) parser.c
```

Note that using the former sequence starting with `grammar.edn` (or
`grammar.jdn`) does not use `node`, whereas the latter sequence that
starts with `grammar.js` does.

### `grammar.js`

It's possible to generate `grammar.js` from `grammar.edn` or
`grammar.jdn`.

This means that in theory one can test how well the generation works via
two paths:

1. `grammar.jdn` / `grammar.edn` -> `grammar.json`
2. `grammar.edn` / `grammar.jdn` -> `grammar.js`

After creating `grammar.json` via path 1 using the tooling here,
`grammar.js` can be generated via path 2 and then by using
`tree-sitter generate`, another `grammar.json` can be created and
compared with the one generated by path 1.

Another use of `grammar.js` generation might be if there is a desire
to stop using the tooling at some point.  To do this, it would be
nicer if comments were maintained and formatting was nicer in the
generated `grammar.js` :)

## Observations

Some miscellaneous observations:

* `grammar.edn` does not have to be written by hand.  One can write
  code (e.g. in Clojure) to generate `grammar.edn`.  Similarly for
  `grammar.jdn`.

* It's not necessary to express a grammar for Clojure using
  `grammar.edn`.  It should be possible to write grammars for other
  programming languages as well.  Similarly for Janet and
  `grammar.jdn`.
