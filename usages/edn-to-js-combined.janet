(import ../janet-ts-dsl/study-edn-grammar :prefix "")
(import ../janet-ts-dsl/jdn-to-js :prefix "")

(comment

  (def src
    (slurp "data/grammar.edn"))

  (process-edn! src)

  (def parsed
    (parse src))

  (def js-as-str
    (gen-js parsed))

  (def expected-js
    (slurp "data/clojure-grammar.js"))

  # interesting that = does not work for this?
  (deep= js-as-str
         expected-js)
  # =>
  true

  )
