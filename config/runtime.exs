import Config

if config_env() == :prod do
  app_name =
    System.get_env("FLY_APP_NAME") ||
      raise "FLY_APP_NAME not available"

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("HOST") || "#{app_name}.fly.dev"

  config :showcase, ShowcaseWeb.Endpoint,
    url: [host: host, port: 80],
    check_origin: [
      "https://jerrysitu.com:443",
      "https://www.jerrysitu.com:443"
    ],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: String.to_integer(System.get_env("PORT") || "4000")
    ],
    secret_key_base: secret_key_base

  config :showcase, ShowcaseWeb.Endpoint, server: true
end
