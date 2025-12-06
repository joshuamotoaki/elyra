defmodule Backend.Matches.MatchPlayer do
  use Ecto.Schema
  import Ecto.Changeset

  schema "match_players" do
    field :color, :string
    field :score, :integer, default: 0
    field :joined_at, :utc_datetime

    belongs_to :match, Backend.Matches.Match
    belongs_to :user, Backend.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(match_player, attrs) do
    match_player
    |> cast(attrs, [:match_id, :user_id, :color, :score, :joined_at])
    |> validate_required([:match_id, :user_id, :color, :joined_at])
    |> unique_constraint([:match_id, :user_id])
    |> foreign_key_constraint(:match_id)
    |> foreign_key_constraint(:user_id)
  end

  @doc false
  def score_changeset(match_player, attrs) do
    match_player
    |> cast(attrs, [:score])
  end
end
