(import ../janet-ts-dsl/jdn-to-json :prefix "")

(comment

  (let [buf @""]
    (gen-defs-rule! [:repeat "_"] buf))
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
    (gen-defs-rule! [:token [:choice "false" "true"]] buf))
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
    (gen-defs-rule! [:seq "," :_lit] buf))
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
    (gen-defs-rule! [:prec 5 [:choice :_dec
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
    (gen-defs-rule! [:optional "."]
                    buf))
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

  )
