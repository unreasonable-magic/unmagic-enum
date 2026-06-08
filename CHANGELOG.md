# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-06-09

### Added
- `column_type(validate:)` option mirroring `ActiveRecord::Enum`. Defaults to `false` (an unknown value raises eagerly on assignment, as before); pass `validate: true` to suppress the eager raise so the value casts to `nil` and model validations (`presence`/`inclusion`) handle it instead.

## [0.1.1] - 2026-06-04

### Changed
- Relaxed `activesupport` dependency to `>= 7.0` (removed upper bound) so the gem installs against Rails 8 and future majors

## [0.1.0] - 2026-06-04

### Added
- Initial release
- `Unmagic::Enum` base class for defining type-safe, immutable enums backed by string values
- Custom attributes via `attribute :name`, with `default:` values and `alias:` reader names
- Key/value separation (`new("entity", value: "bot")`) for mapping code identifiers to differing database values
- Support for symbols, integers, and classes as keys (preserving original type), enabling clean STI integration
- Dynamic query methods (`status.active?`) for checking enum keys
- Lookups by key or value with `Enum[...]`, plus `all`, `keys`, `values`, and `valid?` helpers
- Duplicate key and value detection, and reserved-method conflict detection, raised at definition time
- `InvalidValueError` raised on invalid assignment, mirroring Rails enum behaviour
- ActiveRecord integration: `Enum.column_type` for serialization, casting, and eager validation in `attribute` declarations
- Rails presence support (`blank?`/`present?`) and JSON serialization (`as_json`)
- Empty strings treated as `nil`

[Unreleased]: https://github.com/unreasonable-magic/unmagic-enum/compare/v0.1.1...HEAD
[0.1.1]: https://github.com/unreasonable-magic/unmagic-enum/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/unreasonable-magic/unmagic-enum/releases/tag/v0.1.0
