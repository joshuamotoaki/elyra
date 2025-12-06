defmodule Backend.Matches.Match do
  use Ecto.Schema
  import Ecto.Changeset

  schema "matches" do
    field :code, :string
    field :status, :string, default: "waiting"
    field :is_public, :boolean, default: true
    field :final_state, :map

    belongs_to :host, Backend.Accounts.User
    belongs_to :winner, Backend.Accounts.User
    has_many :match_players, Backend.Matches.MatchPlayer
    has_many :players, through: [:match_players, :user]

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(match, attrs) do
    match
    |> cast(attrs, [
      :code,
      :status,
      :is_public,
      :final_state,
      :host_id,
      :winner_id
    ])
    |> validate_required([:code, :host_id])
    |> validate_inclusion(:status, ["waiting", "playing", "finished"])
    |> unique_constraint(:code)
    |> foreign_key_constraint(:host_id)
    |> foreign_key_constraint(:winner_id)
  end

  @doc false
  def finish_changeset(match, attrs) do
    match
    |> cast(attrs, [:status, :winner_id, :final_state])
    |> validate_required([:status])
  end
end
