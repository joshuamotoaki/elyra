defmodule Backend.Repo.Migrations.AddIsPublicToMatches do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      add :is_public, :boolean, default: true, null: false
    end
  end
end
