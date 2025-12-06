defmodule Backend.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      # Google OAuth fields
      add(:google_id, :string, null: false)
      add(:email, :string, null: false)

      # Profile fields from Google
      add(:name, :string)
      add(:given_name, :string)
      add(:family_name, :string)
      add(:picture, :string)

      # App-specific fields
      add(:username, :string)
      add(:is_admin, :boolean, default: false, null: false)

      timestamps(type: :utc_datetime)
    end

    create(unique_index(:users, [:google_id]))
    create(unique_index(:users, [:email]))
    create(unique_index(:users, [:username]))
  end
end
