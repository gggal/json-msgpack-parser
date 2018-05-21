defmodule JSON_Test do
  use ExUnit.Case
  import JSON

  test "term with redundant spaces" do
    assert to_msgpack!(" \"abc\"  ") |> MsgPack.to_json!() == "\"abc\""
  end

  test "string with unescaped quotation mark" do
    assert {:error, "String #{"\"\"\""} contains unescaped quotation mark or control character."} ==
             to_msgpack("\"\"\"")
  end

  test "string with escaped quotation mark" do
    assert to_msgpack!("\"\\\"\"") |> MsgPack.to_json!() == "\"\\\"\""
  end

  test "valid string" do
    assert to_msgpack!("\"abc\"") |> MsgPack.to_json!() == "\"abc\""
  end

  test "integer with leading plus" do
    assert {:error, "Number cannot start with +."} == to_msgpack("+1")
  end

  test "integer with leading zero" do
    assert {:error, "Number cannot start with zero."} == to_msgpack("01")
  end

  test "float with arbitrary precision" do
    assert to_msgpack!("12.3456") |> MsgPack.to_json!() == "12.3456"
  end

  test "map with invalid key value" do
    assert {:error, "Invalid key before 1:2."} == to_msgpack("{1:2}")
  end

  test "map with invalid syntax" do
    assert {:error, "Invalid key value after "} == to_msgpack("{\"a\":1,}")
  end

  test "map with duplicate keys" do
    assert {:error, "Duplicate key in map."} == to_msgpack("{\"a\":1, \"a\":2}")
  end

  test "valid map" do
    assert to_msgpack!("{\"a\":1, \"b\":2}") |> MsgPack.to_json!() == "{\"a\": 1,\"b\": 2}"
  end

  test "empty map" do
    assert to_msgpack!("{}") |> MsgPack.to_json!() == "{}"
  end

  test "empty array" do
    assert to_msgpack!("[]") |> MsgPack.to_json!() == "[]"
  end

  test "valid array" do
    assert to_msgpack!("[true, 1.1, 1]") |> MsgPack.to_json!() == "[true, 1.1, 1]"
  end

  test "nested map" do
    assert to_msgpack!("[true, {}, {\"a\":1}]") |> MsgPack.to_json! == "[true, {}, {\"a\": 1}]"
  end

  test "nested array" do
    assert to_msgpack!("[{\"a\":[1,2,{}]}]") |> MsgPack.to_json! == "[{\"a\": [1, 2, {}]}]"
  end
end
