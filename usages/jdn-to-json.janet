(import ../janet-ts-dsl/jdn-to-json :prefix "")

(comment

  (let [buf @""]
    (emit-defs-rule! [:repeat "_"] buf))
  # =>
  @``
   {
     "type": "REPEAT",
     "content": {
     "type": "STRING",
     "value": "_"
   }
   }
   ``

  (let [buf @""]
    (emit-defs-rule! [:token [:choice "false" "true"]]
                     buf))
  # =>
  @``
   {
     "type": "TOKEN",
     "content": {
     "type": "CHOICE",
     "members": [
   {
     "type": "STRING",
     "value": "false"
   },
   {
     "type": "STRING",
     "value": "true"
   }
   ]
   }
   }
   ``

  (let [buf @""]
    (emit-defs-rule! [:seq "," :_lit] buf))
  # =>
  @``
   {
     "type": "SEQ",
     "members": [
   {
     "type": "STRING",
     "value": ","
   },
   {
     "type": "SYMBOL",
     "name": "_lit"
   }
   ]
   }
   ``

  (let [buf @""]
    (emit-defs-rule! [:prec 5 [:choice :_dec
                                       :_hex
                                       :_radix]]
                     buf))
  # =>
  @``
   {
     "type": "PREC",
     "value": 5,
     "content": {
     "type": "CHOICE",
     "members": [
   {
     "type": "SYMBOL",
     "name": "_dec"
   },
   {
     "type": "SYMBOL",
     "name": "_hex"
   },
   {
     "type": "SYMBOL",
     "name": "_radix"
   }
   ]
   }
   }
   ``

  (let [buf @""]
    (emit-defs-rule! [:optional "."] buf))
  # =>
  @``
   {
     "type": "CHOICE",
     "members": [
   {
     "type": "STRING",
     "value": "."
   },
   {
     "type": "BLANK"
   }
   ]
   }
   ``

  (let [buf @""]
    (emit-defs-rule! [:prec_left :_expression] buf))
  # =>
  @``
   {
     "type": "PREC_LEFT",
     "value": 0,
     "content": {
     "type": "SYMBOL",
     "name": "_expression"
   }
   }
   ``

  )
