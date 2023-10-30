import gleam/map.{Map}
import gleam/bool
import gleam/string
import gleam/result
import gleam/list
import amf0/marker

pub type Value {
  Number(Float)
  Boolean(Bool)
  String(String)
  Object(Map(String, Value))
  StrictArray(List(Value))
  Null
  Undefined
}

const u16_max = 65_535

const u32_max = 4_294_967_295

pub type SerializeError {
  /// The string length exceeds the maximum length of a regular string (u16 max)
  StringTooLong
  /// The array length exceeds the maximum length of a strict array (u32 max)
  StrictArrayTooLong
}

/// Serialize a list of amf0 Values into a BitString
pub fn serialize(values: List(Value)) -> Result(BitString, SerializeError) {
  use bs, value <- list.fold(values, Ok(<<>>))
  use bs <- result.try(bs)
  use value <- result.map(serialize_value(value))
  <<bs:bit_string, value:bit_string>>
}

/// Serialize a single amf0 Value into a BitString
pub fn serialize_value(value: Value) -> Result(BitString, SerializeError) {
  case value {
    Number(val) -> Ok(serialize_number(val))
    Boolean(val) -> Ok(serialize_bool(val))
    String(val) -> serialize_string(val)
    Object(val) -> serialize_object(val)
    StrictArray(val) -> serialize_strict_array(val)
    Null -> Ok(serialize_null())
    Undefined -> Ok(serialize_undefined())
  }
}

fn serialize_number(value: Float) -> BitString {
  <<marker.number, value:float>>
}

fn serialize_bool(value: Bool) -> BitString {
  <<marker.boolean, bool.to_int(value)>>
}

fn serialize_string(value: String) -> Result(BitString, SerializeError) {
  serialize_utf8(value)
  |> result.map(fn(utf8) { <<marker.string, utf8:bit_string>> })
}

fn serialize_utf8(value: String) -> Result(BitString, SerializeError) {
  case string.length(value) {
    x if x > u16_max -> Error(StringTooLong)
    _ -> Ok(<<string.length(value):16, value:utf8>>)
  }
}

fn serialize_object(
  value: Map(String, Value),
) -> Result(BitString, SerializeError) {
  use properties <- result.map(serialize_properties(value))
  <<marker.object, properties:bit_string, "":utf8, marker.object_end>>
}

fn serialize_properties(
  properties: Map(String, Value),
) -> Result(BitString, SerializeError) {
  use bs, key, value <- map.fold(properties, Ok(<<>>))
  use bs <- result.try(bs)
  use key <- result.try(serialize_utf8(key))
  use value <- result.map(serialize_value(value))
  <<bs:bit_string, key:bit_string, value:bit_string>>
}

fn serialize_strict_array(
  list: List(Value),
) -> Result(BitString, SerializeError) {
  case list.length(list) {
    x if x > u32_max -> Error(StrictArrayTooLong)
    _ -> {
      use items <- result.map(serialize(list))
      <<marker.strict_array, list.length(list):32, items:bit_string>>
    }
  }
}

fn serialize_null() -> BitString {
  <<marker.null>>
}

fn serialize_undefined() -> BitString {
  <<marker.undefined>>
}
