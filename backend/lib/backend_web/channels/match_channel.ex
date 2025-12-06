defmodule BackendWeb.MatchChannel do
  @moduledoc """
  Channel for real-time match communication.
  Handles player input, shooting, power-up purchases, and state broadcasts.
  """
  use BackendWeb, :channel

  alias Backend.Matches.MatchServer

  @impl true
  def join("match:" <> match_id_str, _params, socket) do
    user = socket.assigns.current_user
    match_id = String.to_integer(match_id_str)

    if MatchServer.exists?(match_id) do
      Phoenix.PubSub.subscribe(Backend.PubSub, "match:#{match_id}")

      case MatchServer.join(match_id, user) do
        {:ok, state} ->
          {:ok, state, assign(socket, :match_id, match_id)}

        {:error, reason} ->
          # Unsubscribe on error
          Phoenix.PubSub.unsubscribe(Backend.PubSub, "match:#{match_id}")
          {:error, %{reason: reason}}
      end
    else
      {:error, %{reason: "match_not_found"}}
    end
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

  # Handle player input (WASD)
  @impl true
  def handle_in("input", input, socket) do
    user_id = socket.assigns.current_user.id
    match_id = socket.assigns.match_id

    MatchServer.update_input(match_id, user_id, input)
    {:noreply, socket}
  end

  # Handle shooting a beam
  @impl true
  def handle_in("shoot", %{"direction_x" => dir_x, "direction_y" => dir_y}, socket) do
    user_id = socket.assigns.current_user.id
    match_id = socket.assigns.match_id

    MatchServer.shoot(match_id, user_id, dir_x, dir_y)
    {:noreply, socket}
  end

  # Handle power-up purchase
  @impl true
  def handle_in("buy_powerup", %{"type" => powerup_type}, socket) do
    user_id = socket.assigns.current_user.id
    match_id = socket.assigns.match_id

    case MatchServer.buy_powerup(match_id, user_id, powerup_type) do
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

      if MatchServer.exists?(match_id) do
        MatchServer.leave(match_id, user_id)
      end
    end

    :ok
  end
end
