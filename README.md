# Pluta

This implementation is for learning purposes and not complete. `pluta` is Romanian for raft.

It uses `libcluster` in Gossip mode. Nodes will find each other as long as you name them:

```
iex --sname a -S mix
```

And in a different terminal / tab:

```
iex --sname b -S mix
```

etc..


## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `pluta` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:pluta, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/pluta](https://hexdocs.pm/pluta).

