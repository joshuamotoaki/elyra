defmodule Backend.Matches.MatchSupervisor do
  @moduledoc """
  Dynamic supervisor for match processes.
  Each active match runs as a separate GenServer under this supervisor.
  """
  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @doc """
  Start a new match server process.
  """
  def start_match(match_id) do
    DynamicSupervisor.start_child(__MODULE__, {Backend.Matches.MatchServer, match_id})
  end

  @doc """
  Stop a match server process.
  """
  def stop_match(match_id) do
    case Registry.lookup(Backend.MatchRegistry, match_id) do
      [{pid, _}] -> DynamicSupervisor.terminate_child(__MODULE__, pid)
      [] -> {:error, :not_found}
    end
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
