# CastorEDC.Kino

[Livebook](https://livebook.dev) integration for [ex_castor_edc](https://github.com/basbl/ex_castor_edc): the library's results render as tables and trees instead of raw terms.

It only reads: nothing in it changes a study.

## Installation

```elixir
Mix.install([
  {:ex_castor_edc_kino, "~> 0.1.0"}
])
```

## Usage

The **Castor EDC connection** smart cell builds a client: pick the server, and the Livebook secrets that hold your client ID and secret (`CASTOR_EDC_CLIENT_ID` and `CASTOR_EDC_CLIENT_SECRET` by default) or an access token. The credentials never appear in the notebook.

The **Castor EDC study** smart cell then lists the studies a client in the notebook can reach, and binds the ID of the one you pick (`study_id` by default).

With the package installed, results render by themselves:

```elixir
client = CastorEDC.new(client_id: "...", client_secret: "...")

# A table of the participants, with the raw page in a second tab.
CastorEDC.Participants.list_participants!(client, study_id)

# A tree of one participant.
CastorEDC.Participants.get_participant!(client, study_id, "110001")
```

Errors show their message, status, code and details, and exports a download for each file:

```elixir
{:ok, export} = CastorEDC.Export.participant_data(client, study_id, unzip: true)
export
```
Livebook prints `{:ok, result}` and `{:error, error}` as tuples, as it does any tuple: use the `!` functions, or match the value out, to see the views.
`CastorEDC.Kino.page/1`, `record/1`, `error/1`, `export/1` and `value/1` build the same views, to place them in other layouts.
