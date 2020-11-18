# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog][1], and this project adheres to [Semantic Versioning][2].

[1]: https://keepachangelog.com/en/1.0.0/
[2]: https://semver.org/spec/v2.0.0.html

## majic [Unreleased]

## Added

- Forked gen_magic.
- Pool: `Majic.Pool`, using [nimble_pool](https://hex.pm/packages/nimble_pool).
- Plug: `Majic.Plug`.
- Unified API: `Majic.perform/1,2,3`.
- Builds an up-to-date and patched magic database.
- `Majic.compile/2`
- `Majic.Server.reload/2,3`
- `Majic.Server.recycle/2,3`

## Changed

- Improved C port, now using erl_interface
- Builds on Musl
- Better error and timeout handling
- Bytes support: `Majic.Server.perform(ref, {:bytes, <<>>})`
- Renamed `priv/apprentice` to `priv/libmagic_port` to be more obvious in `ps`
- Renamed `Majic.Helpers.perform_once` to `Majic.Once.perform`

## gen_majic [1.0]

### Added

- Added support for process recycling (evadne).
- Added documentation (evadne).

### Changed

- Replaced GenServer with `:gen_statem` (evadne).
  - Changed API; added support for customisation.

- Refined tests and other aspects of the library (evadne).

## [0.20.83]

### Added

- Soak testing script (devstopfix)

### Changed

- Replaced Erlexec usage with Port (devstopfix)

## 0.0.1

### Added

- Initial Elixir wrapper with Erlexec (evadne)
- Intiial C program (evadne)

[unreleased]: https://github.com/evadne/gen_magic/compare/develop
[0.20.83]: https://github.com/devstopfix/gen_magic/commit/7e27fd094cb462d26ba54fde0205a5be313d12da
