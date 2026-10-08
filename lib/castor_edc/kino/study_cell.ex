defmodule CastorEDC.Kino.StudyCell do
  @moduledoc false
  # A smart cell that picks a study by name from those a client in the
  # notebook can reach, and binds its ID.

  use Kino.JS, assets_path: "lib/assets/study_cell"
  use Kino.JS.Live
  use Kino.SmartCell, name: "Castor EDC study"

  @fields ~w(client study_id study_name variable)

  @impl true
  def init(attrs, ctx) do
    fields = %{
      "client" => attrs["client"] || "",
      "study_id" => attrs["study_id"] || "",
      "study_name" => attrs["study_name"] || "",
      "variable" => attrs["variable"] || "study_id"
    }

    {:ok, assign(ctx, fields: fields, clients: %{}, studies: [], status: nil)}
  end

  @impl true
  def handle_connect(ctx) do
    {:ok, payload(ctx), ctx}
  end

  @impl true
  def handle_event("update_field", %{"field" => "client", "value" => name}, ctx) do
    ctx = ctx |> update_fields(%{"client" => name}) |> list_studies()
    {:noreply, broadcast(ctx)}
  end

  def handle_event("update_field", %{"field" => "study_id", "value" => id}, ctx) do
    name = Enum.find_value(ctx.assigns.studies, "", &(&1.id == id && &1.name))
    {:noreply, ctx |> update_fields(%{"study_id" => id, "study_name" => name}) |> broadcast()}
  end

  def handle_event("update_field", %{"field" => "variable", "value" => variable}, ctx) do
    ctx = if Kino.SmartCell.valid_variable_name?(variable), do: update_fields(ctx, %{"variable" => variable}), else: ctx
    {:noreply, broadcast(ctx)}
  end

  def handle_event("refresh", _payload, ctx) do
    {:noreply, ctx |> list_studies() |> broadcast()}
  end

  @impl true
  def handle_info({:clients, clients}, ctx) do
    ctx = assign(ctx, clients: clients)
    selected = ctx.assigns.fields["client"]

    ctx =
      cond do
        Map.has_key?(clients, selected) and ctx.assigns.studies != [] -> ctx
        Map.has_key?(clients, selected) -> list_studies(ctx)
        clients == %{} -> ctx
        true -> ctx |> update_fields(%{"client" => clients |> Map.keys() |> Enum.min()}) |> list_studies()
      end

    {:noreply, broadcast(ctx)}
  end

  def handle_info({:studies, client, result}, ctx) do
    ctx =
      if client == ctx.assigns.fields["client"] do
        case result do
          {:ok, studies} -> assign(ctx, studies: studies, status: nil)
          {:error, message} -> assign(ctx, studies: [], status: message)
        end
      else
        ctx
      end

    {:noreply, broadcast(ctx)}
  end

  @impl true
  def scan_binding(server, binding, _env) do
    clients = for {name, value} <- binding, is_atom(name), client?(value), into: %{}, do: {Atom.to_string(name), value}
    send(server, {:clients, clients})
  end

  @impl true
  def to_attrs(ctx), do: Map.take(ctx.assigns.fields, @fields)

  @impl true
  def to_source(%{"study_id" => ""}), do: ""

  def to_source(attrs) do
    source =
      Kino.SmartCell.quoted_to_string(
        quote do
          unquote(Macro.var(String.to_atom(attrs["variable"]), nil)) = unquote(attrs["study_id"])
        end
      )

    if attrs["study_name"] in [nil, ""], do: source, else: "# #{attrs["study_name"]}\n" <> source
  end

  # The clients CastorEDC.new/1 builds carry the library's user agent.
  defp client?(%Req.Request{options: %{user_agent: "ex_castor_edc/" <> _version}}), do: true
  defp client?(_value), do: false

  defp list_studies(ctx) do
    name = ctx.assigns.fields["client"]

    case ctx.assigns.clients do
      %{^name => client} ->
        server = self()

        Task.start(fn -> send(server, {:studies, name, fetch_studies(client)}) end)

        assign(ctx, status: "Listing the studies…")

      _none ->
        ctx
    end
  end

  defp fetch_studies(client) do
    case CastorEDC.Studies.list_studies(client) do
      {:ok, page} ->
        studies = Enum.map(page.entries, &%{id: &1.study_id, name: &1.name})
        {:ok, Enum.sort_by(studies, &String.downcase(&1.name || ""))}

      {:error, error} ->
        {:error, Exception.message(error)}
    end
  end

  defp update_fields(ctx, changes), do: assign(ctx, fields: Map.merge(ctx.assigns.fields, changes))

  defp broadcast(ctx) do
    broadcast_event(ctx, "update", payload(ctx))
    ctx
  end

  defp payload(ctx) do
    %{
      fields: ctx.assigns.fields,
      clients: ctx.assigns.clients |> Map.keys() |> Enum.sort(),
      studies: ctx.assigns.studies,
      status: ctx.assigns.status
    }
  end
end
