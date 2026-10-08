defmodule CastorEDC.Kino do
  @moduledoc """
  Livebook integration for [ex_castor_edc](https://hexdocs.pm/ex_castor_edc).

  With this package installed, the library's results render in Livebook as
  something to read rather than raw terms:

    * a `CastorEDC.Page` as a table of its records
    * a record (a struct under `CastorEDC.Model`) as a tree
    * a `CastorEDC.Error` as its message and details
    * a `CastorEDC.Export` as a summary with a download per file
    * a `CastorEDC.MissingValue` or `CastorEDC.PartialDate` as text

  Each keeps the raw term in a tab next to it. The functions below build
  the same views, to use them inside other layouts.

  The package only reads: nothing in it changes a study.
  """

  alias CastorEDC.Error
  alias CastorEDC.Export
  alias CastorEDC.MissingValue
  alias CastorEDC.Page
  alias CastorEDC.PartialDate

  @doc """
  A page of records as a table, with its page counters as the table's
  name, and the raw page in a second tab.

  Nested records show as their ID or name, and lists as their length.
  """
  @spec page(Page.t()) :: Kino.Layout.t()
  def page(%Page{} = page) do
    rows = Enum.map(page.entries, &row/1)
    name = "Page #{page.page} of #{page.page_count} (#{page.total_items} in total)"

    table =
      if rows == [],
        do: Kino.Markdown.new("_#{name}: no records._"),
        else: Kino.DataTable.new(rows, name: name, keys: keys(rows))

    Kino.Layout.tabs(Records: table, Raw: Kino.Inspect.new(page))
  end

  @doc """
  Rows from `CastorEDC.Tabular.data_points/3`, in the long format, as a
  table with its columns in the order the rows describe: whose value it
  is, where it was collected, the field, then the value.
  """
  @spec data_points(Enumerable.t()) :: Kino.JS.Live.t()
  def data_points(rows) do
    keys = ~w(participant_id site_id source instance_id parent_id field_id variable_name value raw_value updated_on)
    table = Enum.map(rows, fn row -> Map.new(row, fn {key, value} -> {to_string(key), data_cell(value)} end) end)
    Kino.DataTable.new(table, name: "Data points", keys: keys)
  end

  @doc """
  The frames of a study, as the Explorer and Dux packages give them in the
  wide format (`%{study: frame, repeating_data: %{name => frame},
  surveys: %{name => frame}}`), in a tab each.
  """
  @spec frames(%{study: term(), repeating_data: map(), surveys: map()}) :: Kino.Layout.t()
  def frames(%{study: study, repeating_data: repeating_data, surveys: surveys}) do
    tabs =
      [{"Study", study}] ++
        Enum.sort_by(repeating_data, &elem(&1, 0)) ++ Enum.sort_by(surveys, &elem(&1, 0))

    Kino.Layout.tabs(tabs)
  end

  @doc """
  A record as a tree, without its `extra` field when that's empty, and
  the raw record in a second tab.
  """
  @spec record(struct()) :: Kino.Layout.t()
  def record(%_module{} = record) do
    Kino.Layout.tabs(Record: Kino.Tree.new(fields(record)), Raw: Kino.Inspect.new(record))
  end

  @doc false
  # The record as the tree shows it: its fields, nested records as maps,
  # without empty extras.
  @spec fields(struct()) :: map()
  def fields(%_module{} = record), do: tree(record)

  @doc """
  An error as its message, with its status, code, request ID and details,
  and the raw error in a second tab.
  """
  @spec error(Error.t()) :: Kino.Layout.t()
  def error(%Error{} = error) do
    sections = [
      "**#{escape(Exception.message(error))}**",
      facts(error),
      details(error)
    ]

    markdown = sections |> Enum.reject(&(&1 == "")) |> Enum.join("\n\n")
    Kino.Layout.tabs(Error: Kino.Markdown.new(markdown), Raw: Kino.Inspect.new(error))
  end

  @doc """
  An export as its type, format, status and size, with a download button
  for its file, or for each file when it was unzipped, and the raw export
  in a second tab.

  Files on disk are read when their button is pressed, not before.
  """
  @spec export(Export.t()) :: Kino.Layout.t()
  def export(%Export{} = export) do
    summary =
      [
        {"Type", export.type},
        {"Format", export.format},
        {"Status", export.status},
        {"File", export.file_name},
        {"Size", export.file_size && size(export.file_size)},
        {"Expires", export.expires_on},
        {"Saved in", export.path}
      ]
      |> Enum.reject(fn {_label, value} -> is_nil(value) end)
      |> Enum.map(fn {label, value} -> "| #{label} | #{escape(to_string(value))} |" end)

    markdown = Kino.Markdown.new(Enum.join(["| | |", "| --- | --- |" | summary], "\n"))
    view = Kino.Layout.grid([markdown | downloads(export)])

    Kino.Layout.tabs(Export: view, Raw: Kino.Inspect.new(export))
  end

  @doc """
  A value marked missing, or a partial date, as text, and the raw value in
  a second tab.
  """
  @spec value(MissingValue.t() | PartialDate.t()) :: Kino.Layout.t()
  def value(%MissingValue{code: code, reason: reason} = value) do
    text = "Missing (#{reason |> Atom.to_string() |> String.replace("_", " ")}), code #{code}"
    Kino.Layout.tabs(Value: Kino.Text.new(text), Raw: Kino.Inspect.new(value))
  end

  def value(%PartialDate{} = value) do
    Kino.Layout.tabs(Value: Kino.Text.new(PartialDate.to_iso8601(value)), Raw: Kino.Inspect.new(value))
  end

  defp downloads(%Export{files: [_file | _more] = files, path: path}) do
    Enum.map(files, fn
      {name, contents} -> Kino.Download.new(fn -> contents end, filename: Path.basename(name), label: name)
      file -> Kino.Download.new(fn -> File.read!(file) end, filename: Path.basename(file), label: relative(file, path))
    end)
  end

  defp downloads(%Export{data: data} = export) when is_binary(data),
    do: [Kino.Download.new(fn -> data end, filename: export.file_name || "#{export.id}.zip")]

  defp downloads(%Export{path: path}) when is_binary(path) do
    if File.regular?(path),
      do: [Kino.Download.new(fn -> File.read!(path) end, filename: Path.basename(path))],
      else: []
  end

  defp downloads(_export), do: []

  defp relative(file, nil), do: Path.basename(file)
  defp relative(file, dir), do: Path.relative_to(file, dir)

  defp size(bytes) when bytes >= 1_048_576, do: "#{Float.round(bytes / 1_048_576, 1)} MB"
  defp size(bytes) when bytes >= 1024, do: "#{Float.round(bytes / 1024, 1)} kB"
  defp size(bytes), do: "#{bytes} bytes"

  defp data_cell(%MissingValue{} = value), do: "Missing (#{value.code})"
  defp data_cell(%PartialDate{} = value), do: PartialDate.to_iso8601(value)
  defp data_cell(value) when is_atom(value) and not is_nil(value) and not is_boolean(value), do: Atom.to_string(value)

  defp data_cell(value) when is_tuple(value) or is_list(value) or (is_map(value) and not is_struct(value)),
    do: inspect(value)

  defp data_cell(value), do: value

  defp facts(error) do
    rows =
      [
        {"Status", error.status},
        {"Code", error.code && code(error.code)},
        {"Request ID", error.request_id},
        {"Retry after", error.retry_after && "#{error.retry_after} s"},
        {"Reason", error.reason && Exception.format_banner(:error, error.reason)}
      ]
      |> Enum.reject(fn {_label, value} -> value in [nil, ""] end)
      |> Enum.map(fn {label, value} -> "| #{label} | #{escape(to_string(value))} |" end)

    if rows == [], do: "", else: Enum.join(["| | |", "| --- | --- |" | rows], "\n")
  end

  defp details(error) do
    Enum.map_join(error.details || [], "\n", fn detail ->
      field = if detail[:field], do: " (`#{detail[:field]}`)", else: ""
      "- #{escape(to_string(detail[:message] || detail[:code]))}#{field}"
    end)
  end

  # A record as a table row: scalars as they are, nested records by their
  # ID or name, lists by their length.
  defp row(%_module{} = record), do: record |> Map.from_struct() |> Map.delete(:extra) |> row()
  defp row(map) when is_map(map), do: Map.new(map, fn {key, value} -> {to_string(key), cell(value)} end)

  defp cell(%module{} = value) when module in [Date, Time, NaiveDateTime, DateTime], do: value
  defp cell(%_module{} = record), do: Map.get(record, :id) || Map.get(record, :name) || inspect(record)
  defp cell(list) when is_list(list), do: length(list)
  defp cell(map) when is_map(map), do: inspect(map)
  defp cell(value), do: value

  # The columns in alphabetical order, the IDs first.
  defp keys([first | _rest]) do
    {ids, others} = first |> Map.keys() |> Enum.split_with(&(&1 in ["id", "participant_id"]))
    Enum.sort(ids) ++ Enum.sort(others)
  end

  defp tree(%module{} = value) when module in [Date, Time, NaiveDateTime, DateTime], do: value

  defp tree(%_module{} = record) do
    fields = Map.from_struct(record)
    fields = if Map.get(fields, :extra) == %{}, do: Map.delete(fields, :extra), else: fields
    Map.new(fields, fn {key, value} -> {key, tree(value)} end)
  end

  defp tree(list) when is_list(list), do: Enum.map(list, &tree/1)
  defp tree(map) when is_map(map), do: Map.new(map, fn {key, value} -> {key, tree(value)} end)
  defp tree(value), do: value

  defp code(code) when is_atom(code), do: inspect(code)
  defp code(code), do: code

  defp escape(text), do: String.replace(text, "|", "\\|")
end
