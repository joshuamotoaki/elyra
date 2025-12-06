defmodule BackendWeb.UserSocket do
  use Phoenix.Socket

  # Channels
  channel "match:*", BackendWeb.MatchChannel

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    case Backend.Guardian.decode_and_verify(token) do
      {:ok, claims} ->
        case Backend.Guardian.resource_from_claims(claims) do
          {:ok, user} ->
            {:ok, assign(socket, :current_user, user)}

          {:error, _reason} ->
            :error
        end

      {:error, _reason} ->
        :error
    end
  end

  def connect(_params, _socket, _connect_info), do: :error

  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.current_user.id}"
end
