defmodule Backend.Matches.MapGenerator do
  @moduledoc """
  Generates game maps with tiles, generators, walls, mirrors, and holes.
  """

  @grid_size 20
  @generator_count_range 6..9
  @generator_min_distance 8
  @wall_cluster_count_range 38..55
  @wall_cluster_size_range 3..5
  @hole_count_range 10..18
  @mirror_conversion_rate 0.3
  @spawn_clear_radius 3

  @type tile_type :: :walkable | :hole | :wall | :mirror | :generator

  @doc """
  Generates a new game map.

  Returns:
    - `map_tiles`: Map of `{x, y} => tile_type`
    - `generators`: List of `{x, y}` positions
    - `spawn_points`: List of 4 `{x, y}` spawn positions
  """
  def generate do
    # Start with all walkable tiles
    tiles = initialize_walkable_grid()

    # Add border walls around the edges
    tiles = add_border_walls(tiles)

    # Place generators first (most important)
    {tiles, generators} = place_generators(tiles)

    # Place wall clusters
    tiles = place_wall_clusters(tiles, generators)

    # Convert some walls to mirrors
    tiles = convert_walls_to_mirrors(tiles)

    # Calculate spawn points in corners
    spawn_points = calculate_spawn_points()

    # Clear areas around spawns
    tiles = clear_spawn_areas(tiles, spawn_points)

    # Place holes AFTER clearing spawn areas so they don't get wiped
    tiles = place_holes(tiles, generators)

    # Fill in any unreachable tiles (convert to walls)
    tiles = fill_unreachable_tiles(tiles, spawn_points)

    # Validate connectivity (ensure all spawns can reach each other)
    if connected?(tiles, spawn_points) do
      %{
        map_tiles: tiles,
        generators: generators,
        spawn_points: spawn_points,
        grid_size: @grid_size
      }
    else
      # Retry if not connected
      generate()
    end
  end

  defp add_border_walls(tiles) do
    # Add walls around all edges
    # Top and bottom edges
    top_bottom = for x <- 0..(@grid_size - 1), y <- [0, @grid_size - 1], do: {x, y}
    # Left and right edges (excluding corners already added)
    left_right = for y <- 1..(@grid_size - 2), x <- [0, @grid_size - 1], do: {x, y}

    border_positions = top_bottom ++ left_right

    Enum.reduce(border_positions, tiles, fn pos, acc ->
      Map.put(acc, pos, :wall)
    end)
  end

  defp initialize_walkable_grid do
    for x <- 0..(@grid_size - 1), y <- 0..(@grid_size - 1), into: %{} do
      {{x, y}, :walkable}
    end
  end

  defp place_generators(tiles) do
    count = Enum.random(@generator_count_range)
    place_generators_recursive(tiles, [], count, 0)
  end

  defp place_generators_recursive(tiles, generators, 0, _attempts), do: {tiles, generators}

  defp place_generators_recursive(tiles, generators, _remaining, attempts) when attempts > 1000 do
    # Give up if too many attempts
    {tiles, generators}
  end

  defp place_generators_recursive(tiles, generators, remaining, attempts) do
    # Avoid edges
    x = Enum.random(5..(@grid_size - 6))
    y = Enum.random(5..(@grid_size - 6))
    pos = {x, y}

    if far_enough_from_all?(pos, generators, @generator_min_distance) do
      new_tiles = Map.put(tiles, pos, :generator)
      place_generators_recursive(new_tiles, [pos | generators], remaining - 1, 0)
    else
      place_generators_recursive(tiles, generators, remaining, attempts + 1)
    end
  end

  defp far_enough_from_all?(pos, positions, min_distance) do
    Enum.all?(positions, fn other_pos ->
      distance(pos, other_pos) >= min_distance
    end)
  end

  defp distance({x1, y1}, {x2, y2}) do
    :math.sqrt(:math.pow(x2 - x1, 2) + :math.pow(y2 - y1, 2))
  end

  defp place_wall_clusters(tiles, generators) do
    cluster_count = Enum.random(@wall_cluster_count_range)

    Enum.reduce(1..cluster_count, tiles, fn _i, acc_tiles ->
      place_wall_cluster(acc_tiles, generators)
    end)
  end

  defp place_wall_cluster(tiles, _generators) do
    # Pick a random starting point throughout the map (just avoiding border)
    start_x = Enum.random(2..(@grid_size - 3))
    start_y = Enum.random(2..(@grid_size - 3))
    start_pos = {start_x, start_y}

    # Only place if tile is walkable
    if Map.get(tiles, start_pos) == :walkable do
      cluster_size = Enum.random(@wall_cluster_size_range)
      grow_cluster(tiles, [start_pos], cluster_size)
    else
      tiles
    end
  end

  defp grow_cluster(tiles, _positions, 0), do: tiles

  defp grow_cluster(tiles, positions, remaining) do
    # Pick a random position from current cluster
    current = Enum.random(positions)
    {cx, cy} = current

    # Pick a random adjacent cell
    neighbors = [
      {cx + 1, cy},
      {cx - 1, cy},
      {cx, cy + 1},
      {cx, cy - 1}
    ]

    valid_neighbors =
      Enum.filter(neighbors, fn {nx, ny} = pos ->
        nx >= 1 and nx < @grid_size - 1 and
          ny >= 1 and ny < @grid_size - 1 and
          Map.get(tiles, pos) == :walkable
      end)

    case valid_neighbors do
      [] ->
        tiles

      _ ->
        new_pos = Enum.random(valid_neighbors)
        new_tiles = Map.put(tiles, new_pos, :wall)
        grow_cluster(new_tiles, [new_pos | positions], remaining - 1)
    end
  end

  defp place_holes(tiles, generators) do
    hole_count = Enum.random(@hole_count_range)

    Enum.reduce(1..hole_count, tiles, fn _i, acc_tiles ->
      place_single_hole(acc_tiles, generators, 0)
    end)
  end

  defp place_single_hole(tiles, _generators, attempts) when attempts > 100, do: tiles

  defp place_single_hole(tiles, generators, attempts) do
    x = Enum.random(5..(@grid_size - 6))
    y = Enum.random(5..(@grid_size - 6))
    pos = {x, y}

    if Map.get(tiles, pos) == :walkable and far_enough_from_all?(pos, generators, 5) do
      Map.put(tiles, pos, :hole)
    else
      place_single_hole(tiles, generators, attempts + 1)
    end
  end

  defp convert_walls_to_mirrors(tiles) do
    tiles
    |> Enum.map(fn
      {pos, :wall} ->
        if :rand.uniform() < @mirror_conversion_rate do
          {pos, :mirror}
        else
          {pos, :wall}
        end

      other ->
        other
    end)
    |> Map.new()
  end

  defp calculate_spawn_points do
    margin = 5

    [
      {margin, margin},
      {@grid_size - 1 - margin, margin},
      {margin, @grid_size - 1 - margin},
      {@grid_size - 1 - margin, @grid_size - 1 - margin}
    ]
  end

  defp clear_spawn_areas(tiles, spawn_points) do
    Enum.reduce(spawn_points, tiles, fn {sx, sy}, acc_tiles ->
      for dx <- -@spawn_clear_radius..@spawn_clear_radius,
          dy <- -@spawn_clear_radius..@spawn_clear_radius,
          reduce: acc_tiles do
        acc ->
          pos = {sx + dx, sy + dy}

          if valid_position?(pos) do
            Map.put(acc, pos, :walkable)
          else
            acc
          end
      end
    end)
  end

  defp valid_position?({x, y}) do
    x >= 0 and x < @grid_size and y >= 0 and y < @grid_size
  end

  defp fill_unreachable_tiles(tiles, spawn_points) do
    # Get all reachable tiles from any spawn point
    reachable =
      Enum.reduce(spawn_points, MapSet.new(), fn spawn, acc ->
        flood_fill(tiles, spawn, acc)
      end)

    # Convert unreachable walkable tiles to walls
    tiles
    |> Enum.map(fn {pos, type} ->
      if type in [:walkable, :generator] and not MapSet.member?(reachable, pos) do
        {pos, :wall}
      else
        {pos, type}
      end
    end)
    |> Map.new()
  end

  defp connected?(tiles, spawn_points) do
    # Flood fill from first spawn point
    [first_spawn | rest] = spawn_points
    reachable = flood_fill(tiles, first_spawn, MapSet.new())

    # Check all other spawn points are reachable
    Enum.all?(rest, fn spawn -> MapSet.member?(reachable, spawn) end)
  end

  defp flood_fill(tiles, pos, visited) do
    if not valid_position?(pos) or MapSet.member?(visited, pos) do
      visited
    else
      tile = Map.get(tiles, pos)

      if tile in [:walkable, :generator] do
        visited = MapSet.put(visited, pos)
        {x, y} = pos

        neighbors = [
          {x + 1, y},
          {x - 1, y},
          {x, y + 1},
          {x, y - 1}
        ]

        Enum.reduce(neighbors, visited, fn neighbor, acc ->
          flood_fill(tiles, neighbor, acc)
        end)
      else
        visited
      end
    end
  end
end
