defmodule CastorEDC.Kino do
  @moduledoc """
  Livebook integration for [ex_castor_edc](https://hexdocs.pm/ex_castor_edc).

  With this package installed, the library's results render in Livebook as
  something to read rather than raw terms:

    * a `CastorEDC.Page` as a table of its records
    * a record (a struct under `CastorEDC.Model`) as a tree
    * a `CastorEDC.Error` as its message and details

  Each keeps the raw term in a tab next to it. The functions below build
  the same views, to use them inside other layouts.

  The package only reads: nothing in it changes a study.
  """

  alias CastorEDC.Error
  alias CastorEDC.Page

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
