# helpful resources
#
# 1. grammar-schema.json in tree-sitter repos (incomplete though)
# 2. tree-sitter.github.io/tree-sitter/creating-parsers#the-grammar-dsl

(def grammar-keys-in-order
  [:name
   :word
   :rules
   :extras
   :conflicts
   :precedences
   :externals
   :inline
   :supertypes])

(defn gen-name!
  [grammar buf]
  (def name-maybe
    (get grammar :name))
  (assert (peg/match ~(sequence (range "az" "AZ" "__")
                                (any (range "az" "AZ" "09" "__"))
                                # XXX: not in original schema, but may be it
                                #      should be?
                                -1)
                     name-maybe)
          (string/format "name contains unallowed chars: %s"
                         name-maybe))
  #
  (buffer/push-string buf "\"" name-maybe "\""))

(comment

  (let [buf @""]
    (gen-name! {:name "janet_simple"} buf))
  # =>
  @"\"janet_simple\""

  (let [buf @""
        result
        (try
          (gen-name! {:name "2fun"} buf)
          ([err]
            err))]
    (string/has-prefix? "name contains unallowed" result))
  # =>
  true

  (let [buf @""]
    (gen-name! {:name "clojure"} buf))
  # =>
  @"\"clojure\""
  )

(defn gen-word!
  [grammar buf]
  (def word-maybe
    (get grammar :word))
  (def type-of-wm
    (type word-maybe))
  (assert (= :keyword type-of-wm)
          (string/format "word should be a keyword, found a %M"
                         type-of-wm))
  #
  (def word-as-str
    (string word-maybe))
  (assert (peg/match ~(sequence (range "az" "AZ" "__")
                                (any (range "az" "AZ" "09" "__"))
                                -1)
                     word-as-str)
          (string/format "word contains unallowed chars: %s"
                         word-as-str))
  #
  (buffer/push-string buf "\"" word-as-str "\"")
  #
  buf)

(comment

  (let [buf @""]
    (gen-word! {:word :basic_identifier} buf))
  # =>
  @"\"basic_identifier\""

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

(defn push-comma-nl
  [buf]
  (buffer/push-string buf ",\n"))

(defn pop-comma-nl-maybe
  [buf]
  (when (string/has-suffix? ",\n" (slice buf -3))
    (buffer/popn buf 2)))

# see "definitions" in grammar-schema.json
#
# * blank-rule
# * string-rule
# * pattern-rule
# * symbol-rule
# * seq-rule
# * choice-rule
# * alias-rule
# * repeat-rule
# * repeat1-rule
# * token-rule <- token, token.immediate
# * field-rule
# * prec-rule <- prec, prec.left, prec.right, prec.dynamic

# XXX: not done yet
#
# * prec-rule <- prec.left, prec.right, prec.dynamic

(defn gen-defs-rule!
  [item buf]
  (def type-of-item (type item))
  (assert (or (= :tuple type-of-item)
              (= :keyword type-of-item)
              (= :string type-of-item))
          (string/format "should be a tuple, keyword, or string, found %M"
                         type-of-item))
  #
  (when (= :keyword type-of-item)
    (buffer/push-string buf
                        "{\n"
                        "  \"type\": \"SYMBOL\",\n"
                        "  \"name\": \"" (string item) "\""
                        "\n}")
    # early return
    (break buf))
  #
  (when (= :string type-of-item)
    (buffer/push-string buf
                        "{\n"
                        "  \"type\": \"STRING\",\n"
                        "  \"value\": \"" (escape-string item) "\""
                        "\n}")
    # early return
    (break buf))
  # item is a tuple at this point
  (def head (first item))
  #
  (buffer/push-string buf "{\n")
  #
  (case head
    :repeat
    (do
      (buffer/push-string buf
                          "  \"type\": \"REPEAT\",\n"
                          "  \"content\": ")
      # repeat takes one argument
      (gen-defs-rule! (get item 1) buf))
    #
    :repeat1
    (do
      (buffer/push-string buf
                          "  \"type\": \"REPEAT1\",\n"
                          "  \"content\": ")
      # repeat1 takes one argument
      (gen-defs-rule! (get item 1) buf))
    #
    :token
    (do
      (buffer/push-string buf
                          "  \"type\": \"TOKEN\",\n"
                          "  \"content\": ")
      # token takes one argument
      (gen-defs-rule! (get item 1) buf))
    #
    :immediate_token
    (do
      (buffer/push-string buf
                          "  \"type\": \"IMMEDIATE_TOKEN\",\n"
                          "  \"content\": ")
      # immediate.token takes one argument
      (gen-defs-rule! (get item 1) buf))
    #
    :choice
    (do
      (buffer/push-string buf
                          "  \"type\": \"CHOICE\",\n"
                          "  \"members\": ")
      (buffer/push-string buf "[\n")
      (each member (slice item 1)
        (gen-defs-rule! member buf)
        (push-comma-nl buf))
      (pop-comma-nl-maybe buf)
      #
      (buffer/push-string buf "\n]"))
    #
    :optional
    (do
      # optional is implemented in terms of CHOICE and BLANK
      (buffer/push-string buf
                          "  \"type\": \"CHOICE\",\n"
                          "  \"members\": ")
      (buffer/push-string buf "[\n")
      (gen-defs-rule! (get item 1) buf)
      (push-comma-nl buf)
      (buffer/push-string buf
                          "{\n"
                          "  \"type\": \"BLANK\""
                          "\n}")
      #
      (buffer/push-string buf "\n]"))
    #
    :seq
    (do
      (buffer/push-string buf
                          "  \"type\": \"SEQ\",\n"
                          "  \"members\": ")
      (buffer/push-string buf "[\n")
      (each member (slice item 1)
        (gen-defs-rule! member buf)
        (push-comma-nl buf))
      (pop-comma-nl-maybe buf)
      #
      (buffer/push-string buf "\n]"))
    #
    :prec
    (do
      (buffer/push-string buf "  \"type\": \"PREC\",\n")
      # prec takes 2 arguments
      (def prec-val
        # first argument to prec can be an integer or string
        (let [val (get item 1)
              type-of-v (type val)]
          (cond
            (= :number type-of-v)
            (string val)
            #
            (= :string type-of-v)
            (string "\"" val "\"")
            #
            (errorf "unexpected val: %M" val))))
      (buffer/push-string buf
                          "  \"value\": " prec-val ",\n"
                          "  \"content\": ")
      (gen-defs-rule! (get item 2) buf))
    #
    :alias
    (do
      (buffer/push-string buf
                          "  \"type\": \"ALIAS\",\n"
                          "  \"content\": ")
      # alias takes 2 arguments
      (gen-defs-rule! (get item 1) buf)
      (push-comma-nl buf)
      (def alias-name
        (get item 2))
      (def is-named?
        (let [type-of-v (type alias-name)]
          (cond
            (= :keyword type-of-v)
            true
            #
            (= :string type-of-v)
            false
            #
            (errorf "unexpected type for alias-name: %M" alias-name))))
      (buffer/push-string buf
                          "  \"named\": " (string is-named?) ",\n"
                          "  \"value\": " "\"" (string alias-name) "\""))
    #
    :field
    (do
      (buffer/push-string buf
                          "  \"type\": \"FIELD\",\n"
                          "  \"name\": " "\"" (string (get item 1)) "\",\n"
                          "  \"content\": " )
      # field takes 2 arguments
      (gen-defs-rule! (get item 2) buf))
    # XXX: more to fill in
    #
    :regex
    (do
      (buffer/push-string buf
                          "  \"type\": \"PATTERN\",\n"
                          "  \"value\": \""
                          (escape-string (string ;(slice item 1)))
                          "\""))
    #
    (errorf "Unknown item: %M" head))
  #
  (buffer/push-string buf "\n}")
  #
  buf)

(comment

  (let [buf @""]
    (gen-defs-rule! [:regex "[" "0-9" "]"] buf))
  # =>
  @``
   {
     "type": "PATTERN",
     "value": "[0-9]"
   }
   ``

  (let [buf @""]
    (gen-defs-rule! :num_lit buf))
  # =>
  @``
   {
     "type": "SYMBOL",
     "name": "num_lit"
   }
   ``

  (let [buf @""]
    (gen-defs-rule! "nil" buf))
  # =>
  @``
   {
     "type": "STRING",
     "value": "nil"
   }
   ``

  (let [buf @""]
    (gen-defs-rule! [:repeat :_lit] buf))
  # =>
  @``
   {
     "type": "REPEAT",
     "content": {
     "type": "SYMBOL",
     "name": "_lit"
   }
   }
   ``

  (let [buf @""]
    (gen-defs-rule! [:choice "-" "+"] buf))
  # =>
  @``
   {
     "type": "CHOICE",
     "members": [
   {
     "type": "STRING",
     "value": "-"
   },
   {
     "type": "STRING",
     "value": "+"
   }
   ]
   }
   ``

  )

(defn gen-rules!
  [grammar rules-names buf]
  (def rules-maybe
    (get grammar :rules))
  (def type-of-rm
    (type rules-maybe))
  (assert (or (= :struct type-of-rm)
              (= :table type-of-rm))
          (string/format "rules should be a struct, found a %M"
                         type-of-rm))
  #
  (def rules rules-maybe)
  #
  (buffer/push-string buf "{\n")
  (each key rules-names
    (def expr
      (get rules key))
    (buffer/push-string buf "  " "\"" (string key) "\": ")
    (gen-defs-rule! expr buf)
    (push-comma-nl buf))
  (pop-comma-nl-maybe buf)
  #
  (buffer/push-string buf "\n}")
  #
  buf)

(defn gen-extras!
  [grammar buf]
  (def extras-maybe
    (get grammar :extras))
  (def type-of-em
    (type extras-maybe))
  (assert (or (nil? extras-maybe)
              (= :tuple type-of-em))
          (string/format "extras should be a tuple or nil, found a %M"
                         type-of-em))
  # extras needs special handling - dsl.js
  (def extras
    (if (nil? extras-maybe)
      [[:regex "\\s"]]
      extras-maybe))
  #
  (buffer/push-string buf "[\n")
  #
  (each extra extras
    (gen-defs-rule! extra buf)
    (push-comma-nl buf))
  (pop-comma-nl-maybe buf)
  #
  (buffer/push-string buf "\n]")
  #
  buf)

(comment

  (let [buf @""]
    (gen-extras! {:extras [[:regex "\\s|\\x0b|\\x0c|\\x00"]
                           [:regex "#.*"]]}
                 buf))
  # =>
  @``
   [
   {
     "type": "PATTERN",
     "value": "\\s|\\x0b|\\x0c|\\x00"
   },
   {
     "type": "PATTERN",
     "value": "#.*"
   }
   ]
   ``

  )

(defn gen-conflicts!
  [grammar buf]
  (def conflicts-maybe
    (get grammar :conflicts))
  (def type-of-em
    (type conflicts-maybe))
  (assert (or (nil? conflicts-maybe)
              (= :tuple type-of-em))
          (string/format "conflicts should be a tuple or nil, found a %M"
                         type-of-em))
  # see dsl.js
  (def conflicts
    (if (nil? conflicts-maybe)
      []
      conflicts-maybe))
  #
  (buffer/push-string buf "[\n")
  #
  (each conflict conflicts
    # each conflict is expected to be a tuple
    (def type-of-conf
      (type conflict))
    (assert (= :tuple type-of-conf)
            (string/format "conflict should be a tuple, found a %M"
                           type-of-conf))
    #
    (buffer/push-string buf "[\n")
    #
    (each item conflict
      (buffer/push-string buf "  " "\"" item "\"")
      (push-comma-nl buf))
    (pop-comma-nl-maybe buf)
    #
    (buffer/push-string buf "\n]")
    #
    (push-comma-nl buf))
  (pop-comma-nl-maybe buf)
  #
  (buffer/push-string buf "\n]")
  #
  buf)

(comment

  (let [buf @""]
    (gen-conflicts! {:conflicts [[:constant_primary :primary]
                                 [:primary :implicit_class_handle]]}
                    buf))
  # =>
  @``
   [
   [
     "constant_primary",
     "primary"
   ],
   [
     "primary",
     "implicit_class_handle"
   ]
   ]
   ``
  )

(defn gen-externals!
  [grammar buf]
  (def externals-maybe
    (get grammar :externals))
  (def type-of-em
    (type externals-maybe))
  (assert (or (nil? externals-maybe)
              (= :tuple type-of-em))
          (string/format "externals should be a tuple or nil, found a %M"
                         type-of-em))
  # see dsl.js
  (def externals
    (if (nil? externals-maybe)
      []
      externals-maybe))
  #
  (buffer/push-string buf "[\n")
  #
  (each external externals
    (gen-defs-rule! external buf)
    (push-comma-nl buf))
  (pop-comma-nl-maybe buf)
  #
  (buffer/push-string buf "\n]")
  #
  buf)

(comment

  (let [buf @""]
    (gen-externals! {:externals [:long_buf_lit :long_str_lit]}
                    buf))
  # =>
  @``
   [
   {
     "type": "SYMBOL",
     "name": "long_buf_lit"
   },
   {
     "type": "SYMBOL",
     "name": "long_str_lit"
   }
   ]
   ``

  )

(defn gen-precedences!
  [grammar buf]
  (def precedences-maybe
    (get grammar :precedences))
  (def type-of-em
    (type precedences-maybe))
  (assert (or (nil? precedences-maybe)
              (= :tuple type-of-em))
          (string/format "precedences should be a tuple or nil, found a %M"
                         type-of-em))
  # see dsl.js
  (def precedences
    (if (nil? precedences-maybe)
      []
      precedences-maybe))
  #
  (buffer/push-string buf "[\n")
  #
  (each precedence precedences
    # each precedence is expected to be a tuple
    (def type-of-prec
      (type precedence))
    (assert (= :tuple type-of-prec)
            (string/format "precedence should be a tuple, found a %M"
                           type-of-prec))
    #
    (buffer/push-string buf "[\n")
    #
    (each item precedence
      (gen-defs-rule! item buf)
      (push-comma-nl buf))
    (pop-comma-nl-maybe buf)
    #
    (buffer/push-string buf "\n]")
    #
    (push-comma-nl buf))
  (pop-comma-nl-maybe buf)
  #
  (buffer/push-string buf "\n]")
  #
  buf)

(comment

  (let [buf @""]
    (gen-precedences! {:precedences [["document_directive" "body_directive"]
                                     ["special" "immediate" "non-immediate"]]}
                      buf))
  # =>
  @``
   [
   [
   {
     "type": "STRING",
     "value": "document_directive"
   },
   {
     "type": "STRING",
     "value": "body_directive"
   }
   ],
   [
   {
     "type": "STRING",
     "value": "special"
   },
   {
     "type": "STRING",
     "value": "immediate"
   },
   {
     "type": "STRING",
     "value": "non-immediate"
   }
   ]
   ]
   ``
  )

(defn gen-inline!
  [grammar buf]
  (def inline-maybe
    (get grammar :inline))
  (def type-of-em
    (type inline-maybe))
  (assert (or (nil? inline-maybe)
              (= :tuple type-of-em))
          (string/format "inline should be a tuple or nil, found a %M"
                         type-of-em))
  # see dsl.js
  (def inline
    (if (nil? inline-maybe)
      []
      inline-maybe))
  #
  (buffer/push-string buf "[\n")
  #
  (each item inline
    (buffer/push-string buf "\"" (string item) "\"")
    (push-comma-nl buf))
  (pop-comma-nl-maybe buf)
  #
  (buffer/push-string buf "\n]")
  #
  buf)

(comment

  (let [buf @""]
    (gen-inline! {:inline [:_sym_qualified
                           :_sym_unqualified]}
                    buf))
  # =>
  @``
   [
   "_sym_qualified",
   "_sym_unqualified"
   ]
   ``

  )


(defn gen-supertypes!
  [grammar buf]
  (def supertypes-maybe
    (get grammar :supertypes))
  (def type-of-em
    (type supertypes-maybe))
  (assert (or (nil? supertypes-maybe)
              (= :tuple type-of-em))
          (string/format "supertypes should be a tuple or nil, found a %M"
                         type-of-em))
  # see dsl.js
  (def supertypes
    (if (nil? supertypes-maybe)
      []
      supertypes-maybe))
  #
  (buffer/push-string buf "[\n")
  #
  (each supertype supertypes
    (gen-defs-rule! supertype buf)
    (push-comma-nl buf))
  (pop-comma-nl-maybe buf)
  #
  (buffer/push-string buf "\n]")
  #
  buf)

(comment

  (let [buf @""]
    (gen-supertypes! {:supertypes [:_declaration
                                   :_expression
                                   :_statement
                                   :_type]} buf))
  # =>
  @``
   [
   {
     "type": "SYMBOL",
     "name": "_declaration"
   },
   {
     "type": "SYMBOL",
     "name": "_expression"
   },
   {
     "type": "SYMBOL",
     "name": "_statement"
   },
   {
     "type": "SYMBOL",
     "name": "_type"
   }
   ]
   ``

  )

(defn gen-json!
  [grammar rules-names buf]
  (assert (and (get grammar :name)
               (get grammar :rules))
          (string/format "grammar's keys missing name and/or rules: %M"
                         (keys grammar)))
  #
  (buffer/push-string buf "{\n")
  #
  # XXX: consider fancier indentation later
  (each key grammar-keys-in-order
    (when (or (get grammar key)
              # some keys need special handling - dsl.js / grammar.json
              (index-of key [:extras :conflicts :precedences
                             :externals :inline :supertypes]))
      (buffer/push-string buf "  ")
      (case key
        :name
        (do
          (buffer/push-string buf "\"name\": ")
          (gen-name! grammar buf))
        #
        :word
        (do
          (buffer/push-string buf "\"word\": ")
          (gen-word! grammar buf))
        #
        :rules
        (do
          (buffer/push-string buf "\"rules\": ")
          (gen-rules! grammar rules-names buf))
        #
        :extras
        (do
          (buffer/push-string buf "\"extras\": ")
          (gen-extras! grammar buf))
        #
        :conflicts
        (do
          (buffer/push-string buf "\"conflicts\": ")
          (gen-conflicts! grammar buf))
        #
        :precedences
        (do
          (buffer/push-string buf "\"precedences\": ")
          (gen-precedences! grammar buf))
        #
        :externals
        (do
          (buffer/push-string buf "\"externals\": ")
          (gen-externals! grammar buf))
        #
        :inline
        (do
          (buffer/push-string buf "\"inline\": ")
          (gen-inline! grammar buf))
        #
        :supertypes
        (do
          (buffer/push-string buf "\"supertypes\": ")
          (gen-supertypes! grammar buf))
        #
        (errorf "Unknown key: %M" key))
      #
      (push-comma-nl buf)))
  (pop-comma-nl-maybe buf)
  #
  (buffer/push-string buf "\n}\n")
  #
  buf)

(defn gen-json
  ``
  Generate `grammar.json` content from an expanded `grammar`.

  `grammar` is typically expanded from `grammar.jdn` by `expand-grammar`
  in `expand.janet`.
  ``
  [grammar rules-names]
  (let [buf @""]
    (gen-json! grammar rules-names buf)
    buf))

(comment

  # note: extras has implicit value if unspecified
  (gen-json {:name "hello"
             :rules {:source "1"}}
            [:source])
  # =>
  @``
   {
     "name": "hello",
     "rules": {
     "source": {
     "type": "STRING",
     "value": "1"
   }
   },
     "extras": [
   {
     "type": "PATTERN",
     "value": "\\s"
   }
   ],
     "conflicts": [

   ],
     "precedences": [

   ],
     "externals": [

   ],
     "inline": [

   ],
     "supertypes": [

   ]
   }

   ``

  )
