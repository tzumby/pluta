defmodule Pluta.Node do
  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_state) do
    state = %{
      type: "Follower",
      term: 0,
      election_timeout: random_timeout(),
      heartbeat_timeout: random_timeout(),
      votes: [],
      voted: false,
      heartbeat: true,
      leader: nil
    }

    IO.inspect(
      "Initializing with heartbeat: #{state.heartbeat_timeout}, election: #{
        state.election_timeout
      }"
    )

    loop_term(state)

    {:ok, state}
  end

  def handle_info(:term, %{heartbeat: true} = state) do
    IO.inspect("Term : #{inspect(state)}")
    :timer.sleep(state.heartbeat_timeout)
    loop_term(state)

    {:noreply, state}
  end

  def handle_info(:term, %{heartbeat: false, election_timeout: election_timeout} = state) do
    Process.send_after(self(), :election, election_timeout)

    {:noreply, state}
  end

  def handle_info(:election, %{leader: nil} = state) do
    IO.inspect("[#{Node.self()}]: starting new election term. state: #{inspect(state)}")

    state =
      state
      |> update_in([:term], &(&1 + 1))
      |> Map.put(:type, "Candidate")
      |> Map.put(:election_timeout, random_timeout())

    Node.list()
    |> Enum.each(fn node ->
      IO.inspect(node, label: "sending vote request to")
      :rpc.call(node, GenServer, :cast, [__MODULE__, {:vote_request, Node.self()}])
    end)

    :timer.sleep(state.election_timeout)
    loop_term(state)

    {:noreply, state}
  end

  def handle_info(:election, state) do
    Process.send(self(), :term, [])
    {:noreply, state}
  end

  def handle_cast({:vote_request, requesting_node}, %{leader: nil} = state) do
    state =
      update_in(state, [:term], &(&1 + 1))
      |> Map.put(:voted, true)

    :rpc.call(requesting_node, GenServer, :cast, [__MODULE__, {:vote, Node.self()}])

    {:noreply, state}
  end

  def handle_cast({:vote_request, _requesting_node}, state), do: {:noreply, state}

  def handle_cast({:vote, vote_from}, %{leader: nil} = state) do
    votes = state.votes ++ [vote_from]

    state = Map.put(state, :votes, votes)

    state =
      if length(state.votes) >= 3 do
        IO.inspect("Found leader: #{Node.self()}")

        state =
          state
          |> Map.put(:type, "Leader")
          |> Map.put(:leader, Node.self())
          |> Map.put(:votes, [])

        Node.list()
        |> Enum.each(fn node ->
          :rpc.call(node, GenServer, :cast, [__MODULE__, {:elect_leader, state.leader}])
        end)

        state
      else
        state
      end

    {:noreply, state}
  end

  def handle_cast({:vote, vote_from}, state) do
    {:noreply, state}
  end

  def handle_cast({:elect_leader, leader}, state) do
    state =
      state
      |> Map.put(:leader, leader)
      |> Map.put(:type, "Follower")

    {:noreply, state}
  end

  defp cluster_size do
    length(Node.list())
  end

  defp loop_term(%{heartbeat_timeout: heartbeat_timeout, leader: leader})
       when not is_nil(leader) do
    Process.send_after(self(), :term, heartbeat_timeout)
  end

  defp loop_term(
         %{
           election_timeout: election_timeout,
           heartbeat_timeout: heartbeat_timeout,
           leader: nil,
           votes: votes
         } = state
       )
       when is_list(votes) and length(votes) > 0 do
    if length(votes) >= ceil(cluster_size() / 2) do
      state
      |> Map.put(:type, "Leader")
      |> Map.put(:leader, Node.self())

      Process.send_after(self(), :term, heartbeat_timeout)
    else
      Process.send_after(self(), :election, election_timeout)
    end
  end

  defp loop_term(%{election_timeout: election_timeout, leader: nil}) do
    IO.inspect("[#{Node.self()}]: We have no leader, starting election in : #{election_timeout}")
    Process.send_after(self(), :election, election_timeout)
  end

  defp random_timeout do
    :rand.uniform(300_00)
  end
end
