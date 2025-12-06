defmodule Backend.Matches.BeamPhysics do
  @moduledoc """
  Handles beam physics: movement, collisions, reflections, and tile capture.
  """

  @base_speed 50.0
  @fast_speed 100.0
  # beam_width could be used for wider capture area
  # @beam_width 0.3
  @max_distance 150.0
  @energy_cost 15

  defstruct [
    :id,
    :user_id,
    :color,
    x: 0.0,
    y: 0.0,
    dir_x: 0.0,
    dir_y: 0.0,
    speed: @base_speed,
    distance_traveled: 0.0,
    piercing_used: false,
    active: true
  ]

  @doc """
  Creates a new beam from a player position in a given direction.
  """
  def create(player, dir_x, dir_y) do
    # Normalize direction
    magnitude = :math.sqrt(dir_x * dir_x + dir_y * dir_y)

    {norm_x, norm_y} =
      if magnitude > 0.001 do
        {dir_x / magnitude, dir_y / magnitude}
      else
        {1.0, 0.0}
      end

    speed = if player.has_beam_speed, do: @fast_speed, else: @base_speed

    %__MODULE__{
      id: generate_id(),
      user_id: player.user_id,
      color: player.color,
      x: player.x,
      y: player.y,
      dir_x: norm_x,
      dir_y: norm_y,
      speed: speed,
      piercing_used: false,
      active: true
    }
  end

  @doc """
  Returns the energy cost to fire a beam.
  """
  def energy_cost, do: @energy_cost

  @doc """
  Creates multishot beams (spread pattern).
  """
  def create_multishot(player, dir_x, dir_y) do
    # Main beam
    main = create(player, dir_x, dir_y)

    # Rotate by +/- 15 degrees for side beams
    angle = :math.atan2(dir_y, dir_x)
    spread = :math.pi() / 12

    left_angle = angle + spread
    right_angle = angle - spread

    left = create(player, :math.cos(left_angle), :math.sin(left_angle))
    right = create(player, :math.cos(right_angle), :math.sin(right_angle))

    [main, left, right]
  end

  @doc """
  Updates a beam's position for a given delta time.
  Returns {updated_beam, captured_tiles, ended?}
  """
  def update(beam, dt, map_tiles, has_piercing) do
    if not beam.active do
      {beam, [], true}
    else
      # Calculate movement
      move_distance = beam.speed * dt
      new_x = beam.x + beam.dir_x * move_distance
      new_y = beam.y + beam.dir_y * move_distance
      new_distance = beam.distance_traveled + move_distance

      # Check max distance
      if new_distance >= @max_distance do
        {%{beam | active: false}, [], true}
      else
        # Get tiles along path
        {captured_tiles, collision} = trace_path(beam, new_x, new_y, map_tiles)

        case collision do
          nil ->
            # No collision, continue
            updated_beam = %{beam | x: new_x, y: new_y, distance_traveled: new_distance}
            {updated_beam, captured_tiles, false}

          {:wall, _wall_x, _wall_y} ->
            # Hit a wall
            if has_piercing and not beam.piercing_used do
              # Pierce through
              updated_beam = %{
                beam
                | x: new_x,
                  y: new_y,
                  distance_traveled: new_distance,
                  piercing_used: true
              }

              {updated_beam, captured_tiles, false}
            else
              # Stop
              {%{beam | active: false}, captured_tiles, true}
            end

          {:mirror_ne, mirror_x, mirror_y} ->
            # NE mirror: reflects beam 90 degrees
            # NE mirror at 45 degrees: swaps x/y components
            {new_dir_x, new_dir_y} = reflect_ne(beam.dir_x, beam.dir_y)

            updated_beam = %{
              beam
              | x: mirror_x + 0.5,
                y: mirror_y + 0.5,
                dir_x: new_dir_x,
                dir_y: new_dir_y,
                distance_traveled: new_distance
            }

            {updated_beam, captured_tiles, false}

          {:mirror_nw, mirror_x, mirror_y} ->
            # NW mirror: reflects beam 90 degrees the other way
            {new_dir_x, new_dir_y} = reflect_nw(beam.dir_x, beam.dir_y)

            updated_beam = %{
              beam
              | x: mirror_x + 0.5,
                y: mirror_y + 0.5,
                dir_x: new_dir_x,
                dir_y: new_dir_y,
                distance_traveled: new_distance
            }

            {updated_beam, captured_tiles, false}

          {:hole, _, _} ->
            # Beam falls into hole
            {%{beam | active: false}, captured_tiles, true}

          {:boundary, _, _} ->
            # Hit map boundary
            {%{beam | active: false}, captured_tiles, true}
        end
      end
    end
  end

  @doc """
  Converts beam to map for JSON serialization.
  """
  def to_map(beam) do
    %{
      id: beam.id,
      user_id: beam.user_id,
      color: beam.color,
      x: Float.round(beam.x, 2),
      y: Float.round(beam.y, 2),
      dir_x: Float.round(beam.dir_x, 3),
      dir_y: Float.round(beam.dir_y, 3)
    }
  end

  # Private functions

  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  defp trace_path(beam, end_x, end_y, map_tiles) do
    # Use Bresenham-like algorithm to get all tiles along path
    start_tile_x = trunc(beam.x)
    start_tile_y = trunc(beam.y)
    end_tile_x = trunc(end_x)
    end_tile_y = trunc(end_y)

    tiles_along_path = bresenham_line(start_tile_x, start_tile_y, end_tile_x, end_tile_y)

    # Note: We could expand to tiles within beam width here if needed
    # For now, just use the line path

    # Find first collision and collect capturable tiles
    {capturable, collision} =
      tiles_along_path
      |> Enum.reduce_while({[], nil}, fn {tx, ty} = tile, {captured_acc, _} ->
        tile_type = Map.get(map_tiles, tile, :boundary)

        case tile_type do
          :walkable ->
            {:cont, {[tile | captured_acc], nil}}

          :generator ->
            {:cont, {[tile | captured_acc], nil}}

          :wall ->
            {:halt, {captured_acc, {:wall, tx, ty}}}

          :mirror_ne ->
            {:halt, {captured_acc, {:mirror_ne, tx, ty}}}

          :mirror_nw ->
            {:halt, {captured_acc, {:mirror_nw, tx, ty}}}

          :hole ->
            {:halt, {captured_acc, {:hole, tx, ty}}}

          :boundary ->
            {:halt, {captured_acc, {:boundary, tx, ty}}}

          _ ->
            {:halt, {captured_acc, {:boundary, tx, ty}}}
        end
      end)

    {Enum.reverse(capturable), collision}
  end

  defp bresenham_line(x0, y0, x1, y1) do
    dx = abs(x1 - x0)
    dy = abs(y1 - y0)
    sx = if x0 < x1, do: 1, else: -1
    sy = if y0 < y1, do: 1, else: -1
    err = dx - dy

    bresenham_step(x0, y0, x1, y1, dx, dy, sx, sy, err, [])
  end

  defp bresenham_step(x, y, x1, y1, _dx, _dy, _sx, _sy, _err, acc) when x == x1 and y == y1 do
    Enum.reverse([{x, y} | acc])
  end

  defp bresenham_step(x, y, x1, y1, dx, dy, sx, sy, err, acc) do
    e2 = 2 * err

    {new_x, new_err_x} =
      if e2 > -dy do
        {x + sx, err - dy}
      else
        {x, err}
      end

    {new_y, new_err} =
      if e2 < dx do
        {y + sy, new_err_x + dx}
      else
        {y, new_err_x}
      end

    bresenham_step(new_x, new_y, x1, y1, dx, dy, sx, sy, new_err, [{x, y} | acc])
  end

  # NE mirror (/) - swaps x and y components
  defp reflect_ne(dir_x, dir_y) do
    {dir_y, dir_x}
  end

  # NW mirror (\) - swaps and negates
  defp reflect_nw(dir_x, dir_y) do
    {-dir_y, -dir_x}
  end
end
