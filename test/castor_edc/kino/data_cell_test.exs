defmodule CastorEDC.Kino.DataCellTest do
  use ExUnit.Case, async: true

  import Kino.Test

  alias CastorEDC.Kino.DataCell

  setup :configure_livebook_bridge

  @attrs %{
    "variable" => "data",
    "client" => "client",
    "study" => "study_id",
    "library" => "rows",
    "source" => "api",
    "format" => "long",
    "sources" => ~w(study repeating_data survey),
    "missing_columns" => false
  }

  defp source(attrs), do: DataCell.to_source(Map.merge(@attrs, attrs))

  describe "the code it generates" do
    test "streams rows into a table" do
      assert source(%{}) == """
             data = client |> CastorEDC.Tabular.data_points(study_id) |> Enum.to_list()
             CastorEDC.Kino.data_points(data)\
             """

      assert source(%{"sources" => ["survey", "study"]}) =~
               "CastorEDC.Tabular.data_points(study_id, sources: [:study, :survey])"
    end

    test "loads Explorer or Dux frames through the API" do
      assert source(%{"library" => "explorer"}) == """
             {:ok, data} = CastorEDC.Explorer.data_points(client, study_id)
             data\
             """

      wide = source(%{"library" => "dux", "format" => "wide", "missing_columns" => true, "sources" => ["study"]})
      assert wide =~ "CastorEDC.Kino.frames(data)"

      assert wide =~
               "CastorEDC.Dux.data_points(client, study_id,\n    format: :wide,\n    missing_columns: true,\n    sources: [:study]\n  )"
    end

    test "loads frames from a participant data export" do
      assert source(%{"library" => "explorer", "source" => "export", "missing_columns" => true}) =~
               "CastorEDC.Explorer.participant_data(client, study_id, missing_columns: true)"

      assert source(%{"library" => "dux", "source" => "export"}) ==
               """
               {:ok, data} = CastorEDC.Dux.participant_data(client, study_id)
               CastorEDC.Kino.frames(data)\
               """
    end

    test "waits for a client" do
      assert source(%{"client" => ""}) == ""
    end
  end

  describe "the cell" do
    test "picks the client and study ID variables from the binding" do
      {kino, ""} = start_smart_cell!(DataCell, %{})

      binding = [
        other: 1,
        trial: "8eff039f-df0a-4855-a850-4adeddfab4bd",
        name: "not an id",
        client: CastorEDC.Test.client(CastorEDC.Test.json(%{}))
      ]

      DataCell.scan_binding(kino.pid, binding, __ENV__)

      assert_broadcast_event(kino, "update", %{
        clients: ["client"],
        studies: ["trial"],
        fields: %{"client" => "client", "study" => "trial"}
      })
    end

    test "offers only the libraries that are installed" do
      {kino, _source} = start_smart_cell!(DataCell, @attrs)
      assert %{libraries: [%{value: "rows"}]} = connect(kino)
    end

    test "updates its fields, and ignores values it can't use" do
      {kino, _source} = start_smart_cell!(DataCell, @attrs)

      push_event(kino, "update_field", %{"field" => "sources", "value" => []})
      assert_broadcast_event(kino, "update", %{fields: %{"sources" => ~w(study repeating_data survey)}})

      push_event(kino, "update_field", %{"field" => "library", "value" => "excel"})
      assert_broadcast_event(kino, "update", %{fields: %{"library" => "rows"}})

      push_event(kino, "update_field", %{"field" => "variable", "value" => "values"})
      push_event(kino, "update_field", %{"field" => "sources", "value" => ["study"]})

      assert_smart_cell_update(kino, %{"variable" => "values", "sources" => ["study"]}, source)
      assert source =~ "values =\n"
      assert source =~ "CastorEDC.Tabular.data_points(study_id, sources: [:study])"
      assert source =~ "CastorEDC.Kino.data_points(values)"
    end
  end
end
