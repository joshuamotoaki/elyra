defmodule Backend.Matches.MatchCleanup do
  @moduledoc """
  Periodic cleanup of stale matches.
  Runs every 5 minutes to clean up:
  - Waiting matches older than 30 minutes
  - Playing matches older than 1 hour (stuck games)
  """
  use GenServer
  require Logger

  alias Backend.Matches

  @cleanup_interval :timer.minutes(5)

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    schedule_cleanup()
    {:ok, state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    case Matches.cleanup_stale_matches() do
      {:ok, 0} ->
        :ok

      {:ok, count} ->
        Logger.info("Cleaned up #{count} stale match(es)")
    end

    schedule_cleanup()
    {:noreply, state}
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval)
  end
end
