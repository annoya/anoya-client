# CLAUDE.md

See [AGENTS.md](AGENTS.md) — the operating guide for this repository lives
there, so every agent runtime reads the same file.

Before changing a subsystem, read the ADR that governs it in
[docs/decisions/](docs/decisions/README.md). This repository is the client, and
it is specified in [docs/SPEC-CLIENT.md](docs/SPEC-CLIENT.md). The server side
lives in its own repository,
[anoya-web-panel](https://github.com/anoya/anoya-web-panel), which carries
`SPEC-SERVICE.md` and the service-side ADRs.
