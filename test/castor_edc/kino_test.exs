defmodule CastorEDC.KinoTest do
  use ExUnit.Case, async: true

  import Kino.Test

  alias CastorEDC.Model.Participant
  alias CastorEDC.Model.Site
  alias Kino.JS.Live

  setup :configure_livebook_bridge

  @moduletag :tmp_dir

  @participant %Participant{
    id: "110001",
    participant_id: "110001",
    status: "open",
    progress: 50,
    created_on: ~U[2026-10-07 19:06:33Z],
    site: %Site{id: "site-1", name: "Amsterdam"}
  }

  describe "page/1" do
    test "shows the records as a table, with the page as its name" do
      page = %CastorEDC.Page{entries: [@participant], page: 2, page_count: 3, page_size: 1, total_items: 3}

      assert %Kino.Layout{type: :tabs, info: %{labels: ["Records", "Raw"]}, items: [table, raw]} =
               CastorEDC.Kino.page(page)

      assert %Live{} = table
      assert %Kino.Inspect{term: ^page} = raw

      data = connect(table)
      assert data.name == "Page 2 of 3 (3 in total)"
      labels = Enum.map(data.content.columns, & &1.label)
      assert ["id", "participant_id" | _others] = labels
      refute "extra" in labels

      row = Map.new(Enum.zip(labels, hd(data.content.data)))
      assert %{"site" => "site-1", "progress" => "50", "status" => "open"} = row
    end

    test "says when a page has no records" do
      page = %CastorEDC.Page{entries: [], page: 1, page_count: 0, total_items: 0}

      assert %Kino.Layout{items: [%Kino.Markdown{text: "_Page 1 of 0 (0 in total): no records._"}, _raw]} =
               CastorEDC.Kino.page(page)
    end
  end

  describe "record/1" do
    test "shows a record as a tree, without an empty extra" do
      assert %Kino.Layout{info: %{labels: ["Record", "Raw"]}, items: [tree, %Kino.Inspect{}]} =
               CastorEDC.Kino.record(@participant)

      assert %Kino.Layout{type: :grid, items: [%Kino.JS{module: Kino.Tree}]} = tree

      fields = CastorEDC.Kino.fields(@participant)
      assert %{site: %{name: "Amsterdam"}, created_on: ~U[2026-10-07 19:06:33Z]} = fields
      refute Map.has_key?(fields, :extra)
      refute Map.has_key?(fields.site, :extra)
      assert Map.has_key?(CastorEDC.Kino.fields(%{@participant | extra: %{"new" => 1}}), :extra)
    end
  end

  describe "error/1" do
    test "shows the message, the facts and the details" do
      error = %CastorEDC.Error{
        message: "Validation failed",
        status: 422,
        code: "VALIDATION_FAILED",
        request_id: "abc123",
        details: [%{code: "INVALID", message: "Name | too short", field: "name"}]
      }

      assert %Kino.Layout{info: %{labels: ["Error", "Raw"]}, items: [%Kino.Markdown{text: text}, _raw]} =
               CastorEDC.Kino.error(error)

      assert text =~ "**Validation failed**"
      assert text =~ "| Status | 422 |"
      assert text =~ "| Request ID | abc123 |"
      assert text =~ "- Name \\| too short (`name`)"
    end

    test "shows the reason of a request that got no answer" do
      error = %CastorEDC.Error{
        message: "connection refused",
        reason: %RuntimeError{message: "econnrefused"},
        code: :transport
      }

      assert %Kino.Layout{items: [%Kino.Markdown{text: text}, _raw]} = CastorEDC.Kino.error(error)
      assert text =~ "| Code | :transport |"
      assert text =~ "econnrefused"
    end
  end

  describe "data_points/1" do
    test "shows long rows in the order they describe, with readable values" do
      rows = [
        %{
          participant_id: "P1",
          site_id: "site-1",
          source: :study,
          instance_id: nil,
          parent_id: nil,
          field_id: "f-1",
          variable_name: "weight",
          value: CastorEDC.MissingValue.new(96),
          raw_value: "##USER_MISSING_96##",
          updated_on: ~N[2026-10-07 21:49:55]
        },
        %{
          participant_id: "P1",
          site_id: "site-1",
          source: :survey,
          instance_id: "si-1",
          parent_id: "s-1",
          field_id: "f-2",
          variable_name: "visit",
          value: %CastorEDC.PartialDate{year: 2020, month: 5},
          raw_value: "00-05-2020",
          updated_on: nil
        }
      ]

      table = CastorEDC.Kino.data_points(rows)
      data = connect(table)
      labels = Enum.map(data.content.columns, & &1.label)

      assert labels ==
               ~w(participant_id site_id source instance_id parent_id field_id variable_name value raw_value updated_on)

      [first, second] = Enum.map(data.content.data, &Map.new(Enum.zip(labels, &1)))
      assert %{"source" => "study", "value" => "Missing (96)"} = first
      assert %{"source" => "survey", "value" => "2020-05"} = second
    end
  end

  describe "frames/1" do
    test "puts the study's frame first, then the repeating data and surveys by name" do
      frames = %{
        study: "study frame",
        repeating_data: %{"Medication" => "m", "Blood pressure" => "b"},
        surveys: %{"GAD-7" => "g"}
      }

      assert %Kino.Layout{type: :tabs, info: %{labels: ["Study", "Blood pressure", "Medication", "GAD-7"]}, items: items} =
               CastorEDC.Kino.frames(frames)

      assert items == ["study frame", "b", "m", "g"]
    end
  end

  describe "export/1" do
    @export %CastorEDC.Export{
      id: "export-1",
      type: :sites,
      format: :csv,
      status: :ready,
      file_name: "sites.zip",
      file_size: 2048
    }

    test "summarises the export, with a download for its file" do
      assert %Kino.Layout{info: %{labels: ["Export", "Raw"]}, items: [view, _raw]} =
               CastorEDC.Kino.export(%{@export | data: "PK"})

      assert %Kino.Layout{type: :grid, items: [%Kino.Markdown{text: text}, %Live{module: Kino.Download}]} = view
      assert text =~ "| Type | sites |"
      assert text =~ "| Size | 2.0 kB |"
      refute text =~ "Saved in"
    end

    test "offers each unzipped file, in memory or on disk", %{tmp_dir: dir} do
      in_memory = %{@export | files: [{"sites.csv", "Site Id"}, {"meta/info.txt", "x"}]}

      assert %Kino.Layout{items: [%Kino.Layout{items: [_summary, _first, _second]}, _raw]} =
               CastorEDC.Kino.export(in_memory)

      path = Path.join(dir, "sites.csv")
      File.write!(path, "Site Id")
      on_disk = %{@export | path: dir, files: [path], file_size: 3_000_000}

      assert %Kino.Layout{items: [%Kino.Layout{items: [%Kino.Markdown{text: text}, _download]}, _raw]} =
               CastorEDC.Kino.export(on_disk)

      assert text =~ "| Size | 2.9 MB |"
      assert text =~ "| Saved in | #{dir} |"
    end

    test "offers a zip saved to disk, and nothing when there's no file", %{tmp_dir: dir} do
      zip = Path.join(dir, "sites.zip")
      File.write!(zip, "PK")

      assert %Kino.Layout{items: [%Kino.Layout{items: [_summary, _download]}, _raw]} =
               CastorEDC.Kino.export(%{@export | path: zip})

      assert %Kino.Layout{items: [%Kino.Layout{items: [_summary]}, _raw]} =
               CastorEDC.Kino.export(%{@export | status: :queued, file_size: 10})
    end
  end

  describe "value/1" do
    test "shows missing values and partial dates as text" do
      assert %Kino.Layout{items: [%Kino.Text{text: "Missing (not applicable), code 96"}, _raw]} =
               CastorEDC.Kino.value(CastorEDC.MissingValue.new(96))

      assert %Kino.Layout{items: [%Kino.Text{text: "2020-05"}, _raw]} =
               CastorEDC.Kino.value(%CastorEDC.PartialDate{year: 2020, month: 5})
    end
  end

  describe "rendering" do
    test "renders pages, records and errors as tabs" do
      for term <- [
            %CastorEDC.Page{entries: []},
            @participant,
            %CastorEDC.Error{message: "No"},
            %CastorEDC.Export{id: "export-1"},
            CastorEDC.MissingValue.new(95),
            %CastorEDC.PartialDate{year: 2020}
          ] do
        assert %{type: :tabs, labels: [_view, "Raw"]} = Kino.Render.to_livebook(term)
      end
    end
  end
end
