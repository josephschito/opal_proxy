## [Unreleased]

## [0.2.0] - 2026-08-19

- Preserve `JS::Promise` wrappers across `then` and `catch` chains.
- Wrap callback receivers and arguments, and unwrap callback return values.
- Support JavaScript iterables and array-like objects through `Enumerable`.
- Make `respond_to?` reflect native property availability.
- Improve exact, camelCase, and acronym-aware property lookup.
- Refresh native property introspection for dynamically added properties.
- Add deterministic browser coverage without external network dependencies.

## [0.1.1] - 2025-08-08

- Add `[]=` method to Proxy.

## [0.1.0] - 2025-07-24

- Initial release.
