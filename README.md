# JsonMsgpackParser

A JSON - MessagePack parser using native elixir data types as intermediate type representation. Although MessagePack is JSON-compatible, the parser takes into consideration basic differences between the two formats, e.g.:

- integer numbers larger than 2^64-1 or smaller than -2^64-1 while being supported by JSON standard cannot be presented in MsgPack format;
- real numbers in JSON are specified in deciaml scientific notation and can have arbitrary precision, while MsgPack real numbers are in IEEE 754 standard;
- MessagePack supports binary data, JSON does not;
Due to said differences and for reasons of simplicity this implementation does not support: encodings other than UTF-8, UTF-16 surrogate pairs in JSON strings, bin 8/16/32, ext 8/16/32, float 32 and fixext 1/2/4/8/16 MessagePack formats.

## Type mappings

 JSON   | MsgPack | Elixir 
------------------------------
string  | String  | BitString
number  | Integer | Integer
number  | Float   | Float
literal | Boolean | Atom
literal | Nil     | Atom
object  | Map     | Map
array   | Array   | List
------------------------------
## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `json_msgpack_parser` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:json_msgpack_parser, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/json_msgpack_parser](https://hexdocs.pm/json_msgpack_parser).

