defprotocol IRType do
  @moduledoc """
    Protocol implemeted by all intermediate types supported by the parser.
  """

  @doc "Converts elixir type to its valid json representation"
  def to_json(expr)

  @doc "Converts elixir type to its valid msgpack representation"
  def to_msgpack(expr)
end

defimpl IRType, for: BitString do
  def to_json(str) do
    case valid_string?(str, :unescaped) do
      true ->
        "\"#{str}\""

      false ->
        {:error, "Unescaped quotation mark or control character was found in #{str}"}
    end
  end

  def to_msgpack(str) do
    case byte_size(str) do
      n when n < 32 ->
        <<5::3, n::5, str::binary>>

      n when n < 256 ->
        <<0xD9, n, str::binary>>

      n when n < 0x10000 ->
        <<0xDA, n::16, str::binary>>

      n when n < 0x100000000 ->
        <<0xDB, n::32, str::binary>>

      _ ->
        {:error, "String #{str} is too large."}
    end
  end

  defp valid_string?(<<>>, _), do: true
  defp valid_string?(<<"\"", _::binary>>, :unescaped), do: false
  defp valid_string?(<<a, _::binary>>, :unescaped) when a <= 0x1F, do: false
  defp valid_string?(<<"\\", rest::binary>>, :unescaped), do: valid_string?(rest, :escaped)
  defp valid_string?(<<_, rest::binary>>, _), do: valid_string?(rest, :unescaped)
end

defimpl IRType, for: Atom do
  def to_json(true), do: "true"
  def to_json(false), do: "false"
  def to_json(nil), do: "null"
  def to_json(smth), do: {:error, "Unknown expression #{smth} cannot be parsed to json"}

  def to_msgpack(true), do: <<0xC3>>
  def to_msgpack(false), do: <<0xC2>>
  def to_msgpack(nil), do: <<0xC0>>
  def to_msgpack(smth), do: {:error, "Unknown expression #{smth} cannot be parsed to msgpack"}
end

defimpl IRType, for: Integer do
  def to_json(int), do: Integer.to_string(int)

  def to_msgpack(int) when int < 128 and int >= 0, do: <<0::1, int::7>>
  def to_msgpack(int) when int > -32 and int < 0, do: <<7::3, int::5>>
  def to_msgpack(int) when int > -128 and int < 0, do: <<0xD0, 1::1, int::7>>
  def to_msgpack(int) when int > -0x8000 and int < 0, do: <<0xD1, 1::1, int::15>>
  def to_msgpack(int) when int > -0x80000000 and int < 0, do: <<0xD2, 1::1, int::31>>
  def to_msgpack(int) when int > -0x80000000000 and int < 0, do: <<0xD3, 1::1, int::63>>
  def to_msgpack(int) when int < 256 and int > 0, do: <<0xCC, int>>
  def to_msgpack(int) when int < 0x10000 and int > 0, do: <<0xCD, int::16>>
  def to_msgpack(int) when int < 0x100000000 and int > 0, do: <<0xCE, int::32>>
  def to_msgpack(int) when int < 0x100000000000 and int > 0, do: <<0xCF, int::64>>

  def to_msgpack(int),
    do: {:error, "Int #{int} is too big or too small to be represented in MsgPack format."}
end

defimpl IRType, for: Float do
  def to_json(float), do: Float.to_string(float)

  def to_msgpack(float), do: <<0xCB, float::float>>
end

defimpl IRType, for: Map do
  def to_json(map) do
    "{#{
      map
      |> Enum.map(fn {key, val} -> "#{IRType.to_json(key)}: #{IRType.to_json(val)}" end)
      |> Enum.join(",")
    }}"
  end

  def to_msgpack(map) do
    packed =
      map
      |> Map.to_list()
      |> Enum.map(fn {key, val} -> IRType.to_msgpack(key) <> IRType.to_msgpack(val) end)
      |> Enum.join()

    case Enum.count(map) do
      n when n < 16 -> <<8::4, n::4, packed::binary>>
      n when n < 0x100000 -> <<0xDE, n::16, packed::binary>>
      n when n < 0x100000000 -> <<0xDF, n::32, packed::binary>>
    end
  end
end

defimpl IRType, for: List do
  def to_json(arr) do
    "[#{
      arr
      |> Enum.map(&IRType.to_json/1)
      |> Enum.join(", ")
    }]"
  end

  def to_msgpack(arr) do
    packed =
      arr
      |> Enum.map(&IRType.to_msgpack/1)
      |> Enum.join()

    case(Enum.count(arr)) do
      n when n < 16 -> <<9::4, n::4, packed::binary>>
      n when n < 0x100000 -> <<0xDC, n::16, packed::binary>>
      n when n < 0x100000000 -> <<0xDD, n::32, packed::binary>>
    end
  end
end

defimpl IRType, for: Tuple do
  def to_json({:error, _} = expr), do: expr
  def to_msgpack({:error, _} = expr), do: expr
end
