defmodule Ueberauth.Strategy.Wordpress do
  @moduledoc """
  Wordpress Strategy for Überauth.
  """

  use Ueberauth.Strategy, uid_field: :ID, default_scope: "email profile"

  alias Ueberauth.Auth.Info
  alias Ueberauth.Auth.Credentials
  alias Ueberauth.Auth.Extra

  @doc """
  Handles initial request for Wordpress authentication.
  """
  def handle_request!(conn) do
    scopes = conn.params["scope"] || option(conn, :default_scope)
    opts = [scope: scopes]
    opts = if conn.params["state"] do
      Keyword.put(opts, :state, conn.params["state"])
    else
      opts
    end
    opts = Keyword.put(opts, :redirect_uri, callback_url(conn))

    redirect!(conn, Ueberauth.Strategy.Wordpress.OAuth.authorize_url!(opts))
  end

  @doc false
  def handle_callback!(%Plug.Conn{params: %{"code" => code}} = conn) do
    opts = [redirect_uri: callback_url(conn)]
    token = Ueberauth.Strategy.Wordpress.OAuth.get_token!([code: code], opts)

    if token.access_token == nil do
      err = token.other_params["error"]
      desc = token.other_params["error_description"]
      set_errors!(conn, [error(err, desc)])
    else
      conn
      |> store_token(token)
      |> fetch_user(token)
    end
  end

  @doc false
  def handle_callback!(conn) do
    set_errors!(conn, [error("missing_code", "No code received")])
  end

  @doc false
  def handle_cleanup!(conn) do
    conn
    |> put_private(:wp_token, nil)
    |> put_private(:wp_user, nil)
  end

  # Store the token for later use.
  @doc false
  defp store_token(conn, token) do
    put_private(conn, :wp_token, token)
  end

  defp fetch_user(conn, token) do
    config = Application.get_env(:ueberauth, Ueberauth.Strategy.Wordpress.OAuth)
    host = Keyword.get(config, :host)
    url = "#{host}/oauth/me/"
    resp = Ueberauth.Strategy.Wordpress.OAuth.get(token, url)

    case resp do
      {:ok, %OAuth2.Response{status_code: 401, body: _body}} ->
        set_errors!(conn, [error("token", "unauthorized")])
      {:ok, %OAuth2.Response{status_code: status_code, body: user}}
        when status_code in 200..399 ->
        put_private(conn, :wp_user, user)
      {:error, %OAuth2.Error{reason: reason}} ->
        set_errors!(conn, [error("OAuth2", reason)])
    end
  end

  defp split_scopes(token) do
    (token.other_params["scope"] || "")
    |> String.split(" ")
  end


  @doc """
  Includes the credentials from the Wordpress response.
  """
  def credentials(conn) do
    token = conn.private.wp_token
    scopes = split_scopes(token)

    %Credentials{
      expires: !!token.expires_at,
      expires_at: token.expires_at,
      scopes: scopes,
      refresh_token: token.refresh_token,
      token: token.access_token
    }
  end

  @doc """
  Fetches the fields to populate the info section of the `Ueberauth.Auth` struct.
  """
  def info(conn) do
    user = conn.private.wp_user

    %Info{
      email: user["email"],
      name: user["display_name"],
    }
  end

  @doc """
  Stores the raw information (including the token and user)
  obtained from the Wordpress callback.
  """
  def extra(conn) do
    %{
      wp_token: :token,
      wp_user: :user,
    }
    |> Enum.filter_map(fn {original_key, _} ->
      Map.has_key?(conn.private, original_key)
      end,
      fn {original_key, mapped_key} ->
        {mapped_key, Map.fetch!(conn.private, original_key)}
      end)
    |> Map.new()
    |> (&(%Extra{raw_info: &1})).()
  end

  @doc """
  Fetches the uid field from the response.
  """
  def uid(conn) do
    uid_field =
      conn
      |> option(:uid_field)
      |> to_string

    conn.private.wp_user[uid_field]
  end

  defp option(conn, key) do
    Dict.get(options(conn), key, Dict.get(default_options, key))
  end

end
