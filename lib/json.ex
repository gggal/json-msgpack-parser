defmodule JSON do
  @moduledoc """
    A module for transforming JSON expressions into corresponding MsgPack expressions.
  Assuming that the expression is a valid one according to JSON standard htttps://tools.ietf.org/html/rfc7159 , the parser takes in consideration basic differences between the two formats, e.g.
  ~ integer numbers larger than 2^64-1 or smaller than -2^64-1 while being supported by JSON standard cannot be presented in MsgPack format;
  ~ real numbers in JSON are specified in deciamlscientific notation an can have arbitrary precision, while MsgPack real numbers are in IEEE 754 standart
  Due to the latter reasons or for reasons of simplycity this implementation does not support:

  The supported JSON expression format is as described in http://tools.ietf.org/html/rfc7159.
  This implementation does not support BOM or encoding other than UTF-8.
  """

  @typedoc """
  This implementation uses intermedate type representation - elixir data types. JSON - elixir type mappings:
    json  | elixir
  --------------
  string  | String.t
  number  | Integer, Float
  literal | Atom
  object  | Map
  array   | List

  """
  @type valid :: String.t() | number | map | list | boolean | nil

  @doc """
  Transforms a valid JSON expression into a corresponding MessagePack expression. Accepts one argument - the JSON expression. Returns `{:ok, MsgPack expression}` in case of success or `{:error, reason}` otherwise.

  ## Examples
      JSON.to_msgpack("123")
      #=> <<0x7b>>

      JSON.to_msgpack("1,23")
      #=> (RuntimeError) Invalid number syntax in 1,23

  """

  @spec to_msgpack(String.t()) :: {:ok, binary} | {:error, binary}
  def to_msgpack(expr) do
    res =
      expr
      |> String.trim()
      |> to_elixir
      |> IRType.to_msgpack()

    case res do
      {:error, _reason} = err -> err
      result -> {:ok, result}
    end
  end

  @doc """
  Same as `to_msgpack/1`, but raises an exception in case of an error, returns the corresponding MessagePack expression otherwise.
  """

  @spec to_msgpack!(String.t()) :: String.t() | no_return
  def to_msgpack!(expr) do
    case to_msgpack(expr) do
      {:ok, result} -> result
      {:error, reason} -> raise reason
    end
  end

  defp to_elixir(<<"\"", _::binary>> = str) do
    sliced = String.slice(str, 1..-2)

    case valid_string?(sliced, :unescaped) do
      true ->
        sliced

      false ->
        {:error, "String #{str} contains unescaped quotation mark or control character."}
    end
  end

  defp to_elixir(<<"[]">>), do: []
  defp to_elixir(<<"[", _::binary>> = arr), do: list_helper(String.slice(arr, 1..-2), "", [], "")

  defp to_elixir(<<"{}">>), do: %{}

  defp to_elixir(<<"{", _::binary>> = map),
    do: map_helper(String.slice(map, 1..-2), "", [], "", true)

  defp to_elixir(~s(true)), do: true
  defp to_elixir(~s(false)), do: false
  defp to_elixir(~s(null)), do: nil

  defp to_elixir(<<"0", _::binary>>), do: {:error, "Number cannot start with zero."}

  defp to_elixir(<<"+", _::binary>>), do: {:error, "Number cannot start with +."}

  defp to_elixir(num) do
    case String.contains?(num, ["e", "E", "."]) do
      true -> String.to_float(num)
      false -> String.to_integer(num)
    end
  end

  defp valid_string?(<<>>, _), do: true
  defp valid_string?(<<"\"", _::binary>>, :unescaped), do: false
  defp valid_string?(<<a, _::binary>>, :unescaped) when a <= 0x1F, do: false
  defp valid_string?(<<"\\", rest::binary>>, :unescaped), do: valid_string?(rest, :escaped)
  defp valid_string?(<<_, rest::binary>>, _), do: valid_string?(rest, :unescaped)

  defp list_helper(<<>>, <<>>, res, curr) do
    [String.reverse(curr) | res]
    |> Enum.map(&String.trim/1)
    |> Enum.reverse()
    |> Enum.map(&to_elixir/1)
  end

  defp list_helper(<<>>, _, _, _), do: {:error, "Invalid list syntax"}

  defp list_helper(<<"\\\"", rest::binary>>, stack, res, curr),
    do: list_helper(rest, stack, res, "\"\\" <> curr)

  defp list_helper(<<"]", rest::binary>>, <<"[", br_st::binary>>, res, curr),
    do: list_helper(rest, br_st, res, "]" <> curr)

  defp list_helper(<<"}", rest::binary>>, <<"{", br_st::binary>>, res, curr),
    do: list_helper(rest, br_st, res, "}" <> curr)

  defp list_helper(<<"\"", rest::binary>>, <<"\"", br_st::binary>>, res, curr),
    do: list_helper(rest, br_st, res, "\"" <> curr)

  defp list_helper(<<a, rest::binary>>, <<"\"", _::binary>> = stack, res, curr) when a in '[]{}',
    do: list_helper(rest, stack, res, <<a, curr::binary>>)

  defp list_helper(<<a, rest::binary>>, stack, res, curr) when a in '"[]{}',
    do: list_helper(rest, <<a, stack::binary>>, res, <<a, curr::binary>>)

  defp list_helper(<<",", rest::binary>>, <<>>, res, curr),
    do: list_helper(rest, <<>>, [String.reverse(curr) | res], "")

  defp list_helper(<<a, rest::binary>>, stack, res, curr),
    do: list_helper(rest, stack, res, <<a, curr::binary>>)

  defp map_helper(<<>>, "", res, curr, false) do
    map =
      [String.reverse(curr) | res]
      |> Enum.map(&String.trim/1)
      |> Enum.reverse()
      |> Enum.chunk_every(2)
      |> Enum.map(fn [key, val] -> {to_elixir(key), to_elixir(val)} end)
      |> Map.new()

    if Enum.count(map) != (Enum.count(res) + 1) / 2 do
      {:error, "Duplicate key in map."}
    else
      map
    end
  end

  defp map_helper(<<"\"", rest::binary>>, "", res, curr, true),
    do: map_helper(rest, "\"", res, "\"" <> curr, true)

  defp map_helper(<<"\\\"", rest::binary>>, "\"", res, curr, true),
    do: map_helper(rest, "", res, "\"\\" <> curr, true)

  defp map_helper(<<"\"", rest::binary>>, "\"", res, curr, true) do
    <<a, other::binary>> = String.trim(rest)

    case <<a>> do
      ":" -> map_helper(other, "", [String.reverse("\"" <> curr) | res], "", false)
      _ -> {:error, "Not a valid keyword after #{String.reverse(curr)}"}
    end
  end

  defp map_helper(<<a, rest::binary>>, "\"", res, curr, true),
    do: map_helper(rest, "\"", res, <<a, curr::binary>>, true)

  defp map_helper(expr, "", _, _, true), do: {:error, "Invalid key before #{expr}."}

  defp map_helper(<<"\\\"", rest::binary>>, stack, res, curr, false),
    do: map_helper(rest, stack, res, "\"\\" <> curr, false)

  defp map_helper(<<"]", rest::binary>>, <<"[", br_st::binary>>, res, curr, false),
    do: map_helper(rest, br_st, res, "]" <> curr, false)

  defp map_helper(<<"}", rest::binary>>, <<"{", br_st::binary>>, res, curr, false),
    do: map_helper(rest, br_st, res, "}" <> curr, false)

  defp map_helper(<<"\"", rest::binary>>, <<"\"", br_st::binary>>, res, curr, false),
    do: map_helper(rest, br_st, res, "\"" <> curr, false)

  defp map_helper(<<a, rest::binary>>, <<"\"", _>> = stack, res, curr, false) when a in '[]{}',
    do: map_helper(rest, stack, res, <<a, curr::binary>>, false)

  defp map_helper(<<a, rest::binary>>, stack, res, curr, false) when a in '"[]{}',
    do: map_helper(rest, <<a, stack::binary>>, res, <<a, curr::binary>>, false)

  defp map_helper(<<",", rest::binary>>, "", res, curr, false) do
    r = String.trim_leading(rest)

    case String.first(r) do
      "\"" -> map_helper(String.slice(r, 1..-1), "\"", [String.reverse(curr) | res], "\"", true)
      _ -> {:error, "Invalid key value after #{r}"}
    end
  end

  defp map_helper(<<a, rest::binary>>, stack, res, curr, false),
    do: map_helper(rest, stack, res, <<a, curr::binary>>, false)
end
