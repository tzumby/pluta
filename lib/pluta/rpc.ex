defmodule Pluta.RPC do
  def vote_request(%{term: _term, candidate_id: _candidate_id} = message) do
    Node.list()
    |> Enum.each(fn node ->
      :rpc.call(node, GenServer, :cast, [Pluta.Node, {:vote_request, message}])
    end)
  end

  def heartbeat(%{term: _term, leader_id: _leader_id} = message) do
    Node.list()
    |> Enum.each(fn node ->
      :rpc.call(node, GenServer, :cast, [Pluta.Node, {:heartbeat, message}])
    end)
  end

  def vote(%{term: _term, candidate_id: candidate_id} = message) do
    :rpc.call(candidate_id, GenServer, :cast, [Pluta.Node, {:vote, message}])
  end
end
