defmodule BackendWeb.AuthPipeline do
  use Guardian.Plug.Pipeline,
    otp_app: :backend,
    module: Backend.Guardian,
    error_handler: BackendWeb.AuthErrorHandler

  plug(Guardian.Plug.VerifyHeader, scheme: "Bearer")
  plug(Guardian.Plug.EnsureAuthenticated)
  plug(Guardian.Plug.LoadResource)
end

defmodule BackendWeb.AuthErrorHandler do
  import Plug.Conn

  @behaviour Guardian.Plug.ErrorHandler

  @impl true
  def auth_error(conn, {type, _reason}, _opts) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(401, Jason.encode!(%{error: to_string(type)}))
  end
end
