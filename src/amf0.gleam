import gleam/map.{Map}
import gleam/bool
import gleam/string
import gleam/result
import gleam/list
import gleam/bit_string
import gleam/option.{None, Option, Some}
import gleam/pair
import amf0/marker.{Marker}

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

pub type DeserializeError {
  /// The BitString did not contain enough data to extract a marker
  MissingMarker
  /// The marker given was of an unknown type to us
  UnknownMarker(Int)
  /// The marker given was of a known type, but we don't handle this type (yet)
  UnsupportedMarker(Marker)
  /// The input was not of a valid format for the given marker
  MalformedInput(Marker)
}

pub fn deserialize(bytes: BitString) -> Result(List(Value), DeserializeError) {
  deserialize_next(bytes, [])
}

fn deserialize_next(
  bytes: BitString,
  list: List(Value),
) -> Result(List(Value), DeserializeError) {
  case bytes {
    <<>> -> Ok(list.reverse(list))
    _ -> {
      use #(value, rest) <- result.try(deserialize_value(bytes))
      deserialize_next(rest, [value, ..list])
    }
  }
}

pub fn deserialize_value(
  bytes: BitString,
) -> Result(#(Value, BitString), DeserializeError) {
  case bytes {
    <<marker, rest:bit_string>> -> {
      marker.from_int(marker)
      |> result.map_error(UnknownMarker)
      |> result.try(fn(marker) { deserialize_value_from_marker(marker, rest) })
    }
    _ -> Error(MissingMarker)
  }
}

fn deserialize_value_from_marker(
  marker: Marker,
  bytes: BitString,
) -> Result(#(Value, BitString), DeserializeError) {
  case marker {
    marker.Number -> deserialize_number(bytes)
    marker.Boolean -> deserialize_bool(bytes)
    marker.String -> deserialize_string(bytes)
    marker.Object -> deserialize_object(bytes)
    marker.StrictArray -> deserialize_strict_array(bytes)
    marker.Null -> deserialize_null(bytes)
    marker.Undefined -> deserialize_undefined(bytes)
    _ -> Error(UnsupportedMarker(marker))
  }
}

fn deserialize_number(
  bytes: BitString,
) -> Result(#(Value, BitString), DeserializeError) {
  case bytes {
    <<value:float, rest:bit_string>> -> Ok(#(Number(value), rest))
    _ -> Error(MalformedInput(marker.Number))
  }
}

fn deserialize_bool(
  bytes: BitString,
) -> Result(#(Value, BitString), DeserializeError) {
  case bytes {
    <<value, rest:bit_string>> if value == 1 -> Ok(#(Boolean(True), rest))
    <<value, rest:bit_string>> if value == 0 -> Ok(#(Boolean(False), rest))
    _ -> Error(MalformedInput(marker.Boolean))
  }
}

fn deserialize_string(
  bytes: BitString,
) -> Result(#(Value, BitString), DeserializeError) {
  deserialize_utf8_string(bytes)
  |> result.map(pair.map_first(_, String))
}

fn deserialize_utf8_string(
  bytes: BitString,
) -> Result(#(String, BitString), DeserializeError) {
  case bytes {
    <<0:16, rest:bit_string>> -> Ok(#("", rest))
    <<length:16, bytes:bit_string>> -> {
      use string <- result.try(
        bit_string.slice(bytes, 0, length)
        |> result.try(bit_string.to_string)
        |> result.replace_error(MalformedInput(marker.String)),
      )
      let rest =
        bit_string.slice(bytes, length, bit_string.byte_size(bytes) - length)
        |> result.unwrap(<<>>)
      Ok(#(string, rest))
    }
    _ -> Error(MalformedInput(marker.String))
  }
}

fn deserialize_object(
  bytes: BitString,
) -> Result(#(Value, BitString), DeserializeError) {
  use #(properties, bytes) <- result.try(deserialize_object_properties(
    bytes,
    map.new(),
  ))
  case bytes {
    <<0:16, "":utf8, 0x09, rest:bit_string>> -> Ok(#(Object(properties), rest))
    _ -> Error(MalformedInput(marker.Object))
  }
}

fn deserialize_object_properties(
  bytes: BitString,
  properties: Map(String, Value),
) -> Result(#(Map(String, Value), BitString), DeserializeError) {
  case deserialize_object_property(bytes) {
    Ok(#(Some(#(key, value)), rest)) ->
      deserialize_object_properties(rest, map.insert(properties, key, value))
    Ok(#(None, _)) -> Ok(#(properties, bytes))
    Error(error) -> Error(error)
  }
}

fn deserialize_object_property(
  bytes: BitString,
) -> Result(#(Option(#(String, Value)), BitString), DeserializeError) {
  use #(key, bytes) <- result.try(deserialize_utf8_string(bytes))
  case key {
    "" -> Ok(#(None, bytes))
    _ ->
      deserialize_value(bytes)
      |> result.map(pair.map_first(_, pair.new(key, _)))
      |> result.map(pair.map_first(_, Some))
  }
}

fn deserialize_strict_array(
  bytes: BitString,
) -> Result(#(Value, BitString), DeserializeError) {
  case bytes {
    <<length:32-unsigned, rest:bit_string>> ->
      deserialize_n_values(rest, length, [])
      |> result.map(pair.map_first(_, list.reverse))
      |> result.map(pair.map_first(_, StrictArray))
    _ -> Error(MalformedInput(marker.StrictArray))
  }
}

fn deserialize_n_values(
  bytes: BitString,
  remaining: Int,
  list: List(Value),
) -> Result(#(List(Value), BitString), DeserializeError) {
  case remaining {
    0 -> Ok(#(list, bytes))
    _ -> {
      use #(value, rest) <- result.try(deserialize_value(bytes))
      deserialize_n_values(rest, remaining - 1, [value, ..list])
    }
  }
}

fn deserialize_null(
  bytes: BitString,
) -> Result(#(Value, BitString), DeserializeError) {
  Ok(#(Null, bytes))
}

fn deserialize_undefined(
  bytes: BitString,
) -> Result(#(Value, BitString), DeserializeError) {
  Ok(#(Undefined, bytes))
}

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
  <<marker.to_int(marker.Number), value:float>>
}

fn serialize_bool(value: Bool) -> BitString {
  <<marker.to_int(marker.Boolean), bool.to_int(value)>>
}

fn serialize_string(value: String) -> Result(BitString, SerializeError) {
  serialize_utf8(value)
  |> result.map(fn(utf8) { <<marker.to_int(marker.String), utf8:bit_string>> })
}

fn serialize_utf8(value: String) -> Result(BitString, SerializeError) {
  case string.byte_size(value) {
    x if x > u16_max -> Error(StringTooLong)
    length -> Ok(<<length:16, value:utf8>>)
  }
}

fn serialize_object(
  value: Map(String, Value),
) -> Result(BitString, SerializeError) {
  use properties <- result.map(serialize_properties(value))
  <<
    marker.to_int(marker.Object),
    properties:bit_string,
    0:16,
    marker.to_int(marker.ObjectEnd),
  >>
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
      <<
        marker.to_int(marker.StrictArray),
        list.length(list):32,
        items:bit_string,
      >>
    }
  }
}

fn serialize_null() -> BitString {
  <<marker.to_int(marker.Null)>>
}

fn serialize_undefined() -> BitString {
  <<marker.to_int(marker.Undefined)>>
}
