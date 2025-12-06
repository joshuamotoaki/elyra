defmodule Backend.Matches.MatchServer do
  @moduledoc """
  GenServer that holds live game state for a single match.
  One process per active match.
  """
  use GenServer

  alias Backend.Matches
  alias Phoenix.PubSub

  @tick_interval 1000

  # Player colors for assignment
  @colors ["#EF4444", "#3B82F6", "#22C55E", "#F59E0B"]

  defstruct [
    :match_id,
    :code,
    :host_id,
    :grid_size,
    :duration,
    :time_remaining,
    :status,
    players: %{},
    grid: %{}
  ]

  # Client API

  def start_link(match_id) do
    GenServer.start_link(__MODULE__, match_id, name: via_tuple(match_id))
  end

  def via_tuple(match_id) do
    {:via, Registry, {Backend.MatchRegistry, match_id}}
  end

  @doc """
  Check if a match server is running.
  """
  def exists?(match_id) do
    case Registry.lookup(Backend.MatchRegistry, match_id) do
      [{_pid, _}] -> true
      [] -> false
    end
  end

  @doc """
  Join a match. Returns the current state.
  """
  def join(match_id, user) do
    GenServer.call(via_tuple(match_id), {:join, user})
  end

  @doc """
  Leave a match.
  """
  def leave(match_id, user_id) do
    GenServer.call(via_tuple(match_id), {:leave, user_id})
  end

  @doc """
  Start the game. Only the host can do this.
  """
  def start_game(match_id, user_id) do
    GenServer.call(via_tuple(match_id), {:start_game, user_id})
  end

  @doc """
  Click a cell to claim it.
  """
  def click_cell(match_id, user_id, row, col) do
    GenServer.call(via_tuple(match_id), {:click_cell, user_id, row, col})
  end

  @doc """
  Get the current game state.
  """
  def get_state(match_id) do
    GenServer.call(via_tuple(match_id), :get_state)
  end

  # Server callbacks

  @impl true
  def init(match_id) do
    match = Matches.get_match_with_players(match_id)

    if match do
      grid = initialize_grid(match.grid_size)

      # Build players map from existing match_players
      players =
        match.match_players
        |> Enum.map(fn mp ->
          {mp.user_id,
           %{
             user_id: mp.user_id,
             username: mp.user.username || mp.user.name || "Player",
             picture: mp.user.picture,
             color: mp.color,
             score: 0
           }}
        end)
        |> Map.new()

      state = %__MODULE__{
        match_id: match_id,
        code: match.code,
        host_id: match.host_id,
        grid_size: match.grid_size,
        duration: match.duration_seconds,
        time_remaining: match.duration_seconds,
        status: :waiting,
        players: players,
        grid: grid
      }

      {:ok, state}
    else
      {:stop, :match_not_found}
    end
  end

  @impl true
  def handle_call({:join, user}, _from, state) do
    if Map.has_key?(state.players, user.id) do
      # Already in match, just return state
      {:reply, {:ok, format_state(state)}, state}
    else
      if map_size(state.players) >= 4 do
        {:reply, {:error, :match_full}, state}
      else
        # Add to database
        match = Matches.get_match!(state.match_id)
        {:ok, _mp} = Matches.add_player(match, user)

        # Assign color based on current player count
        color = Enum.at(@colors, map_size(state.players))

        player_info = %{
          user_id: user.id,
          username: user.username || user.name || "Player",
          picture: user.picture,
          color: color,
          score: 0
        }

        new_players = Map.put(state.players, user.id, player_info)
        new_state = %{state | players: new_players}

        # Broadcast to other players
        broadcast(state.match_id, "player_joined", player_info)

        {:reply, {:ok, format_state(new_state)}, new_state}
      end
    end
  end

  @impl true
  def handle_call({:leave, user_id}, _from, state) do
    if Map.has_key?(state.players, user_id) do
      new_players = Map.delete(state.players, user_id)
      new_state = %{state | players: new_players}

      # Broadcast to other players
      broadcast(state.match_id, "player_left", %{user_id: user_id})

      # If no players left and game is waiting, clean up the match
      if map_size(new_players) == 0 and state.status == :waiting do
        Matches.update_match_status(Matches.get_match!(state.match_id), "finished")
        {:stop, :normal, :ok, new_state}
      else
        {:reply, :ok, new_state}
      end
    else
      {:reply, :ok, state}
    end
  end

  @impl true
  def handle_call({:start_game, user_id}, _from, state) do
    cond do
      user_id != state.host_id ->
        {:reply, {:error, :not_host}, state}

      state.status != :waiting ->
        {:reply, {:error, :game_already_started}, state}

      map_size(state.players) < 2 ->
        {:reply, {:error, :not_enough_players}, state}

      true ->
        # Update database status
        Matches.update_match_status(Matches.get_match!(state.match_id), "playing")

        # Start countdown timer
        Process.send_after(self(), :tick, @tick_interval)
        new_state = %{state | status: :playing}

        broadcast(state.match_id, "game_started", %{time_remaining: state.time_remaining})

        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call({:click_cell, user_id, row, col}, _from, state) do
    cond do
      state.status != :playing ->
        {:reply, {:error, :game_not_playing}, state}

      not Map.has_key?(state.players, user_id) ->
        {:reply, {:error, :not_in_game}, state}

      not valid_cell?(state, row, col) ->
        {:reply, {:error, :invalid_cell}, state}

      true ->
        # Update grid - stealing is allowed
        new_grid = Map.put(state.grid, {row, col}, user_id)
        new_state = %{state | grid: new_grid}

        color = state.players[user_id].color

        broadcast(state.match_id, "cell_claimed", %{
          row: row,
          col: col,
          user_id: user_id,
          color: color
        })

        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, format_state(state), state}
  end

  @impl true
  def handle_info(:tick, state) do
    new_time = state.time_remaining - 1

    if new_time <= 0 do
      end_game(state)
    else
      broadcast(state.match_id, "tick", %{time_remaining: new_time})
      Process.send_after(self(), :tick, @tick_interval)
      {:noreply, %{state | time_remaining: new_time}}
    end
  end

  @impl true
  def handle_info(:terminate, state) do
    {:stop, :normal, state}
  end

  # Private functions

  defp initialize_grid(size) do
    for row <- 0..(size - 1), col <- 0..(size - 1), into: %{} do
      {{row, col}, nil}
    end
  end

  defp valid_cell?(state, row, col) do
    row >= 0 and row < state.grid_size and col >= 0 and col < state.grid_size
  end

  defp end_game(state) do
    # Calculate scores
    scores = calculate_scores(state)
    winner_id = determine_winner(scores, state.players)

    # Convert grid to serializable format for database
    final_state =
      state.grid
      |> Enum.map(fn {{row, col}, user_id} -> {"#{row},#{col}", user_id} end)
      |> Map.new()

    # Persist to database
    Matches.finish_match(state.match_id, winner_id, final_state, scores)

    # Update player scores in state
    new_players =
      Enum.reduce(scores, state.players, fn {user_id, score}, players ->
        if Map.has_key?(players, user_id) do
          put_in(players, [user_id, :score], score)
        else
          players
        end
      end)

    # Broadcast end
    broadcast(state.match_id, "game_ended", %{
      winner_id: winner_id,
      scores: scores,
      final_grid: final_state,
      players: new_players
    })

    # Schedule process termination after 60 seconds
    Process.send_after(self(), :terminate, 60_000)

    {:noreply, %{state | status: :finished, players: new_players, time_remaining: 0}}
  end

  defp calculate_scores(state) do
    state.grid
    |> Enum.reduce(%{}, fn {{_row, _col}, user_id}, acc ->
      if user_id do
        Map.update(acc, user_id, 1, &(&1 + 1))
      else
        acc
      end
    end)
  end

  defp determine_winner(scores, players) do
    if Enum.empty?(scores) do
      # No cells claimed, pick random player or nil
      players |> Map.keys() |> List.first()
    else
      {winner_id, _score} = Enum.max_by(scores, fn {_id, score} -> score end)
      winner_id
    end
  end

  defp broadcast(match_id, event, payload) do
    PubSub.broadcast(Backend.PubSub, "match:#{match_id}", {event, payload})
  end

  defp format_state(state) do
    # Convert grid keys to strings for JSON serialization
    grid =
      state.grid
      |> Enum.map(fn {{row, col}, user_id} -> {"#{row},#{col}", user_id} end)
      |> Map.new()

    %{
      match_id: state.match_id,
      code: state.code,
      status: state.status,
      grid_size: state.grid_size,
      time_remaining: state.time_remaining,
      host_id: state.host_id,
      players: state.players,
      grid: grid
    }
  end
end
