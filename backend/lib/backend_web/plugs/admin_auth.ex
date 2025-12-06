defmodule BackendWeb.AdminAuth do
  @moduledoc """
  Stateless admin auth using JWT from cookie.
  """
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    with {:ok, token} <- get_token_from_cookie(conn),
         {:ok, user, _claims} <- Backend.Guardian.resource_from_token(token),
         true <- user.is_admin do
      conn
    else
      _ ->
        conn
        |> put_status(:unauthorized)
        |> text("Unauthorized: Admin access required")
        |> halt()
    end
  end

  defp get_token_from_cookie(conn) do
    case conn.cookies["auth_token"] do
      nil -> {:error, :no_token}
      token -> {:ok, token}
    end
  end
end
