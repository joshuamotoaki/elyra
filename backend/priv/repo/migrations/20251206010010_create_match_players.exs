defmodule Backend.Repo.Migrations.CreateMatchPlayers do
  use Ecto.Migration

  def change do
    create table(:match_players) do
      add :match_id, references(:matches, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :color, :string, null: false
      add :score, :integer, default: 0
      add :joined_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:match_players, [:match_id, :user_id])
    create index(:match_players, [:user_id])
  end
end
