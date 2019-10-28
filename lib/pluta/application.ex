defmodule Pluta.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  alias Pluta.Node

  def start(_type, _args) do
    topologies = [
      pluta: [
        strategy: Elixir.Cluster.Strategy.Gossip,
        config: [
          port: 45892,
          if_addr: "0.0.0.0",
          multicast_addr: "230.1.1.251",
          multicast_ttl: 1,
          secret: "somepassword"
        ]
      ]
    ]

    children = [
      {Cluster.Supervisor, [topologies, [name: Pluta.ClusterSupervisor]]},
      {Node, []}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Pluta.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
