# Quickstart: Validar Mobile Device Charges

## Prerequisites

- The ASP.NET Web Forms application source, solution/project files, and SQL
  schema/procedures. These were not included in the planning repository.
- A non-production environment with corporate authentication and an explicitly
  authorized test publisher.
- A synthetic or anonymized Excel workbook using the actual source format,
  sheet `Billing Data`, required headers, and a filename beginning `MM_YYYY`.
- Two synthetic employee identities, including one with multiple assignments.

Build and test commands must use the recovered solution's existing tooling; no
solution or test project is present here, so a repository command cannot yet be
specified without guessing.

## End-to-end scenarios

1. **Employee isolation**: Publish synthetic rows for two employee numbers.
   Sign in as each mapped account and open Mobile Device Charges. Each account
   sees only its own numbers, monthly charges, activation dates, and the same
   published month.
2. **Empty and failure states**: Test a valid employee without assignments,
   an unmapped corporate login, and an unavailable data source. Verify distinct
   messages and no disclosure of another employee's records or internal errors.
3. **Workbook validation**: Upload workbooks with a wrong worksheet, missing
   header, invalid filename month, missing employee number, invalid charge/date,
   and duplicate phone number. Each is rejected and the active data remains
   unchanged. A row with a blank activation date is accepted and rendered as
   unavailable.
4. **Snapshot replacement**: Publish a later complete month containing a new
   assignment and omitting a previous one. Verify the new row appears and the
   omitted row no longer appears; no partial state is visible during publication.
5. **Period rules**: Publish a correction for the current month and a later
   month successfully. Attempt an earlier month and verify rejection without
   changing the active snapshot.
6. **Authorization and regression**: Attempt upload and publication with an
   employee and an unauthorized IT identity. Both are denied. Verify PC Asset
   Charges and return navigation remain unchanged.

## Expected outcome

All success and rejection states match
[the UI contract](contracts/mobile-charges-ui.md), row and lifecycle rules match
[the data model](data-model.md), and the measurable targets in `spec.md` pass.
Use only synthetic/anonymized data in test artifacts and logs.
