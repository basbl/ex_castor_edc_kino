defmodule CastorEDC.Kino.ExportCellTest do
  use ExUnit.Case, async: true

  import Kino.Test

  alias CastorEDC.Kino.ExportCell

  setup :configure_livebook_bridge

  @study "8eff039f-df0a-4855-a850-4adeddfab4bd"

  defp php_date(date), do: %{"date" => date <> ".000000", "timezone_type" => 3, "timezone" => "UTC"}

  defp entry(id, type, status, expires) do
    %{
      "id" => id,
      "export_name" => type,
      "export_type" => "csv",
      "status" => status,
      "created_on" => php_date("2026-10-08 14:09:00"),
      "expires_on" => php_date(expires),
      "file_size" => 2048
    }
  end

  defp client(entries) do
    CastorEDC.Test.client(
      CastorEDC.Test.json(%{
        "_embedded" => %{"items" => entries},
        "page" => 1,
        "page_count" => 1,
        "total_items" => length(entries)
      })
    )
  end

  defp started(entries) do
    {kino, ""} = start_smart_cell!(ExportCell, %{})
    ExportCell.scan_binding(kino.pid, [client: client(entries), study_id: @study, other: "x"], __ENV__)
    kino
  end

  test "lists the study's exports, and only ready ones that haven't expired can be picked" do
    kino =
      started([
        entry("e-1", "participant_data", "ready", "2999-01-01 07:00:00"),
        entry("e-2", "sites", "queued", "2999-01-01 07:00:00"),
        entry("e-3", "sites", "ready", "2020-01-01 07:00:00")
      ])

    assert_broadcast_event(kino, "update", %{
      fields: %{"client" => "client", "study" => "study_id"},
      exports: [
        %{id: "e-1", ready: true, label: "participant_data (csv) · 8 Oct 2026 14:09 · ready · 2.0 kB"},
        %{id: "e-2", ready: false, label: "sites (csv) · 8 Oct 2026 14:09 · queued · 2.0 kB"},
        %{id: "e-3", ready: false, label: "sites (csv) · 8 Oct 2026 14:09 · expired · 2.0 kB"}
      ],
      status: nil
    })
  end

  test "downloads the picked export, in memory or into a directory" do
    kino = started([entry("e-1", "sites", "ready", "2999-01-01 07:00:00")])
    assert_broadcast_event(kino, "update", %{exports: [_export]})

    push_event(kino, "update_field", %{"field" => "export_id", "value" => "e-1"})

    assert_smart_cell_update(kino, %{"export_id" => "e-1"}, """
    # sites (csv) · 8 Oct 2026 14:09 · ready · 2.0 kB
    {:ok, export} = CastorEDC.Export.status(client, study_id, "e-1")
    {:ok, export} = CastorEDC.Export.download(client, study_id, export)
    export\
    """)

    push_event(kino, "update_field", %{"field" => "into", "value" => " exports/ "})
    assert_smart_cell_update(kino, %{"into" => "exports/"}, source)
    assert source =~ ~s{CastorEDC.Export.download(client, study_id, export, into: "exports/")}

    push_event(kino, "update_field", %{"field" => "variable", "value" => "bad name"})
    push_event(kino, "update_field", %{"field" => "variable", "value" => "sites"})
    assert_smart_cell_update(kino, %{"variable" => "sites"}, source)
    assert source =~ "{:ok, sites} = CastorEDC.Export.status"
  end

  test "says when the study has no exports, and lists them again on refresh" do
    kino = started([])

    assert_broadcast_event(kino, "update", %{
      exports: [],
      status: "The study has no exports. Queue one with CastorEDC.Export first."
    })

    push_event(kino, "refresh", %{})
    assert_broadcast_event(kino, "update", %{status: "Listing the exports…"})
  end

  test "shows why the exports couldn't be listed" do
    {kino, ""} = start_smart_cell!(ExportCell, %{})
    failing = CastorEDC.Test.client(CastorEDC.Test.json(%{"detail" => "Forbidden"}, status: 403))
    ExportCell.scan_binding(kino.pid, [client: failing, study_id: @study], __ENV__)
    assert_broadcast_event(kino, "update", %{exports: [], status: "Forbidden"})
  end

  test "generates nothing until an export is picked" do
    {_kino, source} = start_smart_cell!(ExportCell, %{"client" => "client"})
    assert source == ""
    assert ExportCell.to_source(%{"client" => "", "export_id" => "e-1"}) == ""
  end
end
