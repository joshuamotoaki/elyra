defmodule BackendWeb.UserController do
  use BackendWeb, :controller

  alias Backend.Accounts

  action_fallback(BackendWeb.FallbackController)

  def me(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    render(conn, :show, user: user)
  end

  def set_username(conn, %{"username" => username}) do
    user = Guardian.Plug.current_resource(conn)

    case Accounts.set_username(user, username) do
      {:ok, updated_user} ->
        render(conn, :show, user: updated_user)

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def check_username(conn, %{"username" => username}) do
    available = Accounts.username_available?(username)
    json(conn, %{available: available, username: username})
  end
end
