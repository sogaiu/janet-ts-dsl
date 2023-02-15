(import ../janet-ts-dsl/study-jdn-grammar :prefix "")
(import ../janet-ts-dsl/expand :prefix "")
(import ../janet-ts-dsl/jdn-to-json :prefix "")

(comment

  (def src
    (slurp "data/grammar.jdn"))

  (def rules-names
    (process-jdn! src))

  (def expanded-grammar
    (expand-grammar (parse src)))

  (def json-as-str
    (gen-json expanded-grammar rules-names))

  (def expected-json
    (slurp "data/jdn-grammar.json"))

  # interesting that = does not work for this?
  (deep= json-as-str
         expected-json)
  # =>
  true

  )
