# Überauth Wordpress

> Wordpress OAuth2 strategy for Überauth based on [ueberauth_discord](https://github.com/schwarz/ueberauth_discord)

For additional documentation on Wordpress's OAuth implementation see [wordpress-oauth-server](https://github.com/justingreerbbi/wordpress-oauth-server) and [wp-oauth.com](https://wp-oauth.com).

## Installation


1. Add `:ueberauth_wordpress` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:ueberauth_wordpress, "~> 0.0.1"}]
    end
    ```

1. Add the strategy to your applications:

    ```elixir
    def application do
      [applications: [:ueberauth_wordpress]]
    end
    ```

1. Add Wordpress to your Überauth configuration:

    ```elixir
    config :ueberauth, Ueberauth,
      providers: [
        wordpress: {Ueberauth.Strategy.Wordpress, []}
      ]
    ```

1.  Update your provider configuration:

    ```elixir
    config :ueberauth, Ueberauth.Strategy.Wordpress.OAuth,
      client_id: System.get_env("WORDPRESS_CLIENT_ID"),
      client_secret: System.get_env("WORDPRESS_CLIENT_SECRET"),
      host: System.get_env("WORDPRESS_HOST")
    ```

1.  Include the Überauth plug in your controller:

    ```elixir
    defmodule MyApp.AuthController do
      use MyApp.Web, :controller
      plug Ueberauth
      ...
    end
    ```

1.  Create the request and callback routes if you haven't already:

    ```elixir
    scope "/auth", MyApp do
      pipe_through :browser

      get "/:provider", AuthController, :request
      get "/:provider/callback", AuthController, :callback
    end
    ```

1. Your controller needs to implement callbacks to deal with `Ueberauth.Auth` and `Ueberauth.Failure` responses.

For an example implementation see the [Überauth Example](https://github.com/ueberauth/ueberauth_example) application.

## License

Please see [LICENSE](https://github.com/schwarz/ueberauth_discrod/blob/master/LICENSE) for licensing details.
