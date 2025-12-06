defmodule BackendWeb.UserJSON do
  alias Backend.Accounts.User

  def show(%{user: user}) do
    %{data: data(user)}
  end

  defp data(%User{} = user) do
    %{
      id: user.id,
      email: user.email,
      name: user.name,
      username: user.username,
      picture: user.picture,
      is_admin: user.is_admin
    }
  end
end
