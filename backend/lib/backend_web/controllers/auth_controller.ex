defmodule BackendWeb.AuthController do
  use BackendWeb, :controller
  plug(Ueberauth)

  alias Backend.Accounts
  alias Backend.Guardian

  defp frontend_url do
    System.get_env("FRONTEND_URL") || "http://localhost:3000"
  end

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
        redirect_path = if user.username, do: "/lobby", else: "/onboarding"

        conn
        |> put_resp_cookie("auth_token", token, http_only: true, max_age: 7 * 24 * 60 * 60)
        |> redirect(
          external: "#{frontend_url()}/auth/callback?token=#{token}&redirect=#{redirect_path}"
        )

      {:error, reason} ->
        redirect(conn, external: "#{frontend_url()}/auth/callback?error=#{reason}")
    end
  end

  # Google OAuth callback - failure
  def callback(%{assigns: %{ueberauth_failure: failure}} = conn, _params) do
    message = failure.errors |> Enum.map(& &1.message) |> Enum.join(", ")
    redirect(conn, external: "#{frontend_url()}/auth/callback?error=#{URI.encode(message)}")
  end
end
