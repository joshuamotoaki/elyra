defmodule BackendWeb.Router do
  use BackendWeb, :router

  pipeline :api do
    plug(:accepts, ["json"])
  end

  pipeline :browser do
    plug(:accepts, ["html", "json"])
    plug(:fetch_session)
  end

  pipeline :authenticated do
    plug(BackendWeb.AuthPipeline)
  end

  scope "/api" do
    pipe_through(:api)

    get("/openapi", OpenApiSpex.Plug.RenderSpec, [])
  end

  scope "/api/swagger" do
    forward("/", OpenApiSpex.Plug.SwaggerUI, path: "/api/openapi")
  end

  # OAuth routes (needs session for CSRF state)
  scope "/api/auth", BackendWeb do
    pipe_through(:browser)

    get("/:provider", AuthController, :request)
    get("/:provider/callback", AuthController, :callback)
  end

  # Public API routes
  scope "/api", BackendWeb do
    pipe_through(:api)

    get("/users/check-username", UserController, :check_username)
  end

  # Protected API routes
  scope "/api", BackendWeb do
    pipe_through([:api, :authenticated])

    get("/users/me", UserController, :me)
    put("/users/username", UserController, :set_username)
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:backend, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through([:fetch_session, :protect_from_forgery])

      live_dashboard("/dashboard", metrics: BackendWeb.Telemetry)
      forward("/mailbox", Plug.Swoosh.MailboxPreview)
    end
  end
end
