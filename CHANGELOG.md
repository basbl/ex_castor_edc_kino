# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### Added

- Pages render as a table of their records, records as a tree, and errors as their message, status, code and details, each with the raw term in a second tab.
  `CastorEDC.Kino.page/1`, `record/1` and `error/1` build the same views.
- Exports render as their type, format, status and size, with a download for their file or each unzipped file; values marked missing and partial dates render as text.
  `CastorEDC.Kino.export/1` and `value/1` build the same views.
- A connection smart cell: it builds a client for a Castor EDC server from Livebook secrets (a client ID and secret, or an access token), never from text in the notebook, and can test the connection by listing the studies it gives access to.
- A study smart cell: it finds the clients in the notebook, lists the studies the chosen one can reach, by name, and binds the ID of the one picked, with its name as a comment.
- A study data smart cell: it loads a study's values as rows (`CastorEDC.Tabular`) through the API, and shows them as a table.
  `CastorEDC.Kino.data_points/1` builds that view, and `frames/1` shows a study's frames in a tab each.
- `CastorEDC.Kino.study/2` shows a study's structure: its visits, forms and fields, then its repeating data and surveys, in the order the study shows them, with a searchable table of every field.
- A Livebook, `notebook/kino.livemd`, that connects, picks a study and looks around it with the smart cells and views.
- An export download smart cell: it lists a study's existing exports, newest first, and downloads the one picked, in memory or into a directory.
  It never queues an export.
