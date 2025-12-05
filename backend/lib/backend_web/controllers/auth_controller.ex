defmodule BackendWeb.AuthController do
  use BackendWeb, :controller
  plug(Ueberauth)

  alias Backend.Accounts
  alias Backend.Guardian

  @frontend_url "http://localhost:3000"

  def request(conn, _params) do
    # Ueberauth redirects to Google OAuth automatically via the plug
    conn
  end

  # Google OAuth callback - success
  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    case Accounts.find_or_create_from_google(auth) do
      {:ok, user} ->
        {:ok, token, _claims} = Guardian.encode_and_sign(user, %{}, ttl: {7, :day})

        # Determine redirect based on onboarding status
        redirect_path = if user.username, do: "/dashboard", else: "/onboarding"

        redirect(conn,
          external: "#{@frontend_url}/auth/callback?token=#{token}&redirect=#{redirect_path}"
        )

      {:error, reason} ->
        redirect(conn, external: "#{@frontend_url}/auth/callback?error=#{reason}")
    end
  end

  # Google OAuth callback - failure
  def callback(%{assigns: %{ueberauth_failure: failure}} = conn, _params) do
    message = failure.errors |> Enum.map(& &1.message) |> Enum.join(", ")
    redirect(conn, external: "#{@frontend_url}/auth/callback?error=#{URI.encode(message)}")
  end
end
