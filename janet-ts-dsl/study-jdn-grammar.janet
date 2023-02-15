(import ./common :prefix "")

(defn make-capture-info
  []
  (def map-info @[])
  (def edn-capture-peg

  ~{:main (some :input)
    #
    :input (choice :non-form
                   :form)
    #
    :non-form (choice :whitespace
                      :comment)
    #
    :whitespace (choice (some (set " \0\f\t\v"))
                        (choice "\r\n"
                                "\r"
                                "\n"))
    #
    :comment (sequence "#"
                       (any (if-not (set "\r\n") 1)))
    #
    :form (choice :reader-macro
                  :collection
                  :literal)
    #
    :reader-macro (choice :fn
                          :quasiquote
                          :quote
                          :splice
                          :unquote)
    #
    :fn (sequence "|"
                  (any :non-form)
                  :form)
    #
    :quasiquote (sequence "~"
                          (any :non-form)
                          :form)
    #
    :quote (sequence "'"
                     (any :non-form)
                     :form)
    #
    :splice (sequence ";"
                      (any :non-form)
                      :form)
    #
    :unquote (sequence ","
                       (any :non-form)
                       :form)
    #
    :literal (choice :number
                     :constant
                     :buffer
                     :string
                     :long-buffer
                     :long-string
                     :keyword
                     :symbol)
    #
    :collection (choice :array
                        :bracket-array
                        :tuple
                        :bracket-tuple
                        :table
                        :struct)
    #
    :number (drop (cmt
                   (capture (some :name-char))
                   ,scan-number))
    #
    :name-char (choice (range "09" "AZ" "az" "\x80\xFF")
                       (set "!$%&*+-./:<?=>@^_"))
    #
    :constant (sequence (choice "false" "nil" "true")
                        (not :name-char))
    #
    :buffer (sequence "@\""
                      (any (choice :escape
                                   (if-not "\"" 1)))
                      "\"")
    #
    :escape (sequence "\\"
                      (choice (set "0efnrtvz\"\\")
                              (sequence "x" [2 :hex])
                              (sequence "u" [4 :hex])
                              (sequence "U" [6 :hex])
                              (error (constant "bad escape"))))
    #
    :hex (range "09" "af" "AF")
    #
    :string (sequence "\""
                      (any (choice :escape
                                   (if-not "\"" 1)))
                      "\"")
    #
    :long-string :long-bytes
    #
    :long-bytes {:main (drop (sequence :open
                                       (any (if-not :close 1))
                                       :close))
                 :open (capture :delim :n)
                 :delim (some "`")
                 :close (cmt (sequence (not (look -1 "`"))
                                       (backref :n)
                                       (capture :delim))
                             ,=)}
    #
    :long-buffer (sequence "@"
                           :long-bytes)
    #
    :keyword (sequence ":"
                       (any :name-char))
    #
    :symbol (some :name-char)
    #
    :array (sequence "@("
                     (any :input)
                     (choice ")"
                             (error (constant "missing )"))))
    #
    :tuple (sequence "("
                      (any :input)
                      (choice ")"
                              (error (constant "missing )"))))
    #
    :bracket-array (sequence "@["
                             (any :input)
                             (choice "]"
                                     (error (constant "missing ]"))))
    #
    :bracket-tuple (sequence "["
                             (any :input)
                             (choice "]"
                                     (error (constant "missing ]"))))
    #
    :table (sequence "@{"
                      (any :input)
                      (choice "}"
                              (error (constant "missing }"))))
    # just capture the start, end positions of what's between the curlys
    :struct (drop
              (cmt (sequence "{"
                             (position)
                             (any :input)
                             (position)
                             (choice "}"
                                     (error (constant "missing }"))))
                   ,|(array/push map-info $&)))
    })
  #
  [map-info edn-capture-peg])

(comment

  (def src
    @``
     # a comment
     {
      :inline [
              # odd isn't it?
              ]

      :name "fancy"

      # another comment
      :rules {
              # nice comment
              :source [:repeat :elt]

              # another nice comment
              :elt [:choice "0" "1"]

              :zero "0"
             }
     }
     ``)

  (def [map-info ec-peg]
    (make-capture-info))

  (peg/match ec-peg src)
  # =>
  @[]

  (let [len (length map-info)]
    (assert (= 2 len)
            (string/format "should have 2 maps, but found: %d" len)))
  # =>
  true

  map-info
  # =>
  @[[106 256] [13 258]]

  (get map-info
       (find-spanning-map map-info))
  # =>
  [13 258]

  )

(defn process-jdn!
  [src]
  (def [map-info ec-peg]
    (make-capture-info))
  #
  (assert (peg/match ec-peg src)
          # XXX: show prefix of source?
          (string/format "failed to parse src"))
  #
  (def len (length map-info))
  # total number of expected maps in the source
  #
  # 2 (+ 1) = outermost overall map +
  #           :rules map +
  #           :_tokens map (not strictly nececssary)
  (assert (<= 2 len 3)
          (string/format "should have 2 or 3 maps, but found: %d" len))
  # need to know the order of the rules to get grammar.json -> parser.c
  # conversion to work correctly (as well as know the "start symbol")
  #
  # find the overall spanning map (there should be one) so we can
  # skip parsing it below -- although this seems unnecessary, there
  # might not actually be an overall spanning map.  e.g. suppose the
  # source contains two disjoint maps.
  (def overall-map-idx
    (find-spanning-map map-info))
  #
  (assert overall-map-idx
          (string/format "did not find an overall spanning map among: %M"
                         map-info))
  #
  (def cands @[])
  #
  (for i 0 (length map-info)
    # skip the overall map
    (when (not= i overall-map-idx)
      (let [[start end] (get map-info i)
            # this is a trick to treat the body of a struct as a tuple
            # to get the order of the keys
            as-tuple
            (parse (string "["
                           (buffer/slice src start end)
                           "]"))
            map-keys @[]]
        (var found-tokens false)
        (for j 0 (length as-tuple)
          # the keys are at the even indeces
          (when (even? j)
            (def key (get as-tuple j))
            (when (token-name? key)
              (set found-tokens true))
            (array/push map-keys key)))
        # we don't want the struct associated with :_tokens
        (unless found-tokens
          (array/push cands map-keys)))))
  #
  (assert (one? (length cands))
          (string/format "should only be one rules map"))
  #
  (first cands))

(comment

  (def src
    @``
     # a comment
     {
      :inline [
              # odd isn't it?
              ]

      :name "fancy"

      :_tokens {
                :WHITESPACE [:regex "\\s+"]
               }

      # another comment
      :rules {
              # nice comment
              :source [:repeat [:choice :elt :zero]]

              # another nice comment
              :elt [:choice "0" "1"]

              :zero "0"
             }
     }
     ``)

  # find rule names in order
  (process-jdn! src)
  # =>
  @[:source :elt :zero]

  )

