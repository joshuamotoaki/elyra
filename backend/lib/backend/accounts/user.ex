defmodule Backend.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field(:google_id, :string)
    field(:email, :string)
    field(:name, :string)
    field(:given_name, :string)
    field(:family_name, :string)
    field(:picture, :string)
    field(:username, :string)
    field(:is_admin, :boolean, default: false)

    timestamps(type: :utc_datetime)
  end

  @required_fields [:google_id, :email]
  @optional_fields [:name, :given_name, :family_name, :picture, :username, :is_admin]

  def changeset(user, attrs) do
    user
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:google_id)
    |> unique_constraint(:email)
    |> unique_constraint(:username)
  end

  def username_changeset(user, attrs) do
    user
    |> cast(attrs, [:username])
    |> validate_required([:username])
    |> validate_length(:username, min: 3, max: 30)
    |> validate_format(:username, ~r/^[a-zA-Z0-9_]+$/,
      message: "only letters, numbers, and underscores allowed"
    )
    |> unique_constraint(:username)
  end
end
