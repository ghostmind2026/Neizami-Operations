# Neizami Mobile UI + Smart Grid Runtime

This runtime ports the reusable principles from Neizami UI Theme and Neizami Smart Grid into Flutter without rebuilding WordPress rendering inside the app.

## UI authority

- Flutter branding remains server-driven through `Branding`.
- `NeizamiUiTokens` converts branding into reusable mobile surfaces, borders, soft states, controls and semantic colors.
- Shared primitives live in `lib/core/ui/neizami_ui.dart`.
- Forms, endpoint lists, filters, KPI cards, loading, error and empty states should reuse those primitives instead of defining local styles.

## Endpoint pipeline

Mobile endpoint screens follow the Smart Grid performance order:

1. Search / filters / sort are sent to the authoritative endpoint.
2. Pagination is applied server-side (`page`, `per_page`, `limit`).
3. Mobile Bridge projects the final page into the mobile `presentation` contract.
4. Flutter renders only that compact projection.
5. The raw endpoint payload is not returned by default; it is available only for explicit administrator diagnostics.

This keeps filtering/search semantics in Smart Grid and avoids duplicating large endpoint payloads in Flutter.

## Search lifecycle

- Default minimum search length: 3 characters.
- Debounce: 320 ms.
- Every input change advances a request generation, so stale in-flight responses are ignored.
- Repeating the same executed search does not trigger another request.
- Search remains server-side.

## Filters

Flutter sends a compact JSON map in `filters`. Mobile Bridge translates it into Smart Grid filter expressions before the internal REST request. Filter changes always reload page 1.

## Pagination and rendering

- Default mobile page size: 40.
- Infinite loading begins before the user reaches the end of the list.
- Appended cards are deduplicated by entry ID where available.
- Existing content remains visible during refresh; only a thin progress indicator is shown.
- Presentation supports rows, compact rows, cards, and a maximum two-column mobile grid.

## Forms

The current Simple Formidable Mobile contract remains intentionally limited to:

- Text
- Number
- Dropdown / Select
- Checkbox

The mobile UI uses the same Neizami primitives and a sticky save action. Submission remains:

`Flutter -> Mobile Bridge -> Formidable -> existing hooks`

Lookup, conditional runtime and calculations remain outside the current simple-form scope.

## Source-of-truth rule

Neizami UI provides the visual system. Smart Grid / Formidable / Neizami backend components remain authoritative for data and business logic. Flutter is the mobile presentation and interaction layer.
