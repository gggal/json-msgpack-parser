defmodule MsgPackTest do
  use ExUnit.Case
  import MsgPack

  @map <<0x81, 0xA1, 0x61, 0x01>>
  @invalid_map <<0x82, 0xa1, 0x61, 0x01, 0xa1, 0x61, 0x02>>
  @nested_map <<0x81, 0xa1, 0x61, 0x91, 0x81, 0xa0, 0x01>>
  @arr <<0x93, 0x01, 0xC3, 0xC0>>
  @nested_arr <<0x81, 0xa1, 0x61, 0x91, 0x81, 0xa0, 0x01>>
  @str <<0xA3, 0x73, 0x74, 0x72>>
  @float <<0xCB, 0x40, 0x09, 0x1E, 0xB8, 0x51, 0xEB, 0x85, 0x1F>>
  @ext <<0xC9>>
  @bin <<0xC6>>
  @float32 <<0xCA>>
  @invalid <<0xC0, 0x01>>

  test "valid int" do
    assert to_json!(<<12>>) |> JSON.to_msgpack!() == <<12>>
  end

  test "valid map" do
    assert to_json!(@map) |> JSON.to_msgpack!() == @map
  end

  test "nested map" do
    assert to_json!(@nested_map) |> JSON.to_msgpack!() == @nested_map
  end

  test "map with duplicate keys" do
    assert {:error, "Duplicated keys a in map."} == to_json(@invalid_map)
  end

  test "valid array" do
    assert to_json!(@arr) |> JSON.to_msgpack!() == @arr
  end

  test "nested array" do
    assert to_json!(@nested_arr) |> JSON.to_msgpack!() == @nested_arr
  end

  test "valid string" do
    assert to_json!(@str) |> JSON.to_msgpack!() == @str
  end

  test "null" do
    assert to_json!(<<0xC0>>) |> JSON.to_msgpack!() == <<0xC0>>
  end

  test "unused first byte 0xc1" do
    assert {:error, "Invalid MsgPack syntax - first byte 0xc1 of a format is never used"} ==
             to_json(<<0xC1>>)
  end

  test "true" do
    assert to_json!(<<0xC3>>) |> JSON.to_msgpack!() == <<0xC3>>
  end

  test "false" do
    assert to_json!(<<0xC2>>) |> JSON.to_msgpack!() == <<0xC2>>
  end

  test "valid float" do
    assert to_json!(@float) |> JSON.to_msgpack!() == @float
  end

  test "unsuported type ext" do
    assert {:error, "MsgPack type ext is unsupported."} == to_json(@ext)
  end

  test "unsuported type bin" do
    assert {:error, "MsgPack type bin is unsupported."} == to_json(@bin)
  end

  test "unsuported type float32" do
    assert {:error, "MsgPack type float 32 is unsupported."} == to_json(@float32)
  end

  test "invalid expression" do
    assert {:error, "Invalid MsgPack expression."} == to_json(@invalid)
  end
end
