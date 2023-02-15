(import ../janet-ts-dsl/study-edn-grammar :prefix "")
(import ../janet-ts-dsl/expand :prefix "")
(import ../janet-ts-dsl/jdn-to-json :prefix "")

(comment

  (def src
    (slurp "data/grammar.edn"))

  (def rules-names
    (process-edn! src))
  
  (def expanded-grammar
    (expand-grammar (parse src)))

  (def json-as-str
    (gen-json expanded-grammar rules-names))

  (def expected-json
    (slurp "data/edn-grammar.json"))

  # interesting that = does not work for this?
  (deep= json-as-str
         expected-json)
  # =>
  true

  )
