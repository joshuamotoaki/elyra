defmodule Backend.Matches do
  @moduledoc """
  Context for match persistence. Handles database operations only.
  Live game state is managed by MatchServer GenServer.
  """

  import Ecto.Query
  alias Backend.Repo
  alias Backend.Matches.{Match, MatchPlayer}
  alias Backend.Accounts.User

  # Player colors for assignment
  @colors ["#3B82F6", "#EF4444", "#22C55E", "#F59E0B"]

  @doc """
  Generate a unique 6-character join code.
  """
  def generate_code do
    code = for _ <- 1..6, into: "", do: <<Enum.random(?A..?Z)>>

    if Repo.exists?(from m in Match, where: m.code == ^code and m.status != "finished") do
      generate_code()
    else
      code
    end
  end

  @doc """
  Create a new match with the given user as host.
  """
  def create_match(%User{} = host, attrs \\ %{}) do
    code = generate_code()

    %Match{}
    |> Match.changeset(Map.merge(attrs, %{code: code, host_id: host.id}))
    |> Repo.insert()
  end

  @doc """
  Get a match by ID.
  """
  def get_match(id) do
    Repo.get(Match, id)
  end

  @doc """
  Get a match by ID, raises if not found.
  """
  def get_match!(id) do
    Repo.get!(Match, id)
  end

  @doc """
  Get a match by ID with preloaded associations.
  """
  def get_match_with_players(id) do
    Match
    |> where([m], m.id == ^id)
    |> preload([:host, :winner, match_players: :user])
    |> Repo.one()
  end

  @doc """
  Find an active match by its code.
  """
  def get_match_by_code(code) do
    Match
    |> where([m], m.code == ^code and m.status != "finished")
    |> preload([:host, match_players: :user])
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      match -> {:ok, match}
    end
  end

  @doc """
  List all public matches with status "waiting" that have at least one player.
  """
  def list_available_matches do
    # Subquery to get match IDs that have players
    matches_with_players =
      from(mp in MatchPlayer,
        select: mp.match_id,
        distinct: true
      )

    Match
    |> where([m], m.status == "waiting" and m.is_public == true and m.is_solo == false)
    |> where([m], m.id in subquery(matches_with_players))
    |> preload([:host, match_players: :user])
    |> order_by([m], desc: m.inserted_at)
    |> Repo.all()
  end

  @doc """
  Clean up stale matches:
  - Waiting matches older than 30 minutes
  - Playing matches older than 1 hour (stuck games)
  """
  def cleanup_stale_matches do
    now = DateTime.utc_now()
    waiting_cutoff = DateTime.add(now, -30, :minute)
    playing_cutoff = DateTime.add(now, -60, :minute)

    # Get stale match IDs for logging
    stale_matches =
      Match
      |> where([m], m.status == "waiting" and m.inserted_at < ^waiting_cutoff)
      |> or_where([m], m.status == "playing" and m.inserted_at < ^playing_cutoff)
      |> select([m], m.id)
      |> Repo.all()

    if length(stale_matches) > 0 do
      # Mark as finished
      Match
      |> where([m], m.id in ^stale_matches)
      |> Repo.update_all(set: [status: "finished", updated_at: now])

      # Stop any running MatchServer processes
      Enum.each(stale_matches, fn match_id ->
        case Registry.lookup(Backend.MatchRegistry, match_id) do
          [{pid, _}] -> GenServer.stop(pid, :normal)
          [] -> :ok
        end
      end)

      {:ok, length(stale_matches)}
    else
      {:ok, 0}
    end
  end

  @doc """
  Add a player to a match.
  """
  def add_player(%Match{} = match, %User{} = user) do
    # Check if already in match
    existing =
      MatchPlayer
      |> where([mp], mp.match_id == ^match.id and mp.user_id == ^user.id)
      |> Repo.one()

    if existing do
      {:ok, existing}
    else
      # Get player count to assign color
      player_count =
        MatchPlayer
        |> where([mp], mp.match_id == ^match.id)
        |> Repo.aggregate(:count)

      if player_count >= 4 do
        {:error, :match_full}
      else
        color = Enum.at(@colors, player_count)

        %MatchPlayer{}
        |> MatchPlayer.changeset(%{
          match_id: match.id,
          user_id: user.id,
          color: color,
          joined_at: DateTime.utc_now()
        })
        |> Repo.insert()
      end
    end
  end

  @doc """
  Remove a player from a match.
  """
  def remove_player(%Match{} = match, %User{} = user) do
    MatchPlayer
    |> where([mp], mp.match_id == ^match.id and mp.user_id == ^user.id)
    |> Repo.delete_all()
  end

  @doc """
  Get a player's info in a match.
  """
  def get_match_player(match_id, user_id) do
    MatchPlayer
    |> where([mp], mp.match_id == ^match_id and mp.user_id == ^user_id)
    |> preload(:user)
    |> Repo.one()
  end

  @doc """
  Get all players in a match.
  """
  def get_match_players(match_id) do
    MatchPlayer
    |> where([mp], mp.match_id == ^match_id)
    |> preload(:user)
    |> Repo.all()
  end

  @doc """
  Update match status.
  """
  def update_match_status(%Match{} = match, status) do
    match
    |> Match.changeset(%{status: status})
    |> Repo.update()
  end

  @doc """
  Finish a match with final results.
  """
  def finish_match(match_id, winner_id, final_state, player_scores) do
    match = get_match!(match_id)

    # Update match
    {:ok, _match} =
      match
      |> Match.finish_changeset(%{
        status: "finished",
        winner_id: winner_id,
        final_state: final_state
      })
      |> Repo.update()

    # Update player scores (round to integer since score field is integer)
    Enum.each(player_scores, fn {user_id, score} ->
      rounded_score = round(score)

      MatchPlayer
      |> where([mp], mp.match_id == ^match_id and mp.user_id == ^user_id)
      |> Repo.update_all(set: [score: rounded_score])
    end)

    :ok
  end

  @doc """
  Count players in a match.
  """
  def count_players(match_id) do
    MatchPlayer
    |> where([mp], mp.match_id == ^match_id)
    |> Repo.aggregate(:count)
  end
end
