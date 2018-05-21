defmodule IRTypeTest do
  use ExUnit.Case
  import IRType

  @string <<0xA6, 0x73, 0x74, 0x72, 0x69, 0x6E, 0x67>>
  @quot_string <<0xA7, 0x73, 0x74, 0x72, 0x22, 0x69, 0x6E, 0x67>>
  @contr_string <<0xA4, 34, 0x00, 97, 34>>
  @float <<0xCB, 0x40, 0x59, 0x00, 0xA3, 0xD7, 0x0A, 0x3D, 0x71>>
  @map <<0x81, 0xA1, 0x61, 0x01>>
  @array <<0x92, 0x01, 0xC3>>
  @one_byte_int <<0xCC, 0xFF>>
  @two_byte_int <<0xD1, 0xFF, 0x00>>
  @four_byte_int <<0xD2, 0xFF, 0xFF, 0x00, 0x00>>
  @eight_byte_int <<0xD3, 0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00>>

  ### TESTING STRINGS ###

  test "valid string to json" do
    assert to_json("string") == "\"string\""
  end

  test "valid string to msgpack" do
    assert to_msgpack("string") == @string
  end

  test "string with unescaped quotation mark in it to json" do
    assert {:error, "Unescaped quotation mark or control character was found in str\"ing"} ==
             to_json("str\"ing")
  end

  test "string with unescaped quotation mark in it to msgpack" do
    assert to_msgpack("str\"ing") == @quot_string
  end

  test "string with unescaped control character in it to json" do
    assert {:error, "Unescaped quotation mark or control character was found in #{@contr_string}"} ==
             to_json(@contr_string)
  end

  test "string with unescaped control character in it to msgpack" do
    assert @contr_string = to_msgpack(<<34, 0x00, 97, 34>>)
  end

  test "empty string to json" do
    assert to_json("") == "\"\""
  end

  test "empty stirng to msgpack" do
    assert to_msgpack("") == <<0xA0>>
  end

  ### TESTING ATOMS ###

  test "true to json" do
    assert to_json(true) == "true"
  end

  test "true to msgpack" do
    assert to_msgpack(true) == <<0xC3>>
  end

  test "false to json" do
    assert to_json(false) == "false"
  end

  test "false to msgpack" do
    assert to_msgpack(false) == <<0xC2>>
  end

  test "nil to json" do
    assert to_json(nil) == "null"
  end

  test "nil to msgpack" do
    assert to_msgpack(nil) == <<0xC0>>
  end

  test "unknown atom to json" do
    assert {:error, _} = to_json(:atom)
  end

  test "unknown atom to msgpack" do
    assert {:error, _} = to_msgpack(:atom)
  end

  ### TESTING INTEGER ###

  test "integer to json" do
    assert to_json(123_456) == "123456"
  end

  test "integer to msgpack" do
    assert to_msgpack(12345) == <<0xCD, 0x30, 0x39>>
  end

  test "too big integer to msgpack" do
    assert {:error, _} = to_msgpack(0x1000000000000000)
  end

  test "too small integer to msgpack" do
    assert {:error, _} = to_msgpack(-0x1000000000000000)
  end

  test "5-bit negative integer to msgpack" do
    assert to_msgpack(-31) == <<0xE1>>
  end

  test "7-bit integer to msgpack" do
    assert to_msgpack(127) == <<0x7F>>
  end

  test "1 byte integer to msgpack" do
    assert to_msgpack(255) == @one_byte_int
  end

  test "2 byte integer to msgpack" do
    assert to_msgpack(-256) == @two_byte_int
  end

  test "4 byte integer to msgpack" do
    assert to_msgpack(-0x10000) == @four_byte_int
  end

  test "8 byte integer to msgpack" do
    assert to_msgpack(-0x100000000) == @eight_byte_int
  end

  test "zero to msgpack" do
    assert to_msgpack(0) == <<0x00>>
  end

  ### TESTING FLOAT ###

  test "float without exponent part to json" do
    assert to_json(12.345) == "12.345"
  end

  test "float with exponent part to json" do
    assert to_json(1.23e4) == "1.23e4"
  end

  test "float without exponent part to msgpack" do
    assert to_msgpack(100.01) == @float
  end

  test "float with exponent part to msgpack" do
    assert to_msgpack(1.0001e2) == @float
  end

  ### TESTING ARRAY ###

  test "empty list to json" do
    assert to_json([]) == "[]"
  end

  test "valid list to json" do
    assert to_json([1, true, 1.1]) == "[1, true, 1.1]"
  end

  test "empty list to msgpack" do
    assert to_msgpack([]) == <<0x90>>
  end

  test "valid array to msgpack" do
    assert to_msgpack([1, true]) == @array
  end

  ### TESTING OBJECT ###

  test "empty map to json" do
    assert to_json(%{}) == "{}"
  end

  test "valid map to json" do
    assert to_json(%{"a" => 1}) == "{\"a\": 1}"
  end

  test "empty map to msgpack" do
    assert to_msgpack(%{}) == <<0x80>>
  end

  test "valid map to msgpack" do
    assert to_msgpack(%{"a" => 1}) == @map
  end
end
