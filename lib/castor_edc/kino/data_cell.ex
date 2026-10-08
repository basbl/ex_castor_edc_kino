defmodule CastorEDC.Kino.DataCell do
  @moduledoc false
  # A smart cell that loads a study's data: as rows with CastorEDC.Tabular,
  # or as frames with the Explorer or Dux packages when they're installed,
  # through the API or a participant data export.

  use Kino.JS, assets_path: "lib/assets/data_cell"
  use Kino.JS.Live
  use Kino.SmartCell, name: "Castor EDC study data"

  alias CastorEDC.Kino.Binding

  @libraries [
    %{value: "rows", label: "Rows (CastorEDC.Tabular)", module: CastorEDC.Tabular},
    %{value: "explorer", label: "Explorer", module: CastorEDC.Explorer},
    %{value: "dux", label: "Dux", module: CastorEDC.Dux}
  ]

  @all_sources ~w(study repeating_data survey)

  @defaults %{
    "variable" => "data",
    "client" => "",
    "study" => "study_id",
    "library" => "rows",
    "source" => "api",
    "format" => "long",
    "sources" => @all_sources,
    "missing_columns" => false
  }

  @impl true
  def init(attrs, ctx) do
    libraries = for library <- @libraries, Code.ensure_loaded?(library.module), do: Map.delete(library, :module)
    fields = Map.merge(@defaults, Map.take(attrs, Map.keys(@defaults)))
    {:ok, assign(ctx, fields: fields, libraries: libraries, clients: [], studies: [])}
  end

  @impl true
  def handle_connect(ctx), do: {:ok, payload(ctx), ctx}

  @impl true
  def handle_event("update_field", %{"field" => field, "value" => value}, ctx) when is_map_key(@defaults, field) do
    ctx = if valid?(field, value), do: assign(ctx, fields: Map.put(ctx.assigns.fields, field, value)), else: ctx
    broadcast_event(ctx, "update", payload(ctx))
    {:noreply, ctx}
  end

  @impl true
  def handle_info({:binding, clients, studies}, ctx) do
    fields = ctx.assigns.fields
    fields = if fields["client"] in clients or clients == [], do: fields, else: Map.put(fields, "client", hd(clients))
    fields = if fields["study"] in studies or studies == [], do: fields, else: Map.put(fields, "study", hd(studies))

    ctx = assign(ctx, fields: fields, clients: clients, studies: studies)
    broadcast_event(ctx, "update", payload(ctx))
    {:noreply, ctx}
  end

  @impl true
  def scan_binding(server, binding, _env) do
    clients = binding |> Binding.clients() |> Map.keys() |> Enum.sort()
    send(server, {:binding, clients, binding |> Binding.study_ids() |> Map.keys() |> Enum.sort()})
  end

  @impl true
  def to_attrs(ctx), do: ctx.assigns.fields

  @impl true
  def to_source(%{"client" => ""}), do: ""

  def to_source(attrs) do
    variable = Macro.var(String.to_atom(attrs["variable"]), nil)
    client = Macro.var(String.to_atom(attrs["client"]), nil)
    study = Macro.var(String.to_atom(attrs["study"]), nil)

    attrs
    |> quoted(variable, client, study)
    |> Kino.SmartCell.quoted_to_string()
  end

  defp quoted(%{"library" => "rows"} = attrs, variable, client, study) do
    call = {{:., [], [CastorEDC.Tabular, :data_points]}, [], arguments([study], sources(attrs))}

    quote do
      unquote(variable) = unquote(client) |> unquote(call) |> Enum.to_list()
      CastorEDC.Kino.data_points(unquote(variable))
    end
  end

  defp quoted(%{"library" => library} = attrs, variable, client, study) do
    module = if library == "dux", do: CastorEDC.Dux, else: CastorEDC.Explorer
    {function, options} = frame_call(attrs)

    call = {{:., [], [module, function]}, [], arguments([client, study], options)}

    show =
      if attrs["source"] == "export" or attrs["format"] == "wide",
        do: quote(do: CastorEDC.Kino.frames(unquote(variable))),
        else: variable

    quote do
      {:ok, unquote(variable)} = unquote(call)
      unquote(show)
    end
  end

  # Arguments, with the options last unless there are none.
  defp arguments(arguments, []), do: arguments
  defp arguments(arguments, options), do: arguments ++ [options]

  defp frame_call(%{"source" => "export"} = attrs), do: {:participant_data, missing_columns(attrs)}

  defp frame_call(%{"format" => "wide"} = attrs),
    do: {:data_points, [format: :wide] ++ missing_columns(attrs) ++ sources(attrs)}

  defp frame_call(attrs), do: {:data_points, sources(attrs)}

  defp missing_columns(%{"missing_columns" => true}), do: [missing_columns: true]
  defp missing_columns(_attrs), do: []

  defp sources(%{"sources" => sources}) do
    if Enum.sort(sources) == Enum.sort(@all_sources),
      do: [],
      else: [sources: for(source <- @all_sources, source in sources, do: String.to_atom(source))]
  end

  defp valid?("variable", value), do: Kino.SmartCell.valid_variable_name?(value)
  defp valid?("sources", value), do: is_list(value) and value != [] and Enum.all?(value, &(&1 in @all_sources))
  defp valid?("missing_columns", value), do: is_boolean(value)
  defp valid?("library", value), do: value in ~w(rows explorer dux)
  defp valid?("source", value), do: value in ~w(api export)
  defp valid?("format", value), do: value in ~w(long wide)
  defp valid?(_field, value), do: is_binary(value)

  defp payload(ctx) do
    %{
      fields: ctx.assigns.fields,
      libraries: ctx.assigns.libraries,
      clients: ctx.assigns.clients,
      studies: ctx.assigns.studies
    }
  end
end
