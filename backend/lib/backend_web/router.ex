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

  pipeline :admin do
    plug(:fetch_cookies)
    plug(BackendWeb.AdminAuth)
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
  end

  # Protected API routes
  scope "/api", BackendWeb do
    pipe_through([:api, :authenticated])

    get("/users/me", UserController, :me)
    get("/users/check-username", UserController, :check_username)
    put("/users/username", UserController, :set_username)

    # Match routes
    get("/matches", MatchController, :index)
    post("/matches", MatchController, :create)
    get("/matches/:id", MatchController, :show)
    post("/matches/join", MatchController, :join_by_code)
  end

  # LiveDashboard - protected by admin auth
  import Phoenix.LiveDashboard.Router

  scope "/admin" do
    pipe_through(:admin)

    live_dashboard("/dashboard", metrics: BackendWeb.Telemetry)
  end
end
