defmodule Backend.Repo.Migrations.AddIsSoloToMatches do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      add :is_solo, :boolean, null: false, default: false
    end
  end
end
