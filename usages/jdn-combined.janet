(import ../janet-ts-dsl/expand :prefix "")
(import ../janet-ts-dsl/jdn-to-json :prefix "")

(comment

  (def src
    (slurp "data/grammar.jdn"))

  (def expanded-grammar
    (expand-grammar (parse src)))

  (def json-as-str
    (gen-json expanded-grammar))

  (def expected-json
    (slurp "data/jdn-grammar.json"))

  # interesting that = does not work for this?
  (deep= json-as-str
         expected-json)
  # =>
  true

  )
