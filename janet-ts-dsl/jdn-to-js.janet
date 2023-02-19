# overall structure of target js code is:
#
# * top-level definitions
#   * one wrapper function (regex) definition
#     * hard-wired
#   * sequence of const declarations
#     * iterate over :_tokens content
#       * needs to be done in order
# * assign grammar() result to module.exports
#   * pass an object to grammar()
#     * object has keys
#       * name
#       * extras
#       * conflicts
#       * inline
#       * rules
#       * etc.
#     * top-level keys don't need to be done in order but
#       it's probably easier to read the result
#     * key, value pairs within rules should be done in
#       order

(import ./common :prefix "")
(import ./emit-js :prefix "")

########################################################################

# this order is aesthetic
(def grammar-keys-in-order
  [:name
   :extras
   :externals
   :supertypes
   :inline
   :conflicts
   :word
   :precedences
   :rules])

########################################################################

(comment

  (def tokens
    [:SIGN [:choice "-" "+"]
     :DIGIT [:regex "[0-9]"]
     :HEX_DIGIT [:regex "[0-9A-Fa-f]"]])

  (def key (get tokens 0))

  (def expr (get tokens (inc 0)))

  (defn wrap-str
    [a-str]
    (string "\"" a-str "\""))

  (def buf @"")

  (buffer/push-string
    buf
    "const " (string key) " =\n"
    # yeah...indentation
    "  "
    (string (first expr))
    "("
    # whether to wrap in double quotes depends on
    # what is being wrapped
    (string ;(interpose ", " (map wrap-str (slice expr 1))))
    ")"
    ";")

  buf
  # =>
  @``
   const SIGN =
     choice("-", "+");
   ``

  )

(defn emit-expr!
  [item buf]
  (def type-of-item
    (type item))
  (assert (or (= :tuple type-of-item)
              (= :keyword type-of-item)
              (= :string type-of-item)
              (= :number type-of-item))
          (string/format (string "expected tuple, keyword, string, or number, "
                                 "but found %M (%M)")
                         type-of-item item))
  #
  (case type-of-item
    :keyword
    (do
      (cond
        (reserved? item)
        (emit-id! item buf)
        #
        (token-name? item)
        (emit-raw-sym! item buf)
        #
        (emit-sym! item buf))
      (break buf))
    #
    :string
    (do
      (emit-str! item buf)
      (break buf))
    #
    :number
    (do
      (emit-num! item buf)
      (break buf)))
  # item is a tuple at this point
  (def head (first item))
  (cond
    (= :regex head)
    (do
      # XXX: could do string concat with "+\n" instead
      (def re-pattern
        (string ;(slice item 1)))
      (emit-start-func-call! "regex" buf)
      (emit-expr! re-pattern buf)
      (emit-end-func-call! buf))
    #
    (keyword? head)
    (do
      (emit-start-func-call! head buf)
      (each item (slice item 1)
        (emit-expr! item buf)
        (emit-comma-space! buf))
      (pop-comma-space-maybe! buf)
      (emit-end-func-call! buf))
    #
    (errorf "unknown item: %M" head))
  #
  buf)

(defn emit-const-decl!
  [name-kwd expr-tup buf]
  (emit-start-const-decl! name-kwd buf)
  (emit-expr! expr-tup buf)
  (emit-end-const-decl! buf))

(comment

  (def tokens
    [:SIGN [:choice "-" "+"]
     :DIGIT [:regex "[0-9]"]
     :HEX_DIGIT [:regex "["
                        "0-9"
                        "A-F"
                        "a-f]"]
     :STRING_DOUBLE_QUOTE_CONTENT
     [:repeat [:choice [:regex "[^" "\\\\" "\"" "]"]
                       [:regex "\\\\(.|\\n)"]]]])

  (def buf @"")

  (each i (range 0 (length tokens) 2)
    (def key (get tokens i))
    (deprintf "key: %M" key)
    (def expr (get tokens (inc i)))
    (deprintf "expr: %M" expr)
    (emit-const-decl! key expr buf)
    (emit-nl! buf))

  buf
  # =>
  @``
   const SIGN = choice("-", "+");
   const DIGIT = regex("[0-9]");
   const HEX_DIGIT = regex("[0-9A-Fa-f]");
   const STRING_DOUBLE_QUOTE_CONTENT = repeat(choice(regex("[^\\\\\"]"), regex("\\\\(.|\\n)")));

   ``

  )

(comment

  (def rules
    [:source [:repeat :_lit]
     :comment [:regex "#.*"]
     :_gap [:choice :_ws
                    :comment
                    :dis_expr]
     :_ws :WHITESPACE
     :comment :COMMENT
     :dis_expr [:seq [:field "marker" "#_"]
                     [:repeat :_gap]
                     [:field "value" :_form]]])

  (def buf @"")

  (do
    (emit-start-obj! buf)
    #
    (each i (range 0 (length rules) 2)
      (def key (get rules i))
      (deprintf "key: %M" key)
      (emit-bare-key! key buf)
      (def expr (get rules (inc i)))
      (deprintf "expr: %M" expr)
      (emit-start-arrow-func! buf)
      (emit-nl! buf)
      (emit-expr! expr buf)
      (emit-comma-nl! buf))
    # XXX: trailing comma ok in js
    (pop-comma-nl-maybe! buf)
    #
    (emit-end-obj! buf))

  buf
  @``
   {
   source: $ =>
   repeat($._lit),
   comment: $ =>
   regex("#.*"),
   _gap: $ =>
   choice($._ws, $.comment, $.dis_expr),
   _ws: $ =>
   $.WHITESPACE,
   comment: $ =>
   $.COMMENT,
   dis_expr: $ =>
   seq(field("marker", "#_"), repeat($._gap), field("value", $._form))
   }
   ``

  )

(comment

  (def rules
    [:source [:repeat :_lit]
     :comment [:regex "#.*"]
     :_gap [:choice :_ws
                    :comment
                    :dis_expr]
     :_ws :WHITESPACE
     :comment :COMMENT
     :dis_expr [:seq [:field "marker" "#_"]
                     [:repeat :_gap]
                     [:field "value" :_form]]])

  (def buf @"")

  (do
    (emit-left-assign! "module.exports" buf)
    (emit-start-func-call! "grammar" buf)
    (emit-start-obj! buf)
    #
    (each i (range 0 (length rules) 2)
      (def key (get rules i))
      (deprintf "key: %M" key)
      (emit-bare-key! key buf)
      (def expr (get rules (inc i)))
      (deprintf "expr: %M" expr)
      (emit-start-arrow-func! buf)
      (emit-nl! buf)
      (emit-expr! expr buf)
      (emit-comma-nl! buf))
    # XXX: trailing comma ok in js
    (pop-comma-nl-maybe! buf)
    #
    (emit-end-obj! buf)
    (emit-end-func-call! buf)
    (emit-end-statement! buf))

  buf
  # =>
  @``
   module.exports = grammar({
   source: $ =>
   repeat($._lit),
   comment: $ =>
   regex("#.*"),
   _gap: $ =>
   choice($._ws, $.comment, $.dis_expr),
   _ws: $ =>
   WHITESPACE,
   comment: $ =>
   COMMENT,
   dis_expr: $ =>
   seq(field("marker", "#_"), repeat($._gap), field("value", $._form))
   });
   ``

  )

(defn emit-regex-func-decl!
  [buf]
  (buffer/push-string buf
                      ``
                      function regex(patt) {
                        return RegExp(patt);
                      }
                      ``))

(defn emit-const-decls!
  [grammar buf]
  (def tokens
    (get-val grammar :_tokens))
  (assert (indexed? tokens)
          (string/format "indexed ds expected, found: %M"
                         (type tokens)))
  #
  (each i (range 0 (length tokens) 2)
    (def key (get tokens i))
    (deprintf "key: %M" key)
    (def expr (get tokens (inc i)))
    (deprintf "expr: %M" expr)
    (emit-const-decl! key expr buf)
    (emit-nl! buf))
  #
  buf)

(defn emit-name!
  [grammar buf]
  (def name-maybe
    (get-val grammar :name))
  (assert (peg/match ~(sequence (range "az" "AZ" "__")
                                (any (range "az" "AZ" "09" "__"))
                                # XXX: not in original schema, but may be it
                                #      should be?
                                -1)
                     name-maybe)
          # XXX: message not quite right for leading digit
          (string/format "name contains unallowed chars: %s"
                         name-maybe))
  #
  (emit-str! name-maybe buf))

(comment

  (let [buf @""]
    (emit-name! [:name "janet_simple"] buf))
  # =>
  @"\"janet_simple\""

  (let [buf @""
        result
        (try
          (emit-name! [:name "2fun"] buf)
          ([err]
            err))]
    (string/has-prefix? "name contains unallowed" result))
  # =>
  true

  (let [buf @""]
    (emit-name! [:name "clojure"] buf))
  # =>
  @"\"clojure\""
  )

(defn emit-word!
  [grammar buf]
  (def word-maybe
    (get-val grammar :word))
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
  (emit-str! word-as-str buf)
  #
  buf)

(comment

  (let [buf @""]
    (emit-word! [:word :basic_identifier] buf))
  # =>
  @"\"basic_identifier\""

  )

(defn emit-rules!
  [grammar buf]
  (def rules-maybe
    (get-val grammar :rules))
  (assert (indexed? rules-maybe)
          (string/format "rules should be indexed, found a %M"
                         (type rules-maybe)))
  #
  (def rules rules-maybe)
  #
  (emit-start-obj! buf)
  #
  (each i (range 0 (length rules) 2)
    (def key (get rules i))
    (def expr (get rules (inc i)))
    (emit-bare-key! key buf)
    (emit-start-arrow-func! buf)
    (emit-nl! buf)
    (emit-expr! expr buf)
    (emit-comma-nl! buf))
  (pop-comma-nl-maybe! buf)
  #
  (emit-end-obj! buf)
  #
  buf)

(comment

  (let [buf @""]
    (emit-rules! [:rules [:source [:repeat :_lit]
                          :comment [:regex "#.*"]
                          :_gap [:choice :_ws
                                         :comment
                                         :dis_expr]
                          :_ws :WHITESPACE
                          :comment :COMMENT
                          :dis_expr [:seq [:field "marker" "#_"]
                                          [:repeat :_gap]
                                          [:field "value" :_form]]]]
                 buf))
  # =>
  @``
   {
   source: $ =>
   repeat($._lit),
   comment: $ =>
   regex("#.*"),
   _gap: $ =>
   choice($._ws, $.comment, $.dis_expr),
   _ws: $ =>
   WHITESPACE,
   comment: $ =>
   COMMENT,
   dis_expr: $ =>
   seq(field("marker", "#_"), repeat($._gap), field("value", $._form))
   }
   ``

  )

(defn emit-extras!
  [grammar buf]
  (def extras-maybe
    (get-val grammar :extras))
  (def type-of-em
    (type extras-maybe))
  (assert (or (nil? extras-maybe)
              (= :tuple type-of-em))
          (string/format "extras should be a tuple or nil, found a %M"
                         type-of-em))
  (def extras extras-maybe)
  #
  (emit-start-array! buf)
  #
  (each extra extras
    (emit-expr! extra buf)
    (emit-comma-nl! buf))
  (pop-comma-nl-maybe! buf)
  #
  (emit-end-array! buf)
  #
  buf)

(comment

  (let [buf @""]
    (emit-extras! [:extras [[:regex "\\s|\\x0b|\\x0c|\\x00"]
                            :comment]]
                 buf))
  # =>
  @``
   [
   regex("\\s|\\x0b|\\x0c|\\x00"),
   $.comment
   ]
   ``

  )

(defn emit-conflicts!
  [grammar buf]
  (def conflicts-maybe
    (get-val grammar :conflicts))
  (def type-of-em
    (type conflicts-maybe))
  (assert (or (nil? conflicts-maybe)
              (= :tuple type-of-em))
          (string/format "conflicts should be a tuple or nil, found a %M"
                         type-of-em))
  (def conflicts conflicts-maybe)
  #
  (emit-start-array! buf)
  #
  (each conflict conflicts
    # each conflict is expected to be a tuple
    (def type-of-conf
      (type conflict))
    (assert (= :tuple type-of-conf)
            (string/format "conflict should be a tuple, found a %M"
                           type-of-conf))
    #
    (emit-start-array! buf)
    #
    (each item conflict
      (emit-sym! item buf)
      (emit-comma-space! buf))
    (pop-comma-space-maybe! buf)
    #
    (emit-end-array! buf)
    #
    (emit-comma-nl! buf))
  (pop-comma-nl-maybe! buf)
  #
  (emit-end-array! buf)
  #
  buf)

(comment

  (let [buf @""]
    (emit-conflicts! [:conflicts [[:constant_primary :primary]
                                  [:primary :implicit_class_handle]]]
                    buf))
  # =>
  @``
   [
   [
   $.constant_primary, $.primary
   ],
   [
   $.primary, $.implicit_class_handle
   ]
   ]
   ``
  )

(defn emit-externals!
  [grammar buf]
  (def externals-maybe
    (get-val grammar :externals))
  (def type-of-em
    (type externals-maybe))
  (assert (or (nil? externals-maybe)
              (= :tuple type-of-em))
          (string/format "externals should be a tuple or nil, found a %M"
                         type-of-em))
  (def externals externals-maybe)
  #
  (emit-start-array! buf)
  #
  (each external externals
    (emit-expr! external buf)
    (emit-comma-nl! buf))
  (pop-comma-nl-maybe! buf)
  #
  (emit-end-array! buf)
  #
  buf)

(comment

  (let [buf @""]
    (emit-externals! [:externals [:long_buf_lit :long_str_lit]]
                     buf))
  # =>
  @``
   [
   $.long_buf_lit,
   $.long_str_lit
   ]
   ``

  )

(defn emit-inline!
  [grammar buf]
  (def inline-maybe
    (get-val grammar :inline))
  (def type-of-em
    (type inline-maybe))
  (assert (or (nil? inline-maybe)
              (= :tuple type-of-em))
          (string/format "inline should be a tuple or nil, found a %M"
                         type-of-em))
  (def inline inline-maybe)
  #
  (emit-start-array! buf)
  #
  (each item inline
    (emit-sym! item buf)
    (emit-comma-nl! buf))
  (pop-comma-nl-maybe! buf)
  #
  (emit-end-array! buf)
  #
  buf)

(comment

  (let [buf @""]
    (emit-inline! [:inline [:_sym_qualified
                            :_sym_unqualified]]
                    buf))
  # =>
  @``
   [
   $._sym_qualified,
   $._sym_unqualified
   ]
   ``

  )

# XXX: other emit-*! functions should go here

(defn emit-grammar-call-assign!
  [grammar buf]
  (def rules
    (get-val grammar :rules))
  (assert (indexed? rules)
          (string/format "indexed ds expected, found: %M"
                         (type rules)))
  #
  (emit-left-assign! "module.exports" buf)
  (emit-start-func-call! "grammar" buf)
  (emit-start-obj! buf)
  #
  (each key grammar-keys-in-order
    (when (get-val grammar key)
      (emit-bare-key! key buf)
      #
      (case key
        :name
        (emit-name! grammar buf)
        # XXX
        #:word
        #(emit-word! grammar buf)
        #
        :rules
        (emit-rules! grammar buf)
        #
        :extras
        (do
          (emit-start-arrow-func! buf)
          (emit-nl! buf)
          (emit-extras! grammar buf))
        #
        :conflicts
        (do
          (emit-start-arrow-func! buf)
          (emit-nl! buf)
          (emit-conflicts! grammar buf))
        # XXX
        #:precedences
        #(emit-precedences! grammar buf)
        #
        :externals
        (do
          (emit-start-arrow-func! buf)
          (emit-nl! buf)
          (emit-externals! grammar buf))
        #
        :inline
        (do
          (emit-start-arrow-func! buf)
          (emit-nl! buf)
          (emit-inline! grammar buf))
        # XXX
        #:supertypes
        #(emit-supertypes! grammar buf)
        # defensive measure
        (errorf "Unknown key: %M" key))
      #
      (emit-comma-nl! buf)))
  #
  (pop-comma-nl-maybe! buf)
  #
  (emit-end-obj! buf)
  (emit-end-func-call! buf)
  (emit-end-statement! buf)
  #
  buf)

(defn emit-js!
  [grammar buf]
  # 2-part structure -- see beginning of file
  #
  # 1. top-level definitions
  #
  # 1a. wrapper function
  (emit-regex-func-decl! buf)
  #
  (emit-nl! buf)
  (emit-nl! buf)
  # 1b. const declarations
  (emit-const-decls! grammar buf)
  #
  (emit-nl! buf)
  (emit-nl! buf)
  #
  # 2. grammar call assignment
  (emit-grammar-call-assign! grammar buf)
  #
  buf)

(defn gen-js
  ``
  Generate `grammar.js` content from a `grammar`.

  `grammar` is typically parsed from `grammar.jdn`.
  ``
  [grammar]
  (let [buf @""]
    (emit-js! grammar buf)
    buf))

(comment

  (def src
    (slurp "../data/grammar.jdn"))

  (def parsed
    (parse src))

  (def js-as-str
    (gen-js parsed))

  (print js-as-str)

  (spit "/tmp/grammar.js" js-as-str)

  )
