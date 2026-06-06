# Changelog

## [Unreleased]
## [0.4] - 2026-06-07
- Add a mode to apply shirt to automatically send the mail

## [0.4] - 2026-06-06
- Add button to select 50 next messages.


## [0.3] - 2026-04-18
- Add Reply a new reply field in mail composition
- Adjust UI with scrolling adjusted
- Old name updated

## [0.2] - 2026-04-13

- The app window is now fully resizable instead of being constrained to the content size.
- Renamed the app to MailWeave.
- In step 2 (Compose), added a recipients bulk-selection button to `Select all` / `Unselect all` next to the recipients header.
- Added a GitHub Actions workflow (`.github/workflows/macos-build.yml`) to run a macOS Xcode build on each push to `main` and on pull requests targeting `main`.

## [0.1] - 2026-03-01

- First-step flow now asks for message mode: `Global message` vs `Per recipient`.
- In `Per recipient` mode, `message` header selection is required in step 1.
- In `Global message` mode, only `email` header is required in step 1.
- Compose recipient rows now include a resolved preview with placeholders replaced using row fields.
- Delimiter selection moved next to the import button in a compact control.
- Default CSV delimiter changed to `;` (semicolon).
- Header mapping now requires only `email`; `message` mapping is optional.
- Switched CSV import to header mapping instead of fixed required header names.
- Moved recipient creation to post-mapping and removed optional name-mapping UI.
- Recipient name now uses CSV `name` when available, otherwise falls back to email local-part.
- Compose view now shows available placeholder headers while editing the default message.
- Import view height is now dynamic.
- Updated `README.md` to reflect the new workflow and wording cleanup.
