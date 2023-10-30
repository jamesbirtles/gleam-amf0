import gleeunit
import gleeunit/should
import amf0
import amf0/marker
import gleam/map

pub fn main() {
  gleeunit.main()
}

pub fn deserialize_number_test() {
  <<marker.to_int(marker.Number), 42.0:float>>
  |> amf0.deserialize_value
  |> should.equal(Ok(#(amf0.Number(42.0), <<>>)))
}

pub fn deserialize_bool_true_test() {
  <<marker.to_int(marker.Boolean), 1>>
  |> amf0.deserialize_value
  |> should.equal(Ok(#(amf0.Boolean(True), <<>>)))
}

pub fn deserialize_bool_false_test() {
  <<marker.to_int(marker.Boolean), 0>>
  |> amf0.deserialize_value
  |> should.equal(Ok(#(amf0.Boolean(False), <<>>)))
}

pub fn deserialize_string_test() {
  <<marker.to_int(marker.String), 5:16, "hello":utf8>>
  |> amf0.deserialize_value
  |> should.equal(Ok(#(amf0.String("hello"), <<>>)))
}

pub fn deserialize_object_empty_test() {
  <<marker.to_int(marker.Object), 0:16, marker.to_int(marker.ObjectEnd)>>
  |> amf0.deserialize_value
  |> should.equal(Ok(#(amf0.Object(map.new()), <<>>)))
}

pub fn deserialize_object_single_field_test() {
  <<
    marker.to_int(marker.Object),
    5:16,
    "hello":utf8,
    marker.to_int(marker.Number),
    42.0:float,
    0:16,
    marker.to_int(marker.ObjectEnd),
  >>
  |> amf0.deserialize_value
  |> should.equal(Ok(#(
    amf0.Object(map.from_list([#("hello", amf0.Number(42.0))])),
    <<>>,
  )))
}

pub fn deserialize_object_multiple_fields_test() {
  <<
    marker.to_int(marker.Object),
    5:16,
    "hello":utf8,
    marker.to_int(marker.Number),
    42.0:float,
    5:16,
    "world":utf8,
    marker.to_int(marker.Number),
    69.0:float,
    0:16,
    marker.to_int(marker.ObjectEnd),
  >>
  |> amf0.deserialize_value
  |> should.equal(Ok(#(
    amf0.Object(map.from_list([
      #("hello", amf0.Number(42.0)),
      #("world", amf0.Number(69.0)),
    ])),
    <<>>,
  )))
}

pub fn deserialize_strict_array_empty() {
  <<marker.to_int(marker.StrictArray), 0:32>>
  |> amf0.deserialize_value
  |> should.equal(Ok(#(amf0.StrictArray([]), <<>>)))
}

pub fn deserialize_strict_array_single_item_test() {
  <<
    marker.to_int(marker.StrictArray),
    1:32,
    marker.to_int(marker.Number),
    42.0:float,
  >>
  |> amf0.deserialize_value
  |> should.equal(Ok(#(amf0.StrictArray([amf0.Number(42.0)]), <<>>)))
}

pub fn deserialize_strict_array_multiple_items_test() {
  <<
    marker.to_int(marker.StrictArray),
    3:32,
    marker.to_int(marker.Number),
    42.0:float,
    marker.to_int(marker.Undefined),
    marker.to_int(marker.String),
    5:16,
    "hello":utf8,
  >>
  |> amf0.deserialize_value
  |> should.equal(Ok(#(
    amf0.StrictArray([amf0.Number(42.0), amf0.Undefined, amf0.String("hello")]),
    <<>>,
  )))
}

pub fn deserialize_null_test() {
  <<marker.to_int(marker.Null)>>
  |> amf0.deserialize_value
  |> should.equal(Ok(#(amf0.Null, <<>>)))
}

pub fn deserialize_undefined_test() {
  <<marker.to_int(marker.Undefined)>>
  |> amf0.deserialize_value
  |> should.equal(Ok(#(amf0.Undefined, <<>>)))
}

pub fn deserialize_test() {
  <<
    marker.to_int(marker.Number),
    1.0:float,
    marker.to_int(marker.Number),
    2.0:float,
    marker.to_int(marker.Number),
    3.0:float,
  >>
  |> amf0.deserialize
  |> should.equal(Ok([amf0.Number(1.0), amf0.Number(2.0), amf0.Number(3.0)]))
}

pub fn serialize_number_test() {
  amf0.Number(42.0)
  |> amf0.serialize_value
  |> should.equal(Ok(<<marker.to_int(marker.Number), 42.0:float>>))
}

pub fn serialize_bool_true_test() {
  amf0.Boolean(True)
  |> amf0.serialize_value
  |> should.equal(Ok(<<marker.to_int(marker.Boolean), 1>>))
}

pub fn serialize_bool_false_test() {
  amf0.Boolean(False)
  |> amf0.serialize_value
  |> should.equal(Ok(<<marker.to_int(marker.Boolean), 0>>))
}

pub fn serialize_string_test() {
  amf0.String("hello")
  |> amf0.serialize_value
  |> should.equal(Ok(<<marker.to_int(marker.String), 5:16, "hello":utf8>>))
}

pub fn serialize_object_empty_test() {
  amf0.Object(map.new())
  |> amf0.serialize_value
  |> should.equal(Ok(<<
    marker.to_int(marker.Object),
    0:16,
    marker.to_int(marker.ObjectEnd),
  >>))
}

pub fn serialize_object_single_field_test() {
  amf0.Object(map.from_list([#("hello", amf0.Number(42.0))]))
  |> amf0.serialize_value
  |> should.equal(Ok(<<
    marker.to_int(marker.Object),
    5:16,
    "hello":utf8,
    marker.to_int(marker.Number),
    42.0:float,
    0:16,
    marker.to_int(marker.ObjectEnd),
  >>))
}

pub fn serialize_object_multiple_fields_test() {
  amf0.Object(map.from_list([
    #("hello", amf0.Number(42.0)),
    #("world", amf0.Number(69.0)),
  ]))
  |> amf0.serialize_value
  |> should.equal(Ok(<<
    marker.to_int(marker.Object),
    5:16,
    "hello":utf8,
    marker.to_int(marker.Number),
    42.0:float,
    5:16,
    "world":utf8,
    marker.to_int(marker.Number),
    69.0:float,
    0:16,
    marker.to_int(marker.ObjectEnd),
  >>))
}

pub fn serialize_strict_array_empty_test() {
  amf0.StrictArray([])
  |> amf0.serialize_value
  |> should.equal(Ok(<<marker.to_int(marker.StrictArray), 0:32>>))
}

pub fn serialize_strict_array_single_item_test() {
  amf0.StrictArray([amf0.Number(42.0)])
  |> amf0.serialize_value
  |> should.equal(Ok(<<
    marker.to_int(marker.StrictArray),
    1:32,
    marker.to_int(marker.Number),
    42.0:float,
  >>))
}

pub fn serialize_strict_array_multiple_items_test() {
  amf0.StrictArray([amf0.Number(42.0), amf0.Undefined, amf0.String("hello")])
  |> amf0.serialize_value
  |> should.equal(Ok(<<
    marker.to_int(marker.StrictArray),
    3:32,
    marker.to_int(marker.Number),
    42.0:float,
    marker.to_int(marker.Undefined),
    marker.to_int(marker.String),
    5:16,
    "hello":utf8,
  >>))
}

pub fn serialize_null_test() {
  amf0.Null
  |> amf0.serialize_value
  |> should.equal(Ok(<<marker.to_int(marker.Null)>>))
}

pub fn serialize_undefined_test() {
  amf0.Undefined
  |> amf0.serialize_value
  |> should.equal(Ok(<<marker.to_int(marker.Undefined)>>))
}

pub fn serialize_test() {
  [amf0.Number(1.0), amf0.Number(2.0), amf0.Number(3.0)]
  |> amf0.serialize
  |> should.equal(Ok(<<
    marker.to_int(marker.Number),
    1.0:float,
    marker.to_int(marker.Number),
    2.0:float,
    marker.to_int(marker.Number),
    3.0:float,
  >>))
}
