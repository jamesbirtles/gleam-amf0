import gleeunit
import gleeunit/should
import amf0
import amf0/marker
import gleam/map

pub fn main() {
  gleeunit.main()
}

pub fn serialize_number_test() {
  amf0.Number(42.0)
  |> amf0.serialize_value
  |> should.equal(Ok(<<marker.number, 42.0:float>>))
}

pub fn serialize_bool_true_test() {
  amf0.Boolean(True)
  |> amf0.serialize_value
  |> should.equal(Ok(<<marker.boolean, 1>>))
}

pub fn serialize_bool_false_test() {
  amf0.Boolean(False)
  |> amf0.serialize_value
  |> should.equal(Ok(<<marker.boolean, 0>>))
}

pub fn serialize_string_test() {
  amf0.String("hello")
  |> amf0.serialize_value
  |> should.equal(Ok(<<marker.string, 5:16, "hello":utf8>>))
}

pub fn serialize_object_empty_test() {
  amf0.Object(map.new())
  |> amf0.serialize_value
  |> should.equal(Ok(<<marker.object, "":utf8, marker.object_end>>))
}

pub fn serialize_object_single_field_test() {
  amf0.Object(map.from_list([#("hello", amf0.Number(42.0))]))
  |> amf0.serialize_value
  |> should.equal(Ok(<<
    marker.object,
    5:16,
    "hello":utf8,
    marker.number,
    42.0:float,
    "":utf8,
    marker.object_end,
  >>))
}

pub fn serialize_object_multiple_fields_test() {
  amf0.Object(map.from_list([
    #("hello", amf0.Number(42.0)),
    #("world", amf0.Number(69.0)),
  ]))
  |> amf0.serialize_value
  |> should.equal(Ok(<<
    marker.object,
    5:16,
    "hello":utf8,
    marker.number,
    42.0:float,
    5:16,
    "world":utf8,
    marker.number,
    69.0:float,
    "":utf8,
    marker.object_end,
  >>))
}

pub fn serialize_strict_array_empty_test() {
  amf0.StrictArray([])
  |> amf0.serialize_value
  |> should.equal(Ok(<<marker.strict_array, 0:32>>))
}

pub fn serialize_strict_array_single_item_test() {
  amf0.StrictArray([amf0.Number(42.0)])
  |> amf0.serialize_value
  |> should.equal(Ok(<<marker.strict_array, 1:32, marker.number, 42.0:float>>))
}

pub fn serialize_strict_array_multiple_items_test() {
  amf0.StrictArray([amf0.Number(42.0), amf0.Undefined, amf0.String("hello")])
  |> amf0.serialize_value
  |> should.equal(Ok(<<
    marker.strict_array,
    3:32,
    marker.number,
    42.0:float,
    marker.undefined,
    marker.string,
    5:16,
    "hello":utf8,
  >>))
}

pub fn serialize_null_test() {
  amf0.Null
  |> amf0.serialize_value
  |> should.equal(Ok(<<marker.null>>))
}

pub fn serialize_undefined_test() {
  amf0.Undefined
  |> amf0.serialize_value
  |> should.equal(Ok(<<marker.undefined>>))
}
