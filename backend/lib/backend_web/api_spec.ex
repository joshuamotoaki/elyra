defmodule BackendWeb.ApiSpec do
  alias OpenApiSpex.{Info, OpenApi, Paths, Server}
  alias BackendWeb.{Endpoint, Router}
  @behaviour OpenApi

  @impl true
  def spec do
    %OpenApi{
      servers: [Server.from_endpoint(Endpoint)],
      info: %Info{
        title: "Elyra API",
        version: "1.0"
      },
      paths: Paths.from_router(Router)
    }
    |> OpenApiSpex.resolve_schema_modules()
  end
end
