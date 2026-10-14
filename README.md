# CastorEDC.Kino

[Livebook](https://livebook.dev) integration for [ex_castor_edc](https://hexdocs.pm/ex_castor_edc): smart cells to connect to Castor EDC, pick a study and load its data, and views that show the library's results as tables and trees instead of raw terms.

It only reads: nothing in it changes a study.

## Installation

```elixir
Mix.install([
  {:ex_castor_edc_kino, "~> 0.1.0"}
])
```

## Smart cells

- **Castor EDC connection** builds a client from Livebook secrets (`CASTOR_EDC_CLIENT_ID` and `CASTOR_EDC_CLIENT_SECRET` by default, or an access token), so credentials never appear in the notebook.
- **Castor EDC study** lists the studies a client in the notebook can reach, and binds the ID of the one you pick.
- **Castor EDC study data** loads the study's values as rows, through the API.
- **Castor EDC export download** lists the study's existing exports and downloads the one you pick; it never queues an export.

## Views

With the package installed, results render by themselves: a page as a table, a record as a tree, an error as its message and details, and an export with a download for each file.

```elixir
CastorEDC.Participants.list_participants!(client, study_id)
```

Livebook shows `{:ok, result}` as a plain tuple, so use the `!` functions, or match the result out, to see the views.
`CastorEDC.Kino.study(client, study_id)` shows a study's visits, forms and fields, then its repeating data and surveys.

## Contributing

See [CONTRIBUTING.md](https://github.com/basbl/ex_castor_edc_kino/blob/main/CONTRIBUTING.md).

## License

MIT; see [LICENSE.md](https://github.com/basbl/ex_castor_edc_kino/blob/main/LICENSE.md).
