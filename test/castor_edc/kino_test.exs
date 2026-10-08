defmodule CastorEDC.KinoTest do
  use ExUnit.Case, async: true

  import Kino.Test

  alias CastorEDC.Model.Participant
  alias CastorEDC.Model.Site

  setup :configure_livebook_bridge

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

      assert %Kino.JS.Live{} = table
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

  describe "rendering" do
    test "renders pages, records and errors as tabs" do
      for term <- [%CastorEDC.Page{entries: []}, @participant, %CastorEDC.Error{message: "No"}] do
        assert %{type: :tabs, labels: [_view, "Raw"]} = Kino.Render.to_livebook(term)
      end
    end
  end
end
