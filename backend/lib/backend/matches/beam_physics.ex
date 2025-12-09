defmodule Backend.Matches.BeamPhysics do
  @moduledoc """
  Handles beam physics: movement, collisions, reflections, and tile capture.
  """

  @base_speed 15.0
  @fast_speed 30.0
  # beam_width could be used for wider capture area
  # @beam_width 0.3
  @max_lifetime 10.0
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
    time_alive: 0.0,
    piercing_used: false,
    active: true
  ]

  @doc """
  Creates a new beam from a player position in a given direction.
  Returns nil if the beam would immediately hit a wall (player standing against wall).
  """
  def create(player, dir_x, dir_y, map_tiles) do
    # Normalize direction
    magnitude = :math.sqrt(dir_x * dir_x + dir_y * dir_y)

    {norm_x, norm_y} =
      if magnitude > 0.001 do
        {dir_x / magnitude, dir_y / magnitude}
      else
        {1.0, 0.0}
      end

    # Check if firing direction immediately hits a blocking tile
    # Look at the tile slightly ahead in the firing direction
    check_x = player.x + norm_x * 0.6
    check_y = player.y + norm_y * 0.6
    check_tile = {trunc(check_x), trunc(check_y)}
    tile_type = Map.get(map_tiles, check_tile, :boundary)

    if tile_type in [:wall, :hole, :boundary] do
      # Would immediately hit a wall - don't create beam
      nil
    else
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
        time_alive: 0.0,
        piercing_used: false,
        active: true
      }
    end
  end

  @doc """
  Returns the energy cost to fire a beam.
  """
  def energy_cost, do: @energy_cost

  @doc """
  Creates multishot beams (spread pattern).
  Filters out any nil beams (ones that would immediately hit walls).
  """
  def create_multishot(player, dir_x, dir_y, map_tiles) do
    # Main beam
    main = create(player, dir_x, dir_y, map_tiles)

    # Rotate by +/- 15 degrees for side beams
    angle = :math.atan2(dir_y, dir_x)
    spread = :math.pi() / 12

    left_angle = angle + spread
    right_angle = angle - spread

    left = create(player, :math.cos(left_angle), :math.sin(left_angle), map_tiles)
    right = create(player, :math.cos(right_angle), :math.sin(right_angle), map_tiles)

    # Filter out nil beams (ones blocked by walls)
    [main, left, right] |> Enum.reject(&is_nil/1)
  end

  @doc """
  Updates a beam's position for a given delta time.
  Returns {updated_beam, captured_tiles, ended?}
  """
  def update(beam, dt, map_tiles, has_piercing) do
    if not beam.active do
      {beam, [], true}
    else
      new_time_alive = beam.time_alive + dt

      # Check timeout
      if new_time_alive >= @max_lifetime do
        {%{beam | active: false}, [], true}
      else
        # Calculate movement
        move_distance = beam.speed * dt
        new_x = beam.x + beam.dir_x * move_distance
        new_y = beam.y + beam.dir_y * move_distance

        # Get tiles along path
        {captured_tiles, collision} = trace_path(beam, new_x, new_y, map_tiles)

        case collision do
          nil ->
            # No collision, continue
            updated_beam = %{beam | x: new_x, y: new_y, time_alive: new_time_alive}
            {updated_beam, captured_tiles, false}

          {:wall, wall_x, wall_y} ->
            # Hit a wall - calculate stop position at wall edge
            {stop_x, stop_y} = calculate_stop_position(beam, wall_x, wall_y)

            if has_piercing and not beam.piercing_used do
              # Pierce through
              updated_beam = %{
                beam
                | x: new_x,
                  y: new_y,
                  time_alive: new_time_alive,
                  piercing_used: true
              }

              {updated_beam, captured_tiles, false}
            else
              # Stop at wall edge
              {%{beam | x: stop_x, y: stop_y, active: false}, captured_tiles, true}
            end

          {:mirror, mirror_x, mirror_y} ->
            # Calculate which face the beam entered through
            {entry_face, entry_x, entry_y} = calculate_entry_point(beam, mirror_x, mirror_y)

            # Reflect based on actual face hit
            {new_dir_x, new_dir_y} =
              case entry_face do
                :left -> {-beam.dir_x, beam.dir_y}
                :right -> {-beam.dir_x, beam.dir_y}
                :top -> {beam.dir_x, -beam.dir_y}
                :bottom -> {beam.dir_x, -beam.dir_y}
              end

            # Position beam at entry point, then move slightly in new direction
            offset = 0.1
            exit_x = entry_x + new_dir_x * offset
            exit_y = entry_y + new_dir_y * offset

            # Check if exit position is in another blocking tile
            exit_tile = {trunc(exit_x), trunc(exit_y)}
            exit_tile_type = Map.get(map_tiles, exit_tile, :boundary)

            if exit_tile_type in [:wall, :mirror, :hole, :boundary] do
              # Would bounce into another obstacle - terminate beam
              {%{beam | x: entry_x, y: entry_y, active: false}, captured_tiles, true}
            else
              # Safe to continue
              updated_beam = %{
                beam
                | x: exit_x,
                  y: exit_y,
                  dir_x: new_dir_x,
                  dir_y: new_dir_y,
                  time_alive: new_time_alive
              }

              {updated_beam, captured_tiles, false}
            end

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

  # Calculate stop position at edge of blocking tile
  defp calculate_stop_position(beam, tile_x, tile_y) do
    # Calculate which edge of the tile the beam hits
    # Based on beam direction, stop just before entering the tile
    offset = 0.01

    cond do
      # Moving right, stop at left edge of tile
      beam.dir_x > 0 and abs(beam.dir_x) >= abs(beam.dir_y) ->
        {tile_x - offset, beam.y + beam.dir_y * ((tile_x - beam.x) / beam.dir_x)}

      # Moving left, stop at right edge of tile
      beam.dir_x < 0 and abs(beam.dir_x) >= abs(beam.dir_y) ->
        {tile_x + 1 + offset, beam.y + beam.dir_y * ((tile_x + 1 - beam.x) / beam.dir_x)}

      # Moving down (positive y), stop at top edge of tile
      beam.dir_y > 0 ->
        {beam.x + beam.dir_x * ((tile_y - beam.y) / beam.dir_y), tile_y - offset}

      # Moving up (negative y), stop at bottom edge of tile
      true ->
        {beam.x + beam.dir_x * ((tile_y + 1 - beam.y) / beam.dir_y), tile_y + 1 + offset}
    end
  end

  defp trace_path(beam, end_x, end_y, map_tiles) do
    # Use DDA ray-casting to get all tiles along path (never skips tiles)
    tiles_along_path = raycast_tiles(beam.x, beam.y, end_x, end_y)

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

          :mirror ->
            {:halt, {captured_acc, {:mirror, tx, ty}}}

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

  # DDA (Digital Differential Analyzer) ray-casting algorithm
  # Returns all tiles that the ray passes through, in order
  # Unlike Bresenham, this never skips tiles
  defp raycast_tiles(start_x, start_y, end_x, end_y) do
    dir_x = end_x - start_x
    dir_y = end_y - start_y

    # Handle degenerate case (no movement)
    if abs(dir_x) < 0.0001 and abs(dir_y) < 0.0001 do
      [{trunc(start_x), trunc(start_y)}]
    else
      # Current tile
      tile_x = trunc(start_x)
      tile_y = trunc(start_y)
      end_tile_x = trunc(end_x)
      end_tile_y = trunc(end_y)

      # Step direction
      step_x = if dir_x > 0, do: 1, else: -1
      step_y = if dir_y > 0, do: 1, else: -1

      # Calculate t values for next boundary crossing
      # t_max_x = time until next vertical boundary
      # t_max_y = time until next horizontal boundary
      t_max_x =
        if abs(dir_x) < 0.0001 do
          :infinity
        else
          next_x = if dir_x > 0, do: tile_x + 1, else: tile_x
          (next_x - start_x) / dir_x
        end

      t_max_y =
        if abs(dir_y) < 0.0001 do
          :infinity
        else
          next_y = if dir_y > 0, do: tile_y + 1, else: tile_y
          (next_y - start_y) / dir_y
        end

      # Delta t to cross one tile
      t_delta_x = if abs(dir_x) < 0.0001, do: :infinity, else: abs(1.0 / dir_x)
      t_delta_y = if abs(dir_y) < 0.0001, do: :infinity, else: abs(1.0 / dir_y)

      dda_step(
        tile_x,
        tile_y,
        end_tile_x,
        end_tile_y,
        step_x,
        step_y,
        t_max_x,
        t_max_y,
        t_delta_x,
        t_delta_y,
        [{tile_x, tile_y}]
      )
    end
  end

  defp dda_step(tile_x, tile_y, end_tile_x, end_tile_y, _, _, _, _, _, _, acc)
       when tile_x == end_tile_x and tile_y == end_tile_y do
    Enum.reverse(acc)
  end

  defp dda_step(
         tile_x,
         tile_y,
         end_tile_x,
         end_tile_y,
         step_x,
         step_y,
         t_max_x,
         t_max_y,
         t_delta_x,
         t_delta_y,
         acc
       ) do
    # Step in the direction of smallest t
    {new_tile_x, new_tile_y, new_t_max_x, new_t_max_y} =
      cond do
        t_max_x == :infinity and t_max_y == :infinity ->
          # No more movement possible
          {end_tile_x, end_tile_y, :infinity, :infinity}

        t_max_x == :infinity ->
          # Only moving in Y
          {tile_x, tile_y + step_y, :infinity, add_t(t_max_y, t_delta_y)}

        t_max_y == :infinity ->
          # Only moving in X
          {tile_x + step_x, tile_y, add_t(t_max_x, t_delta_x), :infinity}

        t_max_x < t_max_y ->
          # Cross vertical boundary first
          {tile_x + step_x, tile_y, add_t(t_max_x, t_delta_x), t_max_y}

        t_max_y < t_max_x ->
          # Cross horizontal boundary first
          {tile_x, tile_y + step_y, t_max_x, add_t(t_max_y, t_delta_y)}

        true ->
          # Cross both at same time (corner case)
          {tile_x + step_x, tile_y + step_y, add_t(t_max_x, t_delta_x), add_t(t_max_y, t_delta_y)}
      end

    # Add new tile if different from last
    new_acc =
      if {new_tile_x, new_tile_y} != {tile_x, tile_y} do
        [{new_tile_x, new_tile_y} | acc]
      else
        acc
      end

    # Check if we've gone too far (safety limit)
    if length(new_acc) > 500 do
      Enum.reverse(new_acc)
    else
      dda_step(
        new_tile_x,
        new_tile_y,
        end_tile_x,
        end_tile_y,
        step_x,
        step_y,
        new_t_max_x,
        new_t_max_y,
        t_delta_x,
        t_delta_y,
        new_acc
      )
    end
  end

  defp add_t(:infinity, _), do: :infinity
  defp add_t(t, :infinity), do: t
  defp add_t(t, delta), do: t + delta

  # Calculate the exact entry point where the beam crosses into a tile
  # Returns {face_hit, entry_x, entry_y}
  # Tiles span from tile_x to tile_x+1 and tile_y to tile_y+1
  defp calculate_entry_point(beam, tile_x, tile_y) do
    # Tile boundaries
    left = tile_x
    right = tile_x + 1
    top = tile_y
    bottom = tile_y + 1

    # Calculate intersection times with each face
    # t = (boundary - position) / direction
    # We want the smallest positive t that's valid

    intersections =
      []
      |> maybe_add_intersection(:left, left, beam.x, beam.dir_x, beam.y, beam.dir_y, top, bottom)
      |> maybe_add_intersection(
        :right,
        right,
        beam.x,
        beam.dir_x,
        beam.y,
        beam.dir_y,
        top,
        bottom
      )
      |> maybe_add_intersection(:top, top, beam.y, beam.dir_y, beam.x, beam.dir_x, left, right)
      |> maybe_add_intersection(
        :bottom,
        bottom,
        beam.y,
        beam.dir_y,
        beam.x,
        beam.dir_x,
        left,
        right
      )

    # Find the intersection with smallest positive t
    case Enum.filter(intersections, fn {_face, t, _x, _y} -> t > 0.0001 end)
         |> Enum.min_by(fn {_face, t, _x, _y} -> t end, fn -> nil end) do
      {face, _t, x, y} ->
        {face, x, y}

      nil ->
        # Fallback: beam is already inside tile, use center
        # Determine face based on direction
        face =
          cond do
            beam.dir_x > 0 -> :left
            beam.dir_x < 0 -> :right
            beam.dir_y > 0 -> :top
            true -> :bottom
          end

        {face, tile_x + 0.5, tile_y + 0.5}
    end
  end

  # Helper to add intersection with vertical face (left/right)
  defp maybe_add_intersection(
         acc,
         face,
         boundary,
         pos,
         dir,
         other_pos,
         other_dir,
         min_other,
         max_other
       )
       when face in [:left, :right] do
    if abs(dir) > 0.0001 do
      t = (boundary - pos) / dir
      other_at_t = other_pos + other_dir * t

      if other_at_t >= min_other and other_at_t <= max_other do
        [{face, t, boundary, other_at_t} | acc]
      else
        acc
      end
    else
      acc
    end
  end

  # Helper to add intersection with horizontal face (top/bottom)
  defp maybe_add_intersection(
         acc,
         face,
         boundary,
         pos,
         dir,
         other_pos,
         other_dir,
         min_other,
         max_other
       )
       when face in [:top, :bottom] do
    if abs(dir) > 0.0001 do
      t = (boundary - pos) / dir
      other_at_t = other_pos + other_dir * t

      if other_at_t >= min_other and other_at_t <= max_other do
        [{face, t, other_at_t, boundary} | acc]
      else
        acc
      end
    else
      acc
    end
  end
end
