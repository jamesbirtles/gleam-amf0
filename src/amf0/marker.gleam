pub type Marker {
  Number
  Boolean
  String
  Object
  Null
  Undefined
  Reference
  EcmaArray
  ObjectEnd
  StrictArray
  Date
  LongString
  Unsupported
  XmlDocument
  TypedObject
}

pub fn to_int(marker: Marker) -> Int {
  case marker {
    Number -> 0x00
    Boolean -> 0x01
    String -> 0x02
    Object -> 0x03
    Null -> 0x05
    Undefined -> 0x06
    Reference -> 0x07
    EcmaArray -> 0x08
    ObjectEnd -> 0x09
    StrictArray -> 0x0A
    Date -> 0x0B
    LongString -> 0x0C
    Unsupported -> 0x0D
    XmlDocument -> 0x0F
    TypedObject -> 0x10
  }
}

pub fn from_int(value: Int) -> Result(Marker, Int) {
  case value {
    0x00 -> Ok(Number)
    0x01 -> Ok(Boolean)
    0x02 -> Ok(String)
    0x03 -> Ok(Object)
    0x05 -> Ok(Null)
    0x06 -> Ok(Undefined)
    0x07 -> Ok(Reference)
    0x08 -> Ok(EcmaArray)
    0x09 -> Ok(ObjectEnd)
    0x0A -> Ok(StrictArray)
    0x0B -> Ok(Date)
    0x0C -> Ok(LongString)
    0x0D -> Ok(Unsupported)
    0x0F -> Ok(XmlDocument)
    0x10 -> Ok(TypedObject)
    _ -> Error(value)
  }
}
