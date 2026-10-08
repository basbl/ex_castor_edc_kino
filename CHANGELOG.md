# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### Added

- Pages render as a table of their records, records as a tree, and errors as their message, status, code and details, each with the raw term in a second tab. `CastorEDC.Kino.page/1`, `record/1` and `error/1` build the same views.
