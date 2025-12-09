defmodule Backend.Matches.MatchServer do
  @moduledoc """
  GenServer that holds live game state for a single match.
  Runs at 60Hz tick rate for smooth real-time gameplay.
  """
  use GenServer

  alias Backend.Matches
  alias Backend.Matches.{MapGenerator, PlayerState, BeamPhysics, Economy}
  alias Phoenix.PubSub

  # 20Hz tick rate (50ms per tick) - balanced between smoothness and performance
  @tick_interval 50
  @ticks_per_second 20
  @game_duration_seconds 120

  defstruct [
    :match_id,
    :code,
    :host_id,
    :status,
    :is_solo,
    # Map data
    :map_tiles,
    :generators,
    :spawn_points,
    :grid_size,
    # Game state
    :tile_owners,
    :players,
    :beams,
    :coin_drops,
    # Timing
    :tick,
    :time_remaining_ms,
    :last_tick_time
  ]

  # =============
  # Client API
  # =============

  def start_link(match_id) do
    GenServer.start_link(__MODULE__, match_id, name: via_tuple(match_id))
  end

  def via_tuple(match_id) do
    {:via, Registry, {Backend.MatchRegistry, match_id}}
  end

  def exists?(match_id) do
    case Registry.lookup(Backend.MatchRegistry, match_id) do
      [{_pid, _}] -> true
      [] -> false
    end
  end

  @doc "Join a match. Returns the full game state."
  def join(match_id, user) do
    GenServer.call(via_tuple(match_id), {:join, user})
  end

  @doc "Leave a match."
  def leave(match_id, user_id) do
    GenServer.call(via_tuple(match_id), {:leave, user_id})
  end

  @doc "Start the game. Only the host can do this."
  def start_game(match_id, user_id) do
    GenServer.call(via_tuple(match_id), {:start_game, user_id})
  end

  @doc "Update player input state (WASD)."
  def update_input(match_id, user_id, input) do
    GenServer.cast(via_tuple(match_id), {:input, user_id, input})
  end

  @doc "Fire a beam in a direction."
  def shoot(match_id, user_id, dir_x, dir_y) do
    GenServer.cast(via_tuple(match_id), {:shoot, user_id, dir_x, dir_y})
  end

  @doc "Purchase a power-up."
  def buy_powerup(match_id, user_id, powerup_type) do
    GenServer.call(via_tuple(match_id), {:buy_powerup, user_id, powerup_type})
  end

  @doc "Get the current game state."
  def get_state(match_id) do
    GenServer.call(via_tuple(match_id), :get_state)
  end

  # =============
  # Server Callbacks
  # =============

  @impl true
  def init(match_id) do
    match = Matches.get_match_with_players(match_id)

    if match do
      # Generate map
      map_data = MapGenerator.generate()

      # Initialize tile owners (all nil)
      tile_owners =
        map_data.map_tiles
        |> Enum.filter(fn {_pos, type} -> type in [:walkable, :generator] end)
        |> Enum.map(fn {pos, _type} -> {pos, nil} end)
        |> Map.new()

      # Build initial players from database (for rejoin scenarios)
      players =
        match.match_players
        |> Enum.with_index()
        |> Enum.map(fn {mp, idx} ->
          spawn_point = Enum.at(map_data.spawn_points, rem(idx, 4))
          {spawn_x, spawn_y} = spawn_point
          player = PlayerState.new(mp.user, spawn_x, spawn_y, idx)
          {mp.user_id, player}
        end)
        |> Map.new()

      # Solo matches have infinite time
      time_remaining = if match.is_solo, do: :infinity, else: @game_duration_seconds * 1000

      state = %__MODULE__{
        match_id: match_id,
        code: match.code,
        host_id: match.host_id,
        status: :waiting,
        is_solo: match.is_solo,
        map_tiles: map_data.map_tiles,
        generators: map_data.generators,
        spawn_points: map_data.spawn_points,
        grid_size: map_data.grid_size,
        tile_owners: tile_owners,
        players: players,
        beams: [],
        coin_drops: [],
        tick: 0,
        time_remaining_ms: time_remaining,
        last_tick_time: nil
      }

      {:ok, state}
    else
      {:stop, :match_not_found}
    end
  end

  @impl true
  def handle_call({:join, user}, _from, state) do
    cond do
      Map.has_key?(state.players, user.id) ->
        # Already in match, return current state
        {:reply, {:ok, format_full_state(state)}, state}

      state.status != :waiting ->
        {:reply, {:error, :game_in_progress}, state}

      map_size(state.players) >= 4 ->
        {:reply, {:error, :match_full}, state}

      true ->
        # Add to database
        match = Matches.get_match!(state.match_id)
        {:ok, _mp} = Matches.add_player(match, user)

        # Assign spawn point and create player
        idx = map_size(state.players)
        spawn_point = Enum.at(state.spawn_points, rem(idx, 4))
        {spawn_x, spawn_y} = spawn_point
        player = PlayerState.new(user, spawn_x, spawn_y, idx)

        new_players = Map.put(state.players, user.id, player)
        new_state = %{state | players: new_players}

        # Broadcast join
        broadcast(state.match_id, "player_joined", PlayerState.to_map(player))

        {:reply, {:ok, format_full_state(new_state)}, new_state}
    end
  end

  @impl true
  def handle_call({:leave, user_id}, _from, state) do
    if Map.has_key?(state.players, user_id) do
      new_players = Map.delete(state.players, user_id)
      new_state = %{state | players: new_players}

      broadcast(state.match_id, "player_left", %{user_id: user_id})

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
    # Solo matches only need 1 player, regular matches need 2
    min_players = if state.is_solo, do: 1, else: 2

    cond do
      user_id != state.host_id ->
        {:reply, {:error, :not_host}, state}

      state.status != :waiting ->
        {:reply, {:error, :game_already_started}, state}

      map_size(state.players) < min_players ->
        {:reply, {:error, :not_enough_players}, state}

      true ->
        Matches.update_match_status(Matches.get_match!(state.match_id), "playing")

        # Start game loop
        Process.send_after(self(), :tick, @tick_interval)
        now = System.monotonic_time(:millisecond)

        new_state = %{state | status: :playing, last_tick_time: now}

        broadcast(state.match_id, "game_started", %{
          time_remaining_ms: state.time_remaining_ms
        })

        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call({:buy_powerup, user_id, powerup_type}, _from, state) do
    case Map.get(state.players, user_id) do
      nil ->
        {:reply, {:error, :not_in_game}, state}

      player ->
        type_atom = String.to_existing_atom(powerup_type)

        case PlayerState.buy_powerup(player, type_atom) do
          {:ok, updated_player} ->
            new_players = Map.put(state.players, user_id, updated_player)
            new_state = %{state | players: new_players}

            broadcast(state.match_id, "powerup_purchased", %{
              user_id: user_id,
              type: powerup_type
            })

            {:reply, :ok, new_state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
    end
  rescue
    ArgumentError ->
      {:reply, {:error, :invalid_powerup}, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, format_full_state(state), state}
  end

  @impl true
  def handle_cast({:input, user_id, input}, state) do
    case Map.get(state.players, user_id) do
      nil ->
        {:noreply, state}

      player ->
        # Normalize input keys
        normalized_input = %{
          w: Map.get(input, "w", false) || Map.get(input, :w, false),
          a: Map.get(input, "a", false) || Map.get(input, :a, false),
          s: Map.get(input, "s", false) || Map.get(input, :s, false),
          d: Map.get(input, "d", false) || Map.get(input, :d, false)
        }

        updated_player = PlayerState.update_input(player, normalized_input)
        new_players = Map.put(state.players, user_id, updated_player)
        {:noreply, %{state | players: new_players}}
    end
  end

  @impl true
  def handle_cast({:shoot, user_id, dir_x, dir_y}, state) do
    if state.status != :playing do
      {:noreply, state}
    else
      case Map.get(state.players, user_id) do
        nil ->
          {:noreply, state}

        player ->
          energy_cost = BeamPhysics.energy_cost()

          case PlayerState.consume_energy(player, energy_cost) do
            {:ok, updated_player} ->
              # Create beam(s)
              new_beams =
                if player.has_multishot do
                  BeamPhysics.create_multishot(player, dir_x, dir_y)
                else
                  [BeamPhysics.create(player, dir_x, dir_y)]
                end

              new_players = Map.put(state.players, user_id, updated_player)

              # Broadcast beam fired
              Enum.each(new_beams, fn beam ->
                broadcast(state.match_id, "beam_fired", BeamPhysics.to_map(beam))
              end)

              {:noreply, %{state | players: new_players, beams: new_beams ++ state.beams}}

            {:error, _reason} ->
              {:noreply, state}
          end
      end
    end
  end

  @impl true
  def handle_info(:tick, state) do
    if state.status != :playing do
      {:noreply, state}
    else
      now = System.monotonic_time(:millisecond)
      dt = (now - state.last_tick_time) / 1000.0

      # Update time remaining (solo matches have :infinity time)
      new_time =
        case state.time_remaining_ms do
          :infinity -> :infinity
          ms -> ms - @tick_interval
        end

      # Solo matches never end from timer
      should_end = new_time != :infinity and new_time <= 0

      if should_end do
        end_game(state)
      else
        # Store old tile owners for diffing
        old_tile_owners = state.tile_owners

        # Run game loop
        new_state =
          state
          |> Map.put(:tick, state.tick + 1)
          |> Map.put(:time_remaining_ms, new_time)
          |> Map.put(:last_tick_time, now)
          |> update_players(dt)
          |> update_glow_capture()
          |> update_beams(dt)
          |> update_economy(dt)
          |> update_coin_drops()
          |> check_coin_pickups()

        # Find changed tiles
        changed_tiles = diff_tile_owners(old_tile_owners, new_state.tile_owners)

        # Broadcast state delta
        broadcast_state_delta(new_state, changed_tiles)

        # Schedule next tick
        Process.send_after(self(), :tick, @tick_interval)

        {:noreply, new_state}
      end
    end
  end

  @impl true
  def handle_info(:terminate, state) do
    {:stop, :normal, state}
  end

  # =============
  # Game Loop Functions
  # =============

  defp update_players(state, dt) do
    new_players =
      state.players
      |> Enum.map(fn {user_id, player} ->
        updated =
          player
          |> apply_movement_with_collision(dt, state.map_tiles)
          |> PlayerState.clamp_position(state.grid_size)
          |> PlayerState.regenerate_energy(dt)

        {user_id, updated}
      end)
      |> Map.new()

    %{state | players: new_players}
  end

  defp apply_movement_with_collision(player, dt, map_tiles) do
    radius = PlayerState.player_radius()
    effective_speed = player.base_speed * player.speed_multiplier

    # Calculate velocity based on input
    dx = input_to_direction(player.input.d, player.input.a)
    dy = input_to_direction(player.input.s, player.input.w)
    {dx, dy} = normalize_direction(dx, dy)

    velocity_x = dx * effective_speed
    velocity_y = dy * effective_speed

    # Try X movement first
    proposed_x = player.x + velocity_x * dt

    new_x =
      if can_occupy?(proposed_x, player.y, map_tiles, radius) do
        proposed_x
      else
        player.x
      end

    # Try Y movement second (using new_x position)
    proposed_y = player.y + velocity_y * dt

    new_y =
      if can_occupy?(new_x, proposed_y, map_tiles, radius) do
        proposed_y
      else
        player.y
      end

    %{player | x: new_x, y: new_y, velocity_x: velocity_x, velocity_y: velocity_y}
  end

  # Check if a circular player can occupy a position without overlapping blocking tiles
  defp can_occupy?(x, y, map_tiles, radius) do
    # Get bounding box of tiles the player could touch
    # Expand by 1 to account for centered tile coordinates (tiles span n-0.5 to n+0.5)
    min_tile_x = floor(x - radius) - 1
    max_tile_x = floor(x + radius) + 1
    min_tile_y = floor(y - radius) - 1
    max_tile_y = floor(y + radius) + 1

    # Check each tile in the bounding box
    not Enum.any?(min_tile_x..max_tile_x, fn tx ->
      Enum.any?(min_tile_y..max_tile_y, fn ty ->
        tile_type = Map.get(map_tiles, {tx, ty}, :wall)

        is_blocking = tile_type in [:wall, :mirror_ne, :mirror_nw, :hole]
        is_blocking and circle_intersects_tile?(x, y, radius, tx, ty)
      end)
    end)
  end

  # Check if a circle at (cx, cy) with given radius intersects a tile at (tile_x, tile_y)
  # Tiles are CENTERED at their integer coordinates (Three.js BoxGeometry is centered)
  defp circle_intersects_tile?(cx, cy, radius, tile_x, tile_y) do
    # Tile spans from tile_x - 0.5 to tile_x + 0.5 (centered on integer coordinate)
    tile_min_x = tile_x - 0.5
    tile_max_x = tile_x + 0.5
    tile_min_y = tile_y - 0.5
    tile_max_y = tile_y + 0.5

    # Find closest point on tile to circle center
    closest_x = max(tile_min_x, min(cx, tile_max_x))
    closest_y = max(tile_min_y, min(cy, tile_max_y))

    # Check distance from circle center to closest point
    dist_x = cx - closest_x
    dist_y = cy - closest_y
    distance_sq = dist_x * dist_x + dist_y * dist_y

    distance_sq <= radius * radius
  end

  defp input_to_direction(positive, negative) do
    cond do
      positive and not negative -> 1.0
      negative and not positive -> -1.0
      true -> 0.0
    end
  end

  defp normalize_direction(dx, dy) when dx != 0.0 and dy != 0.0 do
    magnitude = :math.sqrt(dx * dx + dy * dy)
    {dx / magnitude, dy / magnitude}
  end

  defp normalize_direction(dx, dy), do: {dx, dy}

  defp update_glow_capture(state) do
    # Each player captures tiles within their glow radius
    new_tile_owners =
      Enum.reduce(state.players, state.tile_owners, fn {user_id, player}, owners ->
        tiles = PlayerState.tiles_in_glow_radius(player)

        Enum.reduce(tiles, owners, fn tile, acc ->
          # Only capture if tile exists and is capturable
          if Map.has_key?(acc, tile) do
            Map.put(acc, tile, user_id)
          else
            acc
          end
        end)
      end)

    %{state | tile_owners: new_tile_owners}
  end

  defp update_beams(state, dt) do
    {updated_beams, all_captured, ended_beam_ids} =
      Enum.reduce(state.beams, {[], [], []}, fn beam, {beams_acc, captured_acc, ended_acc} ->
        player = Map.get(state.players, beam.user_id)
        has_piercing = player != nil and player.has_piercing

        {updated_beam, captured_tiles, ended?} =
          BeamPhysics.update(beam, dt, state.map_tiles, has_piercing)

        # FIX: Tag the tiles with the owner's ID immediately
        # converts [{x,y}] -> [{{x,y}, user_id}]
        tagged_captures = Enum.map(captured_tiles, fn tile -> {tile, beam.user_id} end)

        new_beams_acc = if not ended?, do: [updated_beam | beams_acc], else: beams_acc
        new_ended_acc = if ended?, do: [beam.id | ended_acc], else: ended_acc

        # Add tagged captures to the list
        {new_beams_acc, tagged_captures ++ captured_acc, new_ended_acc}
      end)

    # Capture tiles from beams
    new_tile_owners =
      Enum.reduce(all_captured, state.tile_owners, fn {tile_pos, owner_id}, owners ->
        if Map.has_key?(owners, tile_pos) do
          # We now have the correct owner_id directly
          Map.put(owners, tile_pos, owner_id)
        else
          owners
        end
      end)

    # Broadcast ended beams
    Enum.each(ended_beam_ids, fn beam_id ->
      broadcast(state.match_id, "beam_ended", %{id: beam_id})
    end)

    %{state | beams: updated_beams, tile_owners: new_tile_owners}
  end

  defp update_economy(state, dt) do
    new_players =
      state.players
      |> Enum.map(fn {user_id, player} ->
        income = Economy.calculate_income(player, state.generators, state.tile_owners, dt)
        updated = PlayerState.add_coins(player, income)
        {user_id, updated}
      end)
      |> Map.new()

    %{state | players: new_players}
  end

  defp update_coin_drops(state) do
    # Maybe spawn new coin
    new_drop =
      Economy.maybe_spawn_coin_drop(
        state.tick,
        @ticks_per_second,
        state.grid_size,
        state.coin_drops
      )

    drops =
      if new_drop do
        broadcast(state.match_id, "coin_telegraph", Economy.coin_drop_to_map(new_drop))
        [new_drop | state.coin_drops]
      else
        state.coin_drops
      end

    # Update existing drops
    updated_drops = Economy.update_coin_drops(drops, state.tick)

    # Broadcast newly spawned coins
    Enum.each(updated_drops, fn drop ->
      old_drop = Enum.find(drops, fn d -> d.id == drop.id end)

      if old_drop && not old_drop.spawned && drop.spawned do
        broadcast(state.match_id, "coin_spawned", Economy.coin_drop_to_map(drop))
      end
    end)

    %{state | coin_drops: updated_drops}
  end

  defp check_coin_pickups(state) do
    {updated_drops, pickups} = Economy.check_coin_pickups(state.coin_drops, state.players)

    # Apply pickups to players
    new_players =
      Enum.reduce(pickups, state.players, fn {user_id, value, coin_id}, players ->
        case Map.get(players, user_id) do
          nil ->
            players

          player ->
            updated = PlayerState.add_coins(player, value)
            broadcast(state.match_id, "coin_collected", %{id: coin_id, user_id: user_id})
            Map.put(players, user_id, updated)
        end
      end)

    # Remove collected coins
    final_drops = Enum.reject(updated_drops, & &1.collected)

    %{state | coin_drops: final_drops, players: new_players}
  end

  # =============
  # Broadcasting
  # =============

  defp diff_tile_owners(old_owners, new_owners) do
    # Find tiles that have changed ownership
    new_owners
    |> Enum.filter(fn {pos, new_owner} ->
      old_owner = Map.get(old_owners, pos)
      old_owner != new_owner
    end)
    |> Map.new()
  end

  defp broadcast_state_delta(state, changed_tiles) do
    # Build delta with only essential data for each tick
    # Send minimal player data to reduce bandwidth
    # Convert :infinity to nil for JSON serialization
    time_remaining =
      case state.time_remaining_ms do
        :infinity -> nil
        ms -> ms
      end

    delta = %{
      tick: state.tick,
      server_timestamp: System.system_time(:millisecond),
      time_remaining_ms: time_remaining,
      players:
        state.players
        |> Enum.map(fn {uid, p} ->
          # Only send position and frequently changing state
          {uid,
           %{
             x: p.x,
             y: p.y,
             energy: p.energy,
             coins: p.coins,
             max_energy: p.max_energy,
             glow_radius: p.glow_radius,
             speed_stacks: p.speed_stacks,
             radius_stacks: p.radius_stacks,
             energy_stacks: p.energy_stacks,
             has_multishot: p.has_multishot,
             has_piercing: p.has_piercing,
             has_beam_speed: p.has_beam_speed
           }}
        end)
        |> Map.new(),
      beams: Enum.map(state.beams, &BeamPhysics.to_map/1),
      # Only include changed tiles to reduce bandwidth
      tiles: serialize_tile_owners(changed_tiles)
    }

    broadcast(state.match_id, "state_delta", delta)
  end

  defp broadcast(match_id, event, payload) do
    PubSub.broadcast(Backend.PubSub, "match:#{match_id}", {event, payload})
  end

  # =============
  # Game End
  # =============

  defp end_game(state) do
    # Calculate final scores (territory percentage)
    total_tiles = map_size(state.tile_owners)

    scores =
      state.tile_owners
      |> Enum.reduce(%{}, fn {_tile, owner_id}, acc ->
        if owner_id do
          Map.update(acc, owner_id, 1, &(&1 + 1))
        else
          acc
        end
      end)
      |> Enum.map(fn {user_id, count} ->
        percentage = if total_tiles > 0, do: count * 100 / total_tiles, else: 0
        {user_id, Float.round(percentage, 1)}
      end)
      |> Map.new()

    winner_id = determine_winner(scores)

    # Persist to database
    final_state = serialize_tile_owners(state.tile_owners)
    Matches.finish_match(state.match_id, winner_id, final_state, scores)

    # Update player scores
    new_players =
      Enum.reduce(scores, state.players, fn {user_id, score}, players ->
        case Map.get(players, user_id) do
          nil -> players
          player -> Map.put(players, user_id, %{player | coins: score})
        end
      end)

    # Broadcast end
    broadcast(state.match_id, "game_ended", %{
      winner_id: winner_id,
      scores: scores,
      players:
        new_players
        |> Enum.map(fn {uid, p} -> {uid, PlayerState.to_map(p)} end)
        |> Map.new()
    })

    # Schedule termination
    Process.send_after(self(), :terminate, 60_000)

    {:noreply, %{state | status: :finished, players: new_players, time_remaining_ms: 0}}
  end

  defp determine_winner(scores) do
    if Enum.empty?(scores) do
      nil
    else
      {winner_id, _score} = Enum.max_by(scores, fn {_id, score} -> score end)
      winner_id
    end
  end

  # =============
  # Helpers
  # =============

  defp format_full_state(state) do
    # Convert :infinity to nil for JSON serialization
    time_remaining =
      case state.time_remaining_ms do
        :infinity -> nil
        ms -> ms
      end

    %{
      match_id: state.match_id,
      code: state.code,
      status: state.status,
      host_id: state.host_id,
      is_solo: state.is_solo,
      grid_size: state.grid_size,
      time_remaining_ms: time_remaining,
      tick: state.tick,
      server_timestamp: System.system_time(:millisecond),
      map_tiles: serialize_map_tiles(state.map_tiles),
      tile_owners: serialize_tile_owners(state.tile_owners),
      generators: Enum.map(state.generators, fn {x, y} -> "#{x},#{y}" end),
      spawn_points: Enum.map(state.spawn_points, fn {x, y} -> "#{x},#{y}" end),
      players:
        state.players
        |> Enum.map(fn {uid, p} -> {uid, PlayerState.to_map(p)} end)
        |> Map.new(),
      beams: Enum.map(state.beams, &BeamPhysics.to_map/1),
      coin_drops: Enum.map(state.coin_drops, &Economy.coin_drop_to_map/1)
    }
  end

  defp serialize_map_tiles(tiles) do
    tiles
    |> Enum.map(fn {{x, y}, type} -> {"#{x},#{y}", Atom.to_string(type)} end)
    |> Map.new()
  end

  defp serialize_tile_owners(owners) do
    owners
    |> Enum.map(fn {{x, y}, owner_id} -> {"#{x},#{y}", owner_id} end)
    |> Map.new()
  end
end
