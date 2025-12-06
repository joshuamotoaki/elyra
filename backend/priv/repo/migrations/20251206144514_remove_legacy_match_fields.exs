defmodule Backend.Repo.Migrations.RemoveLegacyMatchFields do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      remove :grid_size, :integer, default: 4
      remove :duration_seconds, :integer, default: 30
    end
  end
end
