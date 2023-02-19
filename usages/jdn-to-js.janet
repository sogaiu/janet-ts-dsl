(import ../janet-ts-dsl/emit-js :prefix "")
(import ../janet-ts-dsl/jdn-to-js :prefix "")

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
    (def expr (get tokens (inc i)))
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
      (emit-bare-key! key buf)
      (def expr (get rules (inc i)))
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
      (emit-bare-key! key buf)
      (def expr (get rules (inc i)))
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
