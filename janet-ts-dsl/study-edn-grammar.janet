(import ./common :prefix "")

(defn make-capture-info
  []
  (def comments @[])
  (def map-info @[])
  (def edn-capture-peg
    ~{:main (some :input)
      #
      :input (choice :non-form
                     :form)
      #
      :non-form (choice :whitespace
                        :comment
                        :discard)
      #
      :whitespace (some (set "\f\n\r\t, "))
      # just capture the start of the line comment
      :comment (drop
                 (cmt (sequence (position)
                                (choice ";"
                                        "#!")
                                (any (if-not (set "\r\n")
                                       1)))
                      ,|(array/push comments (first $&))))
      #
      :discard (sequence "#_"
                         (opt (sequence (any (choice :comment
                                                     :whitespace))
                                        :discard))
                         (any (choice :comment
                                      :whitespace))
                         :form)
      #
      :form (choice :reader-macro
                    :collection
                    :literal)
      #
      :reader-macro (choice :dispatch
                            :backtick
                            :quote
                            :unquote-splicing
                            :unquote
                            :deref
                            :metadata)
      #
      :dispatch (choice :set
                        :fn
                        :regex
                        :conditional
                        :conditional-splicing
                        :namespaced-map
                        :var-quote
                        :eval
                        :tag
                        :symbolic)
      #
      :set (sequence "#{"
                     (any :input)
                     (choice "}" (error (constant "missing }"))))
      #
      :fn (sequence "#" :list)
      #
      :regex (sequence "#" :string)
      #
      :namespaced-map (sequence "#"
                                (choice :macro-keyword
                                        :auto-resolve
                                        :keyword)
                                (any :non-form)
                                :map)
      #
      :conditional (sequence "#?"
                             (any :whitespace)
                             :list)
      #
      :conditional-splicing (sequence "#?@"
      (any :whitespace)
      :list)
      #
      :auto-resolve "::"
      #
      :var-quote (sequence "#'"
                           (any :non-form)
                           :form)
      #
      :eval (sequence "#="
                      (any :non-form)
                      (choice :list
                              :symbol))
      #
      :tag (sequence "#"
                     :symbol
                     (any :non-form)
                     (choice :tag
                             :collection
                             :literal))
      #
      :symbolic (sequence "##"
                          (any :non-form)
                          :symbol)
      #
      :backtick (sequence "`"
                          (any :non-form)
                          :form)
      #
      :quote (sequence "'"
                       (any :non-form)
                       :form)
      #
      :unquote (sequence "~"
                         (any :non-form)
                         :form)
      #
      :unquote-splicing (sequence "~@"
                                  (any :non-form)
                                  :form)
      #
      :deref (sequence "@"
                       (any :non-form)
                       :form)
      #
      :metadata
      (sequence (some (sequence (choice :metadata-entry
                                        :deprecated-metadata-entry)
                                (any :non-form)))
                (choice :collection
                        :conditional
                        :namespaced-map
                        :set
                        :tag
                        :fn
                        :unquote-splicing
                        :unquote
                        :deref
                        :quote
                        :backtick
                        :var-quote
                        :symbol))
      #
      :metadata-entry (sequence "^"
                                (any :non-form)
                                (choice :conditional
                                        :map
                                        :string
                                        :macro-keyword
                                        :keyword
                                        :symbol))
      #
      :deprecated-metadata-entry (sequence "#^"
                                           (any :non-form)
                                           (choice :conditional
                                                   :map
                                                   :string
                                                   :macro-keyword
                                                   :keyword
                                                   :symbol))
      #
      :collection (choice :list
                          :vector
                          :map)
      #
      :list (sequence "("
                      (any :input)
                      (choice ")" (error (constant "missing )"))))
      #
      :vector (sequence "["
                        (any :input)
                        (choice "]" (error (constant "missing ]"))))
      # just capture the start, end positions of what's between the curlys
      :map (drop
             (cmt (sequence "{"
                            (position)
                            (any :input)
                            (position)
                            (choice "}"
                                    (error (constant "missing }"))))
                  ,|(array/push map-info $&)))
      #
      :literal (choice :number
                       :macro-keyword
                       :keyword
                       :string
                       :character
                       :symbol)
      #
      :number (sequence (opt (set "+-"))
                        (choice :hex-number
                                :octal-number
                                :radix-number
                                :ratio
                                :double
                                :integer))
      #
      :double (sequence (some :digit)
                        (opt (sequence "."
                                       (any :digit)))
                        (opt (sequence (set "eE")
                                       (opt (set "+-"))
                                       (some :digit)))
                        (opt "M"))
      #
      :digit (range "09")
      #
      :integer (sequence (some :digit)
                         (opt (set "MN")))
      #
      :hex-number (sequence "0"
                            (set "xX")
                            (some :hex)
                            (opt "N"))
      #
      :hex (range "09" "af" "AF")
      #
      :octal-number (sequence "0"
                              (some :octal)
                              (opt "N"))
      #
      :octal (range "07")
      #
      :radix-number (sequence (some :digit)
                              (set "rR")
                              (some (range "09" "az" "AZ")))
      #
      :ratio (sequence (some :digit)
                       "/"
                       (some :digit))
      #
      :macro-keyword (sequence "::"
                               :keyword-head
                               (any :keyword-body))
      #
      :keyword (sequence ":"
                         (choice "/"
                                 (sequence :keyword-head
                                           (any :keyword-body))))
      #
      :keyword-head (if-not (set "\f\n\r\t ()[]{}\"@~^;`\\,:/")
                      1)
      #
      :keyword-body (choice (set ":'/")
                            :keyword-head)
      #
      :string (sequence "\""
                        (any (if-not (set "\"\\")
                               1))
                        (any (sequence "\\"
                                       1
                                       (any (if-not (set "\"\\")
                                              1))))
                        "\"")
      #
      :character (sequence "\\"
                           (choice :named-char
                                   :octal-char
                                   :unicode
                                   :unicode-char))
      #
      :named-char (choice "backspace"
                          "formfeed"
                          "newline"
                          "return"
                          "space"
                          "tab")
      # XXX: \o477 and others are not valid
      :octal-char (sequence "o"
                            (choice [1 :octal]
                                    [2 :octal]
                                    [3 :octal]))
      #
      :unicode (sequence "u" [4 :hex])
      # XXX: this just matches anything...may be not what we want
      :unicode-char 1
      #
      :symbol (sequence :symbol-head
                        (any :symbol-body))
      #
      :symbol-head (if-not (set "\f\n\r\t ()[]{}\"@~^;`\\,:#'0123456789")
                     1)
      #
      :symbol-body (choice :symbol-head
                           (set ":#'0123456789"))
      })
  #
  [comments map-info edn-capture-peg])

(comment

  (def src
    @``
     ;; a comment
     {
      :inline [
              ;; odd isn't it?
              ]

      :name "fancy"

      ;; another comment
      :rules {
              ;; nice comment
              :source [:repeat :elt]

              ;; another nice comment
              :elt [:choice "0" "1"]
             }
     }
     ``)

  (def [comments map-info ec-peg]
    (make-capture-info))

  (peg/match ec-peg src)
  # =>
  @[]

  comments
  # =>
  @[0 35 81 119 177]

  (let [len (length map-info)]
    (assert (= 2 len)
            (string/format "should have 2 maps, but found: %d" len)))
  # =>
  true

  map-info
  # =>
  @[[109 241] [14 243]]

  (get map-info
       (find-spanning-map map-info))
  # =>
  [14 243]

  )

(defn process-edn!
  [src]
  (def [comments map-info ec-peg]
    (make-capture-info))
  #
  (assert (peg/match ec-peg src)
          # XXX: show prefix of source?
          (string/format "failed to parse src"))
  #
  # convert edn line comments to jdn line comments
  (each pos comments
    (put src pos (chr "#")))
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
     ;; a comment
     {
      :inline [
              ;; odd isn't it?
              ]

      :name "fancy"

      :_tokens {
                :WHITESPACE [:regex "\\s+"]
               }

      ;; another comment
      :rules {
              ;; nice comment
              :source [:repeat :elt]

              ;; another nice comment
              :elt [:choice "0" "1"]
             }
     }
     ``)

  # change comments and find rule names in order
  (process-edn! src)
  # =>
  @[:source :elt]

  # ; line-comments are now # line-comments
  src
  # =>
  @``
   #; a comment
   {
    :inline [
            #; odd isn't it?
            ]

    :name "fancy"

    :_tokens {
              :WHITESPACE [:regex "\\s+"]
             }

    #; another comment
    :rules {
            #; nice comment
            :source [:repeat :elt]

            #; another nice comment
            :elt [:choice "0" "1"]
           }
   }
   ``

  )
