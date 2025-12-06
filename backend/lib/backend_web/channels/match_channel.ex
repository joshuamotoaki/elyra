defmodule BackendWeb.MatchChannel do
  use BackendWeb, :channel

  alias Backend.Matches.MatchServer

  @impl true
  def join("match:" <> match_id_str, _params, socket) do
    user = socket.assigns.current_user
    match_id = String.to_integer(match_id_str)

    # Check if match server exists
    if MatchServer.exists?(match_id) do
      case MatchServer.join(match_id, user) do
        {:ok, state} ->
          send(self(), :after_join)
          {:ok, state, assign(socket, :match_id, match_id)}

        {:error, reason} ->
          {:error, %{reason: reason}}
      end
    else
      {:error, %{reason: "match_not_found"}}
    end
  end

  @impl true
  def handle_info(:after_join, socket) do
    # Subscribe to PubSub topic for this match
    Phoenix.PubSub.subscribe(Backend.PubSub, "match:#{socket.assigns.match_id}")
    {:noreply, socket}
  end

  # Handle PubSub broadcasts and forward to client
  @impl true
  def handle_info({event, payload}, socket) when is_binary(event) do
    push(socket, event, payload)
    {:noreply, socket}
  end

  @impl true
  def handle_info({event, payload}, socket) when is_atom(event) do
    push(socket, Atom.to_string(event), payload)
    {:noreply, socket}
  end

  @impl true
  def handle_in("start_game", _params, socket) do
    user_id = socket.assigns.current_user.id
    match_id = socket.assigns.match_id

    case MatchServer.start_game(match_id, user_id) do
      :ok ->
        {:reply, :ok, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  @impl true
  def handle_in("click_cell", %{"row" => row, "col" => col}, socket) do
    user_id = socket.assigns.current_user.id
    match_id = socket.assigns.match_id

    case MatchServer.click_cell(match_id, user_id, row, col) do
      :ok ->
        {:reply, :ok, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  @impl true
  def terminate(_reason, socket) do
    if Map.has_key?(socket.assigns, :match_id) do
      user_id = socket.assigns.current_user.id
      match_id = socket.assigns.match_id

      # Try to leave the match
      if MatchServer.exists?(match_id) do
        MatchServer.leave(match_id, user_id)
      end
    end

    :ok
  end
end
