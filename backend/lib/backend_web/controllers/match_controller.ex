defmodule BackendWeb.MatchController do
  use BackendWeb, :controller

  alias Backend.Matches
  alias Backend.Matches.MatchSupervisor

  action_fallback(BackendWeb.FallbackController)

  @doc """
  GET /api/matches
  List all available (waiting) matches.
  """
  def index(conn, _params) do
    matches = Matches.list_available_matches()
    render(conn, :index, matches: matches)
  end

  @doc """
  POST /api/matches
  Create a new match and start the game server.
  """
  def create(conn, params) do
    user = Guardian.Plug.current_resource(conn)

    is_solo = Map.get(params, "is_solo", false)

    attrs = %{
      # Solo matches are always private
      is_public: if(is_solo, do: false, else: Map.get(params, "is_public", true)),
      is_solo: is_solo
    }

    with {:ok, match} <- Matches.create_match(user, attrs),
         {:ok, _mp} <- Matches.add_player(match, user),
         {:ok, _pid} <- MatchSupervisor.start_match(match.id) do
      match = Matches.get_match_with_players(match.id)
      render(conn, :show, match: match)
    end
  end

  @doc """
  GET /api/matches/:id
  Get a specific match by ID.
  """
  def show(conn, %{"id" => id}) do
    case Matches.get_match_with_players(id) do
      nil -> {:error, :not_found}
      match -> render(conn, :show, match: match)
    end
  end

  @doc """
  POST /api/matches/join
  Join a match by its code.
  """
  def join_by_code(conn, %{"code" => code}) do
    user = Guardian.Plug.current_resource(conn)

    with {:ok, match} <- Matches.get_match_by_code(String.upcase(code)),
         {:ok, _mp} <- Matches.add_player(match, user) do
      # Ensure match server is running
      unless Backend.Matches.MatchServer.exists?(match.id) do
        MatchSupervisor.start_match(match.id)
      end

      match = Matches.get_match_with_players(match.id)
      render(conn, :show, match: match)
    else
      {:error, :not_found} -> {:error, :not_found}
      {:error, :match_full} -> {:error, :match_full}
      error -> error
    end
  end
end
