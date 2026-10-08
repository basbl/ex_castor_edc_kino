defmodule CastorEDC.Kino.ExportCell do
  @moduledoc false
  # A smart cell that lists a study's existing exports and downloads the
  # one picked. It never queues an export.

  use Kino.JS, assets_path: "lib/assets/export_cell"
  use Kino.JS.Live
  use Kino.SmartCell, name: "Castor EDC export download"

  alias CastorEDC.Kino.Binding

  @defaults %{
    "variable" => "export",
    "client" => "",
    "study" => "study_id",
    "export_id" => "",
    "export_label" => "",
    "into" => ""
  }

  @impl true
  def init(attrs, ctx) do
    fields = Map.merge(@defaults, Map.take(attrs, Map.keys(@defaults)))
    {:ok, assign(ctx, fields: fields, clients: %{}, studies: %{}, exports: [], status: nil)}
  end

  @impl true
  def handle_connect(ctx), do: {:ok, payload(ctx), ctx}

  @impl true
  def handle_event("update_field", %{"field" => "export_id", "value" => id}, ctx) do
    label = Enum.find_value(ctx.assigns.exports, "", &(&1.id == id && &1.label))
    {:noreply, ctx |> update_fields(%{"export_id" => id, "export_label" => label}) |> broadcast()}
  end

  def handle_event("update_field", %{"field" => field, "value" => value}, ctx) when field in ~w(client study) do
    {:noreply, ctx |> update_fields(%{field => value}) |> list_exports() |> broadcast()}
  end

  def handle_event("update_field", %{"field" => "variable", "value" => value}, ctx) do
    ctx = if Kino.SmartCell.valid_variable_name?(value), do: update_fields(ctx, %{"variable" => value}), else: ctx
    {:noreply, broadcast(ctx)}
  end

  def handle_event("update_field", %{"field" => "into", "value" => value}, ctx) do
    {:noreply, ctx |> update_fields(%{"into" => String.trim(value)}) |> broadcast()}
  end

  def handle_event("refresh", _payload, ctx), do: {:noreply, ctx |> list_exports() |> broadcast()}

  @impl true
  def handle_info({:binding, clients, studies}, ctx) do
    fields = ctx.assigns.fields

    fields =
      if Map.has_key?(clients, fields["client"]) or clients == %{},
        do: fields,
        else: Map.put(fields, "client", clients |> Map.keys() |> Enum.min())

    fields =
      if Map.has_key?(studies, fields["study"]) or studies == %{},
        do: fields,
        else: Map.put(fields, "study", studies |> Map.keys() |> Enum.min())

    ctx = assign(ctx, fields: fields, clients: clients, studies: studies)
    ctx = if ctx.assigns.exports == [], do: list_exports(ctx), else: ctx
    {:noreply, broadcast(ctx)}
  end

  def handle_info({:exports, key, result}, ctx) do
    ctx =
      if key == {ctx.assigns.fields["client"], ctx.assigns.fields["study"]} do
        case result do
          {:ok, []} ->
            assign(ctx, exports: [], status: "The study has no exports. Queue one with CastorEDC.Export first.")

          {:ok, exports} ->
            assign(ctx, exports: exports, status: nil)

          {:error, message} ->
            assign(ctx, exports: [], status: message)
        end
      else
        ctx
      end

    {:noreply, broadcast(ctx)}
  end

  @impl true
  def scan_binding(server, binding, _env) do
    send(server, {:binding, Binding.clients(binding), Binding.study_ids(binding)})
  end

  @impl true
  def to_attrs(ctx), do: ctx.assigns.fields

  @impl true
  def to_source(%{"export_id" => ""}), do: ""
  def to_source(%{"client" => ""}), do: ""

  def to_source(attrs) do
    export = Macro.var(String.to_atom(attrs["variable"]), nil)
    client = Macro.var(String.to_atom(attrs["client"]), nil)
    study = Macro.var(String.to_atom(attrs["study"]), nil)
    options = if attrs["into"] == "", do: [], else: [[into: attrs["into"]]]
    download = {{:., [], [CastorEDC.Export, :download]}, [], [client, study, export | options]}

    source =
      Kino.SmartCell.quoted_to_string(
        quote do
          {:ok, unquote(export)} = CastorEDC.Export.status(unquote(client), unquote(study), unquote(attrs["export_id"]))
          {:ok, unquote(export)} = unquote(download)
          unquote(export)
        end
      )

    if attrs["export_label"] in [nil, ""], do: source, else: "# #{attrs["export_label"]}\n" <> source
  end

  defp list_exports(ctx) do
    %{"client" => client_name, "study" => study_name} = ctx.assigns.fields

    with %{^client_name => client} <- ctx.assigns.clients,
         %{^study_name => study_id} <- ctx.assigns.studies do
      server = self()
      Task.start(fn -> send(server, {:exports, {client_name, study_name}, fetch_exports(client, study_id)}) end)
      assign(ctx, status: "Listing the exports…")
    else
      _missing -> ctx
    end
  end

  # The newest exports first, as the API lists them; only those that are
  # ready and not expired can be downloaded.
  defp fetch_exports(client, study_id) do
    case CastorEDC.Exports.list_exports(client, study_id, page_size: 100) do
      {:ok, page} -> {:ok, Enum.map(page.entries, &entry/1)}
      {:error, error} -> {:error, Exception.message(error)}
    end
  end

  defp entry(entry) do
    expired = entry.expires_on && DateTime.before?(entry.expires_on, DateTime.utc_now())
    ready = entry.status == "ready" and not expired
    state = if expired, do: "expired", else: entry.status

    parts = [
      "#{entry.type} (#{entry.format})",
      entry.created_on && Calendar.strftime(entry.created_on, "%-d %b %Y %H:%M"),
      state,
      entry.file_size && size(entry.file_size)
    ]

    %{id: entry.id, ready: ready, label: parts |> Enum.reject(&is_nil/1) |> Enum.join(" · ")}
  end

  defp size(bytes) when bytes >= 1_048_576, do: "#{Float.round(bytes / 1_048_576, 1)} MB"
  defp size(bytes) when bytes >= 1024, do: "#{Float.round(bytes / 1024, 1)} kB"
  defp size(bytes), do: "#{bytes} bytes"

  defp update_fields(ctx, changes), do: assign(ctx, fields: Map.merge(ctx.assigns.fields, changes))

  defp broadcast(ctx) do
    broadcast_event(ctx, "update", payload(ctx))
    ctx
  end

  defp payload(ctx) do
    %{
      fields: ctx.assigns.fields,
      clients: ctx.assigns.clients |> Map.keys() |> Enum.sort(),
      studies: ctx.assigns.studies |> Map.keys() |> Enum.sort(),
      exports: ctx.assigns.exports,
      status: ctx.assigns.status
    }
  end
end
