(defn deprintf
  [fmt & args]
  # XXX: consider a different env var or may be a dynamic variable?
  (when (os/getenv "VERBOSE")
    (eprintf fmt ;args)))

(defn token-name?
  [kwd]
  (def first-byte-as-str
    (slice kwd 0 1))
  (and (not= "_" first-byte-as-str)
       (= (string/ascii-upper first-byte-as-str)
          first-byte-as-str)))

(comment

  (token-name? :ALPHA_NUM)
  # =>
  true

  (token-name? :_lit)
  # =>
  false

  (token-name? :num_lit)
  # =>
  false

  (token-name? :regex)
  # =>
  false

  )

(defn escape-string
  [a-str]
  (->> a-str
       (string/replace-all "\\" "\\\\")
       (string/replace-all "\"" "\\\"")))

(comment

  (escape-string "hello")
  # =>
  "hello"

  (escape-string "\"")
  # =>
  "\\\""

  )

(defn find-spanning-map
  [map-info]
  (var min-bound (get-in map-info [0 0]))
  (var max-bound (get-in map-info [0 1]))
  (var min-map-idx 0)
  (var max-map-idx 0)
  (for i 1 (length map-info)
    (def [cl cr] (get map-info i))
    (when (<= cl min-bound)
      (set min-bound cl)
      (set min-map-idx i))
    (when (<= max-bound cr)
      (set max-bound cr)
      (set max-map-idx i)))
  (when (= min-map-idx max-map-idx)
    min-map-idx))

(comment

  (def map-info
    @[[263 5154] [5167 12752] [1 12753]])

  (get map-info
       (find-spanning-map map-info))
  # =>
  [1 12753]

  )
