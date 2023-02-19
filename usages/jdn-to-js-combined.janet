(import ../janet-ts-dsl/jdn-to-js :prefix "")

(comment

  (def src
    (slurp "data/grammar.jdn"))

  (def parsed
    (parse src))

  (def js-as-str
    (gen-js parsed))

  (def expected-js
    (slurp "data/janet-simple-grammar.js"))

  # interesting that = does not work for this?
  (deep= js-as-str
         expected-js)
  # =>
  true

  )
