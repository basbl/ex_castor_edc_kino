defmodule CastorEDC.Kino.ConnectionCell do
  @moduledoc false
  # A smart cell that builds a client: the server, and credentials or an
  # access token from Livebook secrets, never as text in the notebook.

  use Kino.JS, assets_path: "lib/assets/connection_cell"
  use Kino.JS.Live
  use Kino.SmartCell, name: "Castor EDC connection"

  @servers [
    %{value: "https://data.castoredc.com", label: "Netherlands (data.castoredc.com)"},
    %{value: "https://uk.castoredc.com", label: "United Kingdom (uk.castoredc.com)"},
    %{value: "https://us.castoredc.com", label: "United States (us.castoredc.com)"},
    %{value: "https://au.castoredc.com", label: "Australia (au.castoredc.com)"},
    %{value: "custom", label: "Another server"}
  ]

  @defaults %{
    "variable" => "client",
    "server" => "https://data.castoredc.com",
    "custom_server" => "",
    "auth" => "credentials",
    "client_id_secret" => "CASTOR_EDC_CLIENT_ID",
    "client_secret_secret" => "CASTOR_EDC_CLIENT_SECRET",
    "access_token_secret" => "CASTOR_EDC_ACCESS_TOKEN"
  }

  @impl true
  def init(attrs, ctx) do
    fields = Map.merge(@defaults, Map.take(attrs, Map.keys(@defaults)))
    {:ok, assign(ctx, fields: fields, test: nil)}
  end

  @impl true
  def handle_connect(ctx) do
    fields = ctx.assigns.fields
    {:ok, %{fields: fields, servers: @servers, test: ctx.assigns.test, warning: warning(fields)}, ctx}
  end

  @impl true
  def handle_event("update_field", %{"field" => field, "value" => value}, ctx) when is_map_key(@defaults, field) do
    fields =
      if field == "variable" and not Kino.SmartCell.valid_variable_name?(value),
        do: ctx.assigns.fields,
        else: Map.put(ctx.assigns.fields, field, value)

    broadcast_event(ctx, "update", %{"fields" => fields, "warning" => warning(fields)})
    {:noreply, assign(ctx, fields: fields, test: nil)}
  end

  def handle_event("test", _payload, ctx) do
    test = test(ctx.assigns.fields)
    broadcast_event(ctx, "test", test)
    {:noreply, assign(ctx, test: test)}
  end

  @impl true
  def to_attrs(ctx), do: ctx.assigns.fields

  @impl true
  def to_source(attrs) do
    options = Enum.map(credentials(attrs), fn {key, secret} -> {key, fetch_env(secret)} end) ++ [base_url: server(attrs)]

    quote_result =
      quote do
        unquote(Macro.var(String.to_atom(attrs["variable"]), nil)) = CastorEDC.new(unquote(options))
      end

    Kino.SmartCell.quoted_to_string(quote_result)
  end

  defp credentials(%{"auth" => "token"} = attrs), do: [access_token: attrs["access_token_secret"]]

  defp credentials(attrs), do: [client_id: attrs["client_id_secret"], client_secret: attrs["client_secret_secret"]]

  defp fetch_env(secret) do
    quote do: System.fetch_env!(unquote("LB_" <> secret))
  end

  defp server(%{"server" => "custom", "custom_server" => url}), do: String.trim(url)
  defp server(%{"server" => url}), do: url

  # Picking the same secret for the client ID and the secret is an easy
  # slip in the secret picker, and the API only says the credentials are
  # wrong.
  defp warning(%{"auth" => "credentials", "client_id_secret" => same, "client_secret_secret" => same}) do
    "The client ID and the client secret both come from the secret #{same}; pick the secret that holds each."
  end

  defp warning(_fields), do: nil

  defp test(fields) do
    case warning(fields) do
      nil -> list_studies(fields)
      warning -> %{"ok" => false, "message" => warning}
    end
  end

  # Builds the client the source would, from the secrets this notebook has,
  # and lists its studies.
  defp list_studies(fields) do
    secrets = credentials(fields)

    case Enum.reject(secrets, fn {_key, secret} -> System.get_env("LB_" <> secret) end) do
      [] ->
        options = Enum.map(secrets, fn {key, secret} -> {key, System.get_env("LB_" <> secret)} end)
        options = options ++ [base_url: server(fields)] ++ Application.get_env(:ex_castor_edc_kino, :client_options, [])

        case options |> CastorEDC.new() |> CastorEDC.Studies.list_studies() do
          {:ok, page} -> %{"ok" => true, "message" => "Connected: #{studies(length(page.entries))} available."}
          {:error, error} -> %{"ok" => false, "message" => Exception.message(error)}
        end

      missing ->
        names = Enum.map_join(missing, " and ", fn {_key, secret} -> secret end)
        %{"ok" => false, "message" => "This notebook has no secret #{names}; add it in the notebook's secrets."}
    end
  end

  defp studies(1), do: "1 study"
  defp studies(count), do: "#{count} studies"
end
