defmodule MsgPack do
  @moduledoc """
  A module for transforming MessagePack expressions into corresponding JSON expressions.
  The supported MessagePack format is as described in http://github.com/msgpack/msgpack/blob/master/spec.md.
  This implementation does not support binary, extension and timestamp types as well as float32 format.
  """

  @typedoc """
  This implementation uses intermediate type representation - elixir data types. MessagePack types - elixir type mappings:
  msgpack | elixir
  ----------------
  String  | String.t
  Integer | Integer
  Float   | Float
  Boolean | Atom
  Nil     | Atom
  Map     | Map
  Array   | Array
  """

  @type valid :: String.t() | number | map | list | boolean | nil

  @doc """
  Transforms a valid MessagePack expression into a corresponding JSON expression. Accepts one argument - the MessagePack expression. Returns `{:ok, JSON expression}` in case of success or `{:error, reason}` otherwise.

  ## Examples
      MsgPack.to_json(<<0xc0>>)
      #=> "null"

      MsgPack.to_json(<<0xc1>>)
      #=> (RuntimeError) First byte <<0xc1>> is never used

  """

  # @spec to_json(String.t()) :: {:ok, binary} | {:error, String.t()}
  def to_json(expr) do
    case to_elixir(expr) |> IRType.to_json() do
      {:error, _reason} = err -> err
      parsed -> {:ok, parsed}
    end
  end

  @doc """
    Same as `to_json/1`, but raises an exception in case of an error, returns the corresponding JSON expression otherwise.
  """

  # @spec to_json!(String.t()) :: binary | no_return
  def to_json!(expr) do
    case to_json(expr) do
      {:error, reason} -> raise reason
      {:ok, result} -> result
    end
  end

  @spec to_elixir(binary()) :: valid | {:error, String.t()}
  def to_elixir(expr) do
    case to_elixir_helper(expr) do
      {:error, _reason} = err -> err
      {res, ""} -> res
      _ -> {:error, "Invalid MsgPack expression."}
    end
  end

  defp to_elixir_helper(<<h, _::binary>> = expr) when h <= 0x7F, do: int(expr)
  defp to_elixir_helper(<<h, _::binary>> = expr) when h <= 0x8F, do: map(expr)
  defp to_elixir_helper(<<h, _::binary>> = expr) when h <= 0x9F, do: array(expr)
  defp to_elixir_helper(<<h, _::binary>> = expr) when h <= 0xBF, do: str(expr)
  defp to_elixir_helper(<<h, rest::binary>>) when h == 0xC0, do: {nil, rest}

  defp to_elixir_helper(<<h, _::binary>>) when h == 0xC1,
    do: {:error, "Invalid MsgPack syntax - first byte 0xc1 of a format is never used"}

  defp to_elixir_helper(<<h, rest::binary>>) when h == 0xC2, do: {false, rest}
  defp to_elixir_helper(<<h, rest::binary>>) when h == 0xC3, do: {true, rest}

  defp to_elixir_helper(<<h, _::binary>>) when h <= 0xC6,
    do: {:error, "MsgPack type bin is unsupported."}

  defp to_elixir_helper(<<h, _::binary>>) when h <= 0xC9,
    do: {:error, "MsgPack type ext is unsupported."}

  defp to_elixir_helper(<<h, _::binary>>) when h == 0xCA,
    do: {:error, "MsgPack type float 32 is unsupported."}

  defp to_elixir_helper(<<h, _::binary>> = expr) when h == 0xCB, do: float(expr)

  defp to_elixir_helper(<<h, _::binary>> = expr) when h <= 0xCF, do: uint(expr)

  defp to_elixir_helper(<<h, _::binary>> = expr) when h <= 0xD3, do: int(expr)

  defp to_elixir_helper(<<h, _::binary>>) when h <= 0xD8,
    do: {:error, "MsgPack type fixext is unsupported."}

  defp to_elixir_helper(<<h, _::binary>> = expr) when h <= 0xDB, do: str(expr)
  defp to_elixir_helper(<<h, _::binary>> = expr) when h <= 0xDD, do: array(expr)
  defp to_elixir_helper(<<h, _::binary>> = expr) when h <= 0xDF, do: map(expr)
  defp to_elixir_helper(<<_h, _::binary>> = expr), do: int(expr)

  defp int(<<0::1, int::7, rest::binary>>), do: {int, rest}
  defp int(<<7::3, int::5, rest::binary>>), do: {int * -1, rest}
  defp int(<<0xD0, 1::1, int::7, rest::binary>>), do: {int * -1, rest}
  defp int(<<0xD0, 0::1, int::7, rest::binary>>), do: {int, rest}
  defp int(<<0xD1, 1::1, int::15, rest::binary>>), do: {int * -1, rest}
  defp int(<<0xD1, 0::1, int::15, rest::binary>>), do: {int, rest}
  defp int(<<0xD2, 1::1, int::31, rest::binary>>), do: {int * -1, rest}
  defp int(<<0xD2, 0::1, int::31, rest::binary>>), do: {int, rest}
  defp int(<<0xD3, 1::1, int::63, rest::binary>>), do: {int * -1, rest}
  defp int(<<0xD3, 0::1, int::63, rest::binary>>), do: {int, rest}

  defp uint(<<0xCC, uint::8, rest::binary>>), do: {uint, rest}
  defp uint(<<0xCD, uint::16, rest::binary>>), do: {uint, rest}
  defp uint(<<0xCE, uint::32, rest::binary>>), do: {uint, rest}
  defp uint(<<0xCF, uint::64, rest::binary>>), do: {uint, rest}

  defp float(<<0xCB, float::float, rest::binary>>), do: {float, rest}

  defp str(<<5::3, size::5, str::bytes-size(size), rest::binary>>), do: {str, rest}
  defp str(<<0xD9, size::8, str::bytes-size(size), rest::binary>>), do: {str, rest}
  defp str(<<0xDA, size::16, str::bytes-size(size), rest::binary>>), do: {str, rest}
  defp str(<<0xDB, size::32, str::bytes-size(size), rest::binary>>), do: {str, rest}

  defp array(<<9::4, size::4, elements::binary>>), do: arr_el(elements, size, [])
  defp array(<<0xDC, size::16, elements::binary>>), do: arr_el(elements, size, [])
  defp array(<<0xDD, size::32, elements::binary>>), do: arr_el(elements, size, [])

  defp arr_el(rest, 0, res), do: {Enum.reverse(res), rest}

  defp arr_el(elements, size, res) do
    {unpacked, rest} = to_elixir_helper(elements)
    arr_el(rest, size - 1, [unpacked | res])
  end

  def map(<<8::4, size::4, elements::binary>>), do: map_el(elements, size, %{})
  def map(<<0xDE, size::16, elements::binary>>), do: map_el(elements, size, %{})
  def map(<<0xDF, size::32, elements::binary>>), do: map_el(elements, size, %{})

  defp map_el(rest, 0, res), do: {res, rest}

  defp map_el(elements, size, res) do
    {name, rest} = str(elements)
    {val, rr} = to_elixir_helper(rest)

    case Map.get(res, name) do
      nil -> map_el(rr, size - 1, Map.put(res, name, val))
      _ -> {:error, "Duplicated keys #{name} in map."}
    end
  end
end
