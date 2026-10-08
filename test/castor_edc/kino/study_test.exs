defmodule CastorEDC.Kino.StudyTest do
  use ExUnit.Case, async: true

  import Kino.Test

  setup :configure_livebook_bridge

  defp page(key, items), do: CastorEDC.Test.json(%{"_embedded" => %{key => items}, "page" => 1, "page_count" => 1})

  defp field(id, type, parent, number, attrs \\ %{}) do
    Map.merge(
      %{
        "id" => id,
        "field_type" => type,
        "field_variable_name" => id,
        "field_label" => "Label #{id}",
        "field_number" => number,
        "parent_id" => parent
      },
      attrs
    )
  end

  defp client(fields) do
    routes = %{
      "/field" => page("fields", fields),
      "/form" =>
        page("forms", [
          %{
            "id" => "form-2",
            "form_name" => "Outcome",
            "form_order" => 1,
            "_embedded" => %{"visit" => %{"id" => "v-2", "visit_name" => "Follow-up", "visit_order" => 2}}
          },
          %{
            "id" => "form-1",
            "form_name" => "Baseline",
            "form_order" => 1,
            "_embedded" => %{"visit" => %{"id" => "v-1", "visit_name" => "Screening", "visit_order" => 1}}
          }
        ]),
      "/repeating-data" => page("repeatingData", [%{"id" => "rd-1", "name" => "Blood pressure"}]),
      "/repeating-data/rd-1/repeating-data-form" =>
        page("repeating_data_forms", [%{"id" => "rd-form", "repeating_data_form_name" => "Measurement"}]),
      "/survey" => page("surveys", [])
    }

    CastorEDC.Test.client(fn request ->
      Map.fetch!(routes, String.replace_prefix(request.url.path, "/api/study/s-1", ""))
    end)
  end

  test "outlines the study in its own order, and tables its fields" do
    fields = [
      field("outcome", "radio", "form-2", 1, %{"option_group" => %{"id" => "og-1", "name" => "Outcomes"}}),
      field("weight", "numeric", "form-1", 2, %{"field_label" => "Weight | kg"}),
      field("year", "year", "form-1", 1),
      field("note", "remark", "form-1", 3),
      field("systolic", "numeric", "rd-form", 1)
    ]

    assert %Kino.Layout{type: :tabs, info: %{labels: ["Structure", "Fields"]}, items: [%Kino.Markdown{text: text}, table]} =
             CastorEDC.Kino.study(client(fields), "s-1")

    assert text == """
           ### Visits

           - **Screening**
             - Baseline
               - `year` Label year (year)
               - `weight` Weight \\| kg (numeric)
           - **Follow-up**
             - Outcome
               - `outcome` Label outcome (radio, Outcomes)

           ### Repeating data

           - **Blood pressure**
             - Measurement
               - `systolic` Label systolic (numeric)\
           """

    data = connect(table)

    assert Enum.map(data.content.columns, & &1.label) ==
             ~w(variable_name label field_type context parent form option_group field_id)

    assert length(data.content.data) == 4
  end

  test "says when the study has no fields" do
    assert %Kino.Layout{items: [%Kino.Markdown{text: "_The study has no fields that hold values._"}, _table]} =
             CastorEDC.Kino.study(client([]), "s-1")
  end

  test "raises the error of a failed request" do
    client = CastorEDC.Test.client(CastorEDC.Test.json(%{"detail" => "Forbidden"}, status: 403))
    assert_raise CastorEDC.Error, ~r/Forbidden/, fn -> CastorEDC.Kino.study(client, "s-1") end
  end
end
