# Documentation — agent rules

The site in `docs/` has four sections, and a page belongs to one reader.

- **Use** (`docs/use/`): someone who wants the app on the menu bar. What it does, how to install it, reading the bars,
  adding a provider from a JSON file, troubleshooting. No Xcode and no Swift.
- **Develop** (`docs/develop/`): someone who builds, signs or extends it. Build and run, architecture, the API of
  `TokenMeterCore`, the file formats, data sources, commands, signing and notarization, contributing.
- **Features** (`docs/features/`): one folder per feature, newest first, each a nucleus of overview, proposal and
  implementation plan. The proposal keeps a screenshot of the design that was chosen, because its canvas is deleted once the
  code is in. The pattern is in `docs/features/index.md` and `docs/develop/implement-a-feature.md`; what an agent does and
  does not do is in `.agents/doc/features.md`.
- **Decisions** (`docs/adr/`): structural decisions only. Every ADR links to the others, so they keep their numbers and
  their place.

When a topic serves both readers (the providers file), the Use page says how to use it and the Develop page says how it is
decoded. Public URLs are changed without redirects while nothing outside the README links to them.
