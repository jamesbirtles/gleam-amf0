import gleam/map.{type Map}
import gleam/bool
import gleam/string
import gleam/result
import gleam/list
import gleam/bit_array
import gleam/option.{type Option, None, Some}
import gleam/pair
import amf0/marker.{type Marker}

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

pub fn deserialize(bytes: BitArray) -> Result(List(Value), DeserializeError) {
  deserialize_next(bytes, [])
}

fn deserialize_next(
  bytes: BitArray,
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
  bytes: BitArray,
) -> Result(#(Value, BitArray), DeserializeError) {
  case bytes {
    <<marker, rest:bits>> -> {
      marker.from_int(marker)
      |> result.map_error(UnknownMarker)
      |> result.try(fn(marker) { deserialize_value_from_marker(marker, rest) })
    }
    _ -> Error(MissingMarker)
  }
}

fn deserialize_value_from_marker(
  marker: Marker,
  bytes: BitArray,
) -> Result(#(Value, BitArray), DeserializeError) {
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
  bytes: BitArray,
) -> Result(#(Value, BitArray), DeserializeError) {
  case bytes {
    <<value:float, rest:bits>> -> Ok(#(Number(value), rest))
    _ -> Error(MalformedInput(marker.Number))
  }
}

fn deserialize_bool(
  bytes: BitArray,
) -> Result(#(Value, BitArray), DeserializeError) {
  case bytes {
    <<value, rest:bits>> if value == 1 -> Ok(#(Boolean(True), rest))
    <<value, rest:bits>> if value == 0 -> Ok(#(Boolean(False), rest))
    _ -> Error(MalformedInput(marker.Boolean))
  }
}

fn deserialize_string(
  bytes: BitArray,
) -> Result(#(Value, BitArray), DeserializeError) {
  deserialize_utf8_string(bytes)
  |> result.map(pair.map_first(_, String))
}

fn deserialize_utf8_string(
  bytes: BitArray,
) -> Result(#(String, BitArray), DeserializeError) {
  case bytes {
    <<0:16, rest:bits>> -> Ok(#("", rest))
    <<length:16, bytes:bits>> -> {
      use string <- result.try(
        bit_array.slice(bytes, 0, length)
        |> result.try(bit_array.to_string)
        |> result.replace_error(MalformedInput(marker.String)),
      )
      let rest =
        bit_array.slice(bytes, length, bit_array.byte_size(bytes) - length)
        |> result.unwrap(<<>>)
      Ok(#(string, rest))
    }
    _ -> Error(MalformedInput(marker.String))
  }
}

fn deserialize_object(
  bytes: BitArray,
) -> Result(#(Value, BitArray), DeserializeError) {
  use #(properties, bytes) <- result.try(deserialize_object_properties(
    bytes,
    map.new(),
  ))
  case bytes {
    <<0:16, "":utf8, 0x09, rest:bits>> -> Ok(#(Object(properties), rest))
    _ -> Error(MalformedInput(marker.Object))
  }
}

fn deserialize_object_properties(
  bytes: BitArray,
  properties: Map(String, Value),
) -> Result(#(Map(String, Value), BitArray), DeserializeError) {
  case deserialize_object_property(bytes) {
    Ok(#(Some(#(key, value)), rest)) ->
      deserialize_object_properties(rest, map.insert(properties, key, value))
    Ok(#(None, _)) -> Ok(#(properties, bytes))
    Error(error) -> Error(error)
  }
}

fn deserialize_object_property(
  bytes: BitArray,
) -> Result(#(Option(#(String, Value)), BitArray), DeserializeError) {
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
  bytes: BitArray,
) -> Result(#(Value, BitArray), DeserializeError) {
  case bytes {
    <<length:32-unsigned, rest:bits>> ->
      deserialize_n_values(rest, length, [])
      |> result.map(pair.map_first(_, list.reverse))
      |> result.map(pair.map_first(_, StrictArray))
    _ -> Error(MalformedInput(marker.StrictArray))
  }
}

fn deserialize_n_values(
  bytes: BitArray,
  remaining: Int,
  list: List(Value),
) -> Result(#(List(Value), BitArray), DeserializeError) {
  case remaining {
    0 -> Ok(#(list, bytes))
    _ -> {
      use #(value, rest) <- result.try(deserialize_value(bytes))
      deserialize_n_values(rest, remaining - 1, [value, ..list])
    }
  }
}

fn deserialize_null(
  bytes: BitArray,
) -> Result(#(Value, BitArray), DeserializeError) {
  Ok(#(Null, bytes))
}

fn deserialize_undefined(
  bytes: BitArray,
) -> Result(#(Value, BitArray), DeserializeError) {
  Ok(#(Undefined, bytes))
}

pub type SerializeError {
  /// The string length exceeds the maximum length of a regular string (u16 max)
  StringTooLong
  /// The array length exceeds the maximum length of a strict array (u32 max)
  StrictArrayTooLong
}

/// Serialize a list of amf0 Values into a BitString
pub fn serialize(values: List(Value)) -> Result(BitArray, SerializeError) {
  use bs, value <- list.fold(values, Ok(<<>>))
  use bs <- result.try(bs)
  use value <- result.map(serialize_value(value))
  <<bs:bits, value:bits>>
}

/// Serialize a single amf0 Value into a BitString
pub fn serialize_value(value: Value) -> Result(BitArray, SerializeError) {
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

fn serialize_number(value: Float) -> BitArray {
  <<marker.to_int(marker.Number), value:float>>
}

fn serialize_bool(value: Bool) -> BitArray {
  <<marker.to_int(marker.Boolean), bool.to_int(value)>>
}

fn serialize_string(value: String) -> Result(BitArray, SerializeError) {
  serialize_utf8(value)
  |> result.map(fn(utf8) { <<marker.to_int(marker.String), utf8:bits>> })
}

fn serialize_utf8(value: String) -> Result(BitArray, SerializeError) {
  case string.byte_size(value) {
    x if x > u16_max -> Error(StringTooLong)
    length -> Ok(<<length:16, value:utf8>>)
  }
}

fn serialize_object(
  value: Map(String, Value),
) -> Result(BitArray, SerializeError) {
  use properties <- result.map(serialize_properties(value))
  <<
    marker.to_int(marker.Object),
    properties:bits,
    0:16,
    marker.to_int(marker.ObjectEnd),
  >>
}

fn serialize_properties(
  properties: Map(String, Value),
) -> Result(BitArray, SerializeError) {
  use bs, key, value <- map.fold(properties, Ok(<<>>))
  use bs <- result.try(bs)
  use key <- result.try(serialize_utf8(key))
  use value <- result.map(serialize_value(value))
  <<bs:bits, key:bits, value:bits>>
}

fn serialize_strict_array(list: List(Value)) -> Result(BitArray, SerializeError) {
  case list.length(list) {
    x if x > u32_max -> Error(StrictArrayTooLong)
    _ -> {
      use items <- result.map(serialize(list))
      <<marker.to_int(marker.StrictArray), list.length(list):32, items:bits>>
    }
  }
}

fn serialize_null() -> BitArray {
  <<marker.to_int(marker.Null)>>
}

fn serialize_undefined() -> BitArray {
  <<marker.to_int(marker.Undefined)>>
}
