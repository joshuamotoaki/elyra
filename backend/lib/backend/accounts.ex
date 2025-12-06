defmodule Backend.Accounts do
  @moduledoc """
  The Accounts context for user management.
  """

  import Ecto.Query
  alias Backend.Repo
  alias Backend.Accounts.User

  def get_user(id), do: Repo.get(User, id)

  def get_user_by_google_id(google_id) do
    Repo.get_by(User, google_id: google_id)
  end

  def get_user_by_email(email) do
    Repo.get_by(User, email: email)
  end

  def find_or_create_from_google(auth_info) do
    case get_user_by_google_id(auth_info.uid) do
      nil -> create_from_google(auth_info)
      user -> {:ok, user}
    end
  end

  defp create_from_google(auth_info) do
    %User{}
    |> User.changeset(%{
      google_id: auth_info.uid,
      email: auth_info.info.email,
      name: auth_info.info.name,
      given_name: auth_info.info.first_name,
      family_name: auth_info.info.last_name,
      picture: auth_info.info.image
    })
    |> Repo.insert()
  end

  def set_username(user, username) do
    user
    |> User.username_changeset(%{username: username})
    |> Repo.update()
  end

  def username_available?(username) do
    query = from(u in User, where: u.username == ^username)
    !Repo.exists?(query)
  end
end
