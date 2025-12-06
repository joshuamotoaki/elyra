defmodule BackendWeb.MatchJSON do
  alias Backend.Matches.Match

  @doc """
  Renders a list of matches.
  """
  def index(%{matches: matches}) do
    %{data: for(match <- matches, do: data(match))}
  end

  @doc """
  Renders a single match.
  """
  def show(%{match: match}) do
    %{data: data(match)}
  end

  defp data(%Match{} = match) do
    %{
      id: match.id,
      code: match.code,
      status: match.status,
      is_public: match.is_public,
      is_solo: match.is_solo,
      host_id: match.host_id,
      host: host_data(match.host),
      player_count: length(match.match_players || []),
      players: players_data(match.match_players),
      winner_id: match.winner_id,
      inserted_at: match.inserted_at,
      updated_at: match.updated_at
    }
  end

  defp host_data(nil), do: nil

  defp host_data(host) do
    %{
      id: host.id,
      username: host.username,
      name: host.name,
      picture: host.picture
    }
  end

  defp players_data(nil), do: []

  defp players_data(match_players) do
    for mp <- match_players do
      %{
        user_id: mp.user_id,
        username: mp.user.username || mp.user.name,
        picture: mp.user.picture,
        color: mp.color,
        score: mp.score
      }
    end
  end
end
