defmodule Backend.Matches.PlayerState do
  @moduledoc """
  Represents the state of a player in an active match.
  """

  @player_colors ["#EF4444", "#3B82F6", "#22C55E", "#F59E0B"]
  @max_income 300.0
  @player_radius 0.4

  defstruct [
    :user_id,
    :username,
    :color,
    :picture,
    # Position (float for smooth movement)
    x: 0.0,
    y: 0.0,
    # Velocity
    velocity_x: 0.0,
    velocity_y: 0.0,
    # Movement
    base_speed: 5.0,
    speed_multiplier: 1.0,
    # Energy
    energy: 100.0,
    max_energy: 100.0,
    energy_regen: 10.0,
    # Territory capture
    glow_radius: 1.5,
    # Economy
    coins: 0.0,
    # Power-up stacks (can buy multiple)
    speed_stacks: 0,
    radius_stacks: 0,
    energy_stacks: 0,
    # Power-up flags (one-time purchase)
    has_multishot: false,
    has_piercing: false,
    has_beam_speed: false,
    # Current input state
    input: %{w: false, a: false, s: false, d: false}
  ]

  @doc """
  Creates a new player state at the given spawn position.
  """
  def new(user, spawn_x, spawn_y, color_index) do
    color = Enum.at(@player_colors, rem(color_index, length(@player_colors)))

    %__MODULE__{
      user_id: user.id,
      username: user.username || user.name || "Player",
      picture: user.picture,
      color: color,
      x: spawn_x * 1.0,
      y: spawn_y * 1.0
    }
  end

  @doc """
  Returns available player colors.
  """
  def colors, do: @player_colors

  @doc """
  Updates player input state.
  """
  def update_input(player, input) do
    %{player | input: Map.merge(player.input, input)}
  end

  @doc """
  Updates player position based on input and delta time.
  Returns updated player state.
  """
  def update_position(player, dt) do
    # Calculate velocity based on input
    dx = input_to_direction(player.input.d, player.input.a)
    dy = input_to_direction(player.input.s, player.input.w)

    # Normalize diagonal movement
    {dx, dy} = normalize_direction(dx, dy)

    # Apply speed
    effective_speed = player.base_speed * player.speed_multiplier

    new_x = player.x + dx * effective_speed * dt
    new_y = player.y + dy * effective_speed * dt

    %{
      player
      | x: new_x,
        y: new_y,
        velocity_x: dx * effective_speed,
        velocity_y: dy * effective_speed
    }
  end

  @doc """
  Clamps player position within grid bounds, accounting for player radius.
  """
  def clamp_position(player, grid_size) do
    new_x = max(@player_radius, min(player.x, grid_size - 1.0 - @player_radius))
    new_y = max(@player_radius, min(player.y, grid_size - 1.0 - @player_radius))
    %{player | x: new_x, y: new_y}
  end

  @doc """
  Returns the player collision radius.
  """
  def player_radius, do: @player_radius

  @doc """
  Checks if player can move to a tile (not wall/hole).
  """
  def can_move_to?(_player, map_tiles, new_x, new_y) do
    # Check the tile at the new position
    tile_x = trunc(new_x)
    tile_y = trunc(new_y)
    tile = Map.get(map_tiles, {tile_x, tile_y}, :walkable)
    tile in [:walkable, :generator]
  end

  @doc """
  Regenerates energy based on delta time.
  """
  def regenerate_energy(player, dt) do
    new_energy = min(player.energy + player.energy_regen * dt, player.max_energy)
    %{player | energy: new_energy}
  end

  @doc """
  Consumes energy for shooting. Returns {:ok, player} or {:error, :not_enough_energy}.
  """
  def consume_energy(player, amount) do
    if player.energy >= amount do
      {:ok, %{player | energy: player.energy - amount}}
    else
      {:error, :not_enough_energy}
    end
  end

  @doc """
  Adds coins to player.
  """
  def add_coins(player, amount) do
    new_balance = player.coins + amount
    %{player | coins: min(new_balance, @max_income)}
  end

  @doc """
  Attempts to purchase a power-up. Returns {:ok, player} or {:error, reason}.
  """
  def buy_powerup(player, type) do
    cost = powerup_cost(type, player)

    cond do
      player.coins < cost ->
        {:error, :not_enough_coins}

      type in [:multishot, :piercing, :beam_speed] and has_powerup?(player, type) ->
        {:error, :already_owned}

      true ->
        {:ok, apply_powerup(player, type, cost)}
    end
  end

  @doc """
  Returns the cost of a power-up.
  """
  def powerup_cost(:speed, player) do
    base_cost = 15
    base_cost + player.speed_stacks * 10
  end

  def powerup_cost(:radius, player) do
    base_cost = 20
    base_cost + player.radius_stacks * 10
  end

  def powerup_cost(:energy, player) do
    base_cost = 20
    base_cost + player.energy_stacks * 10
  end

  def powerup_cost(:multishot, _player), do: 40
  def powerup_cost(:piercing, _player), do: 35
  def powerup_cost(:beam_speed, _player), do: 30

  @doc """
  Returns tiles within the player's glow radius.
  """
  def tiles_in_glow_radius(player) do
    cx = trunc(player.x)
    cy = trunc(player.y)
    radius = player.glow_radius

    for dx <- -ceil(radius)..ceil(radius),
        dy <- -ceil(radius)..ceil(radius),
        distance_from_center(dx, dy) <= radius do
      {cx + dx, cy + dy}
    end
  end

  @doc """
  Converts player state to a map for JSON serialization.
  """
  def to_map(player) do
    %{
      user_id: player.user_id,
      username: player.username,
      picture: player.picture,
      color: player.color,
      x: Float.round(player.x, 2),
      y: Float.round(player.y, 2),
      energy: Float.round(player.energy, 1),
      max_energy: player.max_energy,
      coins: Float.round(player.coins, 1),
      glow_radius: player.glow_radius,
      speed_stacks: player.speed_stacks,
      radius_stacks: player.radius_stacks,
      energy_stacks: player.energy_stacks,
      has_multishot: player.has_multishot,
      has_piercing: player.has_piercing,
      has_beam_speed: player.has_beam_speed
    }
  end

  # Private functions

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

  defp distance_from_center(dx, dy) do
    :math.sqrt(dx * dx + dy * dy)
  end

  defp has_powerup?(player, :multishot), do: player.has_multishot
  defp has_powerup?(player, :piercing), do: player.has_piercing
  defp has_powerup?(player, :beam_speed), do: player.has_beam_speed
  defp has_powerup?(_player, _type), do: false

  defp apply_powerup(player, :speed, cost) do
    %{
      player
      | coins: player.coins - cost,
        speed_stacks: player.speed_stacks + 1,
        speed_multiplier: player.speed_multiplier + 0.15
    }
  end

  defp apply_powerup(player, :radius, cost) do
    %{
      player
      | coins: player.coins - cost,
        radius_stacks: player.radius_stacks + 1,
        glow_radius: player.glow_radius + 0.25
    }
  end

  defp apply_powerup(player, :energy, cost) do
    %{
      player
      | coins: player.coins - cost,
        energy_stacks: player.energy_stacks + 1,
        max_energy: player.max_energy + 25,
        energy_regen: player.energy_regen + 2.5
    }
  end

  defp apply_powerup(player, :multishot, cost) do
    %{player | coins: player.coins - cost, has_multishot: true}
  end

  defp apply_powerup(player, :piercing, cost) do
    %{player | coins: player.coins - cost, has_piercing: true}
  end

  defp apply_powerup(player, :beam_speed, cost) do
    %{player | coins: player.coins - cost, has_beam_speed: true}
  end
end
