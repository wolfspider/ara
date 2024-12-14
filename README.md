# ĀRA

Āra (pronounced ˈɛərə) is a webserver ported from the FSharp project based on Mi-TLS. 
The name comes from the latin word for "Altar" due to the code having its basis on many functional
programming idioms and so it pays homage to this.

# Status

Currently, this is a very early implementation and so there are many parts which
have not been hooked up quite yet including the fiber -> process translation.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `ara` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ara, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/ara>.

