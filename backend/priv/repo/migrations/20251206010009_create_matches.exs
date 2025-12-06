defmodule Backend.Repo.Migrations.CreateMatches do
  use Ecto.Migration

  def change do
    create table(:matches) do
      add :code, :string, null: false
      add :host_id, references(:users, on_delete: :nilify_all), null: false
      add :status, :string, null: false, default: "waiting"
      add :grid_size, :integer, null: false, default: 4
      add :duration_seconds, :integer, null: false, default: 30
      add :winner_id, references(:users, on_delete: :nilify_all)
      add :final_state, :map

      timestamps(type: :utc_datetime)
    end

    create unique_index(:matches, [:code], where: "status != 'finished'")
    create index(:matches, [:status])
    create index(:matches, [:host_id])
  end
end
