defmodule Pluta.Node do
  use GenServer

  alias Pluta.RPC

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    state = %{
      current_term: 0,
      voted_for: nil,
      election_timeout: random_timeout(),
      heartbeat: false,
      leader_id: nil,
      candidate_id: nil,
      vote_count: 0,
      me: Node.self()
    }

    {:ok, state, {:continue, :election}}
  end

  def handle_continue(:election, %{election_timeout: election_timeout} = state) do
    Process.send_after(self(), :term, election_timeout)

    {:noreply, state}
  end

  def handle_info(:term, %{leader_id: nil, candidate_id: nil, heartbeat: false} = state) do
    IO.puts("Starting election")

    state =
      state
      |> update_in([:current_term], &(&1 + 1))
      |> Map.put(:election_timeout, random_timeout())
      |> Map.put(:voted_for, Node.self())
      |> Map.put(:candidate_id, Node.self())

    RPC.vote_request(%{
      term: state.current_term,
      candidate_id: state.candidate_id
    })

    Process.send_after(self(), :term, state.election_timeout)

    {:noreply, state}
  end

  def handle_info(
        :term,
        %{
          me: me,
          leader_id: leader_id,
          election_timeout: election_timeout,
          current_term: current_term,
          candidate_id: candidate_id
        } = state
      )
      when not is_nil(leader_id) and me == leader_id do
    RPC.heartbeat(%{
      term: current_term,
      leader_id: Node.self(),
      candidate_id: candidate_id
    })

    Process.send_after(self(), :term, election_timeout)

    {:noreply, state}
  end

  def handle_info(
        :term,
        %{heartbeat: true, leader_id: leader_id, election_timeout: election_timeout} = state
      )
      when not is_nil(leader_id) do
    IO.puts("Normal term")

    state = reset_heartbeat(state)

    Process.send_after(self(), :term, election_timeout)

    {:noreply, state}
  end

  def handle_info(
        :term,
        %{candidate_id: candidate_id, election_timeout: election_timeout, heartbeat: false} =
          state
      )
      when not is_nil(candidate_id) do
    IO.puts("Election timeout.")

    state =
      reset_heartbeat(state)
      |> Map.put(:candidate_id, nil)
      |> Map.put(:leader_id, nil)

    Process.send_after(self(), :term, election_timeout)

    {:noreply, state}
  end

  def handle_info(
        :term,
        %{candidate_id: nil, heartbeat: false, election_timeout: election_timeout} = state
      ) do
    IO.puts("Leader timeout")

    state =
      reset_heartbeat(state)
      |> Map.put(:leader_id, nil)

    Process.send_after(self(), :term, election_timeout)

    {:noreply, state}
  end

  def handle_cast({:vote_request, %{term: term, candidate_id: candidate_id}}, state) do
    state =
      state
      |> Map.put(:candidate_id, candidate_id)
      |> Map.put(:voted_for, candidate_id)
      |> Map.put(:current_term, term)

    RPC.vote(%{candidate_id: state.candidate_id, term: state.current_term})

    {:noreply, state}
  end

  def handle_cast(
        {:vote, %{term: term}},
        %{current_term: current_term, leader_id: nil} = state
      )
      when term >= current_term do
    state =
      state
      |> update_in([:vote_count], &(&1 + 1))

    state =
      if state.vote_count >= 3 do
        state =
          state
          |> Map.put(:leader_id, Node.self())
          |> Map.put(:candidate_id, nil)

        RPC.heartbeat(%{
          term: current_term,
          leader_id: state.leader_id,
          candidate_id: state.candidate_id
        })

        state
      else
        state
      end

    {:noreply, state}
  end

  def handle_cast({:vote, _message}, state), do: {:noreply, state}

  def handle_cast(
        {:heartbeat, %{leader_id: leader_id, term: term, candidate_id: candidate_id}} = message,
        state
      ) do
    IO.inspect("Receiving heartbeat")

    state =
      state
      |> Map.put(:leader_id, leader_id)
      |> Map.put(:current_term, term)
      |> Map.put(:heartbeat, true)
      |> Map.put(:candidate_id, candidate_id)

    {:noreply, state}
  end

  def handle_cast({:heartbeat, _message}, state), do: {:noreply, state}

  defp random_timeout do
    :rand.uniform(3000_0)
  end

  defp reset_heartbeat(state) do
    Map.put(state, :heartbeat, false)
  end
end
