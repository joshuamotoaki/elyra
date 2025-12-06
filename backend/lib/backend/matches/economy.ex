defmodule Backend.Matches.Economy do
  @moduledoc """
  Handles game economy: passive income, generators, coin drops, and power-up purchases.
  """

  @passive_income_per_second 1.0
  @generator_income_per_second 3.0

  # Coin drop types with their values and telegraph durations
  @coin_drops %{
    bronze: %{value: 10, telegraph_seconds: 3},
    silver: %{value: 25, telegraph_seconds: 5},
    gold: %{value: 50, telegraph_seconds: 7}
  }

  @coin_pickup_radius 1.0

  defmodule CoinDrop do
    @moduledoc false
    defstruct [
      :id,
      :type,
      :value,
      :x,
      :y,
      :spawn_at_tick,
      :spawned,
      :collected
    ]
  end

  @doc """
  Calculates passive income for a player over delta time.
  """
  def passive_income(dt) do
    @passive_income_per_second * dt
  end

  @doc """
  Calculates generator income based on owned generators.
  """
  def generator_income(owned_generator_count, dt) do
    owned_generator_count * @generator_income_per_second * dt
  end

  @doc """
  Counts how many generators a player owns.
  """
  def count_owned_generators(user_id, generators, tile_owners) do
    Enum.count(generators, fn gen_pos ->
      Map.get(tile_owners, gen_pos) == user_id
    end)
  end

  @doc """
  Calculates total income for a player this tick.
  """
  def calculate_income(player, generators, tile_owners, dt) do
    owned_count = count_owned_generators(player.user_id, generators, tile_owners)
    passive_income(dt) + generator_income(owned_count, dt)
  end

  @doc """
  Creates a new coin drop.
  """
  def create_coin_drop(type, x, y, current_tick, ticks_per_second) do
    drop_info = Map.get(@coin_drops, type)
    telegraph_ticks = trunc(drop_info.telegraph_seconds * ticks_per_second)

    %CoinDrop{
      id: generate_id(),
      type: type,
      value: drop_info.value,
      x: x * 1.0,
      y: y * 1.0,
      spawn_at_tick: current_tick + telegraph_ticks,
      spawned: false,
      collected: false
    }
  end

  @doc """
  Randomly generates a coin drop if conditions are met.
  Returns nil or a new CoinDrop.
  """
  def maybe_spawn_coin_drop(current_tick, ticks_per_second, grid_size, existing_drops) do
    # Spawn chance per second: ~5%
    # At 60 ticks/sec, that's ~0.083% per tick
    spawn_chance = 0.05 / ticks_per_second

    if :rand.uniform() < spawn_chance and length(existing_drops) < 10 do
      type = random_coin_type()
      x = Enum.random(10..(grid_size - 11))
      y = Enum.random(10..(grid_size - 11))
      create_coin_drop(type, x, y, current_tick, ticks_per_second)
    else
      nil
    end
  end

  @doc """
  Updates coin drops: marks as spawned when telegraph is done, removes old ones.
  """
  def update_coin_drops(drops, current_tick) do
    Enum.map(drops, fn drop ->
      if not drop.spawned and current_tick >= drop.spawn_at_tick do
        %{drop | spawned: true}
      else
        drop
      end
    end)
    |> Enum.reject(& &1.collected)
  end

  @doc """
  Checks if any players can pick up coins.
  Returns {updated_drops, [{user_id, coin_value, coin_id}]}
  """
  def check_coin_pickups(drops, players) do
    Enum.reduce(drops, {[], []}, fn drop, {updated_drops, pickups} ->
      if drop.spawned and not drop.collected do
        nearby_players =
          players
          |> Enum.filter(fn {_uid, p} ->
            distance(drop.x, drop.y, p.x, p.y) <= @coin_pickup_radius
          end)
          |> Enum.map(fn {uid, _p} -> uid end)

        case nearby_players do
          [] ->
            {[drop | updated_drops], pickups}

          [single_player] ->
            # Single player gets full value
            collected_drop = %{drop | collected: true}
            pickup = {single_player, drop.value, drop.id}
            {[collected_drop | updated_drops], [pickup | pickups]}

          multiple ->
            # Split value among multiple players
            split_value = drop.value / length(multiple)
            collected_drop = %{drop | collected: true}
            new_pickups = Enum.map(multiple, fn uid -> {uid, split_value, drop.id} end)
            {[collected_drop | updated_drops], new_pickups ++ pickups}
        end
      else
        {[drop | updated_drops], pickups}
      end
    end)
  end

  @doc """
  Converts a coin drop to a map for JSON serialization.
  """
  def coin_drop_to_map(drop) do
    %{
      id: drop.id,
      type: Atom.to_string(drop.type),
      value: drop.value,
      x: Float.round(drop.x, 2),
      y: Float.round(drop.y, 2),
      spawned: drop.spawned
    }
  end

  @doc """
  Returns all power-up costs.
  """
  def powerup_costs do
    %{
      speed: 15,
      radius: 20,
      energy: 20,
      multishot: 40,
      piercing: 35,
      beam_speed: 30
    }
  end

  # Private functions

  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  defp random_coin_type do
    # Weighted random: bronze more common than gold
    rand = :rand.uniform(100)

    cond do
      rand <= 60 -> :bronze
      rand <= 90 -> :silver
      true -> :gold
    end
  end

  defp distance(x1, y1, x2, y2) do
    :math.sqrt((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1))
  end
end
