## Rationale

It's partly about trying to improve perception and in some cases,
consequently reasoning.  It's also about time spent, what the time was
spent on, and the experience itself -- this applies to activities close
to the present but also to later times when returning to the project
after absences on repeated occasions.

Below are some details that motivated the overall endeavor.

### Formatting

The initial idea of trying to start with a different "DSL" came about
after not being satisfied with results of applying located formatters:

* astyle
* clang-format
* codepainter
* esformatter
* js-beautify
* jsfmt

AFAICT, these are designed for formatting source code (of which they
may do a fine job) used for typical JavaScript (and in some cases,
C/C++, etc.)  projects without much thought for a DSL for expressing a
grammar.

Within the tree-sitter grammar DSL, nested function calls are pretty
common and multiple levels is pretty normal.

Unfortunately, I didn't succeed in convincing the formatters I tried
to render an acceptable result.  Here is typical formatter output:

```js
    declaration: $ => seq(
      $._declaration_specifiers,
      commaSep1(field('declarator', choice(
        $._declarator,
        $.init_declarator
      ))),
      ';'
    ),
```

I spend what I consider unnecessary time scanning (and memory) to
figure out what `$._declarator` is an argument of.  Here it is
`choice`.

To learn this, I look up and then over to the right some variable
distance depending on what else is on the line.  This gets old pretty
quick across many rules (which is pretty typical for a grammar for a
programming language).

An example of something that I find much less work to perceive is:

```js
    ns_map_lit: $ =>
      seq(repeat($._metadata_lit),
          field('marker', "#"),
          field('prefix', choice($.auto_res_mark,
                                 $.kwd_lit)),
          repeat($._gap),
          $._bare_map_lit),
```

In this example, if I want to know what `$.kwd_lit` is an argument of,
I look up and to the left of the opening parenthesis (which is a fixed
predicatable distance from the left-most column of each of the
vertically aligned parameters).

In summary, I don't spend as much time on multiple visual puzzles
repeatedly getting distracted from the task of comprehending what the
code means.

### Comments

Getting comments to live in appropriate places also presented some
challenges.

One example of this sort of thing is how to add comments to regular
expressions.

If one uses regular expression literals in JavaScript, it can lead to
long unbroken strings that are difficult to read / understand as well
as comment on individual sections:

```js
const KEYWORD_HEAD =
      /[^\f\n\r\t ()\[\]{}"@~^;`\\,:/\u000B\u001C\u001D\u001E\u001F\u2028\u2029\u1680\u2000\u2001\u2002\u2003\u2004\u2005\u2006\u2008\u2009\u200a\u205f\u3000]/;
```

Using the `RegExp` construct in combination with string concatenation
can lead to a nicer arrangement, e.g.:

```js
const KEYWORD_HEAD =
      RegExp('[^' +
             '\\f\\n\\r\\t ' +
             '(){}' +
             '\\[\\]' + // double-backslashes for re escapes
             '\\\\' +   // double-backslashes for re escapes
             '"' +
             '~^;`,:/' +
             '@' +
             '\\u000B\\u001C\\u001D\\u001E\\u001F' +
             '\\u2028\\u2029\\u1680' +
             '\\u2000\\u2001\\u2002\\u2003\\u2004\\u2005\\u2006\\u2008\\u2009' +
             '\\u200a\\u205f\\u3000' +
             ']');
```

Much better, right?

If one expresses a grammar for tree-sitter using EDN (or JDN), the
above sorts of things don't take much work, e.g.

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

or:

```clojure
  :KEYWORD_HEAD
  [:regex "[^"
          "\\f\\n\\r\\t "
          "/"
          "()"
          "\\[\\]"
          "{}"
          "\""
          "@~^;`"
          "\\\\"
          ",:"
          "\\u000B\\u001C\\u001D\\u001E\\u001F"
          "\\u2028\\u2029\\u1680"
          "\\u2000\\u2001\\u2002\\u2003\\u2004\\u2005\\u2006\\u2008\\u2009"
          "\\u200a\\u205f\\u3000"
          "]"]
```
