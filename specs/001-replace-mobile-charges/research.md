# Research: Reemplazo de Mobile Device Charges

## Existing application integration

**Decision**: Implement the replacement in the existing ASP.NET Web Forms
application, retaining the current Asset Voucher entry/return navigation and
leaving PC Asset Charges unchanged.

**Rationale**: The supplied source identifies `rptMCMUserPeriodDetail.aspx`
as the mobile page and shows the existing application is VB.NET Web Forms on
.NET Framework 4.7.1. The repository currently contains only planning
documents, so the exact solution and database integration points must be
confirmed when application source is restored.

**Alternatives considered**: Rebuild the whole Asset Voucher site or create a
separate application. Both expand scope and risk disrupting the working PC page
and existing corporate authentication.

## Identity and authorization

**Decision**: Resolve the signed-in corporate account on the server and map it
to the employee using the existing `PeopleId_by_logoind` / `zGetPidFlogon`
path. Filter every employee query by that resolved employee ID. Enforce
publisher authorization server-side using the explicitly approved TI publisher
list or role already used by the application.

**Rationale**: The inspected page has a `peopleid` query-string input, while the
application also exposes the authenticated identity and a server-side mapping.
Using a caller-supplied ID would permit cross-employee disclosure. Authentication
does not itself imply permission to publish workbook data. The mapping helper
returns a `PeopleId`; confirm how that identifier corresponds to the workbook's
`Description 2 - Emp Number` before implementing the row filter.

**Alternatives considered**: Trusting the query string or a form field, mapping
by employee display name, or allowing every IT user. These do not satisfy the
confirmed access requirements.

## Workbook parsing

**Decision**: Use a managed Excel reader compatible with .NET Framework 4.7.1,
with format support finalized against an anonymized source workbook. Read the
`Billing Data` sheet by its exact headers, not by a fixed cell range. Initially
support `.xls` and `.xlsx`, consistent with the existing upload page, unless
the real source file requires a different supported format.

**Rationale**: The existing `LeaseUpdate.aspx.vb` uses OleDb Jet/ACE providers,
fixed temporary filenames, and a lease-specific fixed range. Reusing those
assumptions risks reading the wrong columns or colliding uploads. The previously
evaluated ExcelDataReader package supports .NET Framework 4.6.2+, which includes
the inspected 4.7.1 target; confirm the selected package version and deployment
dependencies against the actual solution.

**Alternatives considered**: Reusing the lease-specific OleDb query; rejected
because it is coupled to a different sheet/range and provider installation.
Manual CSV conversion is also rejected because it adds an unrequested
operational step.

The user confirmed that `Activation Date` may be blank. Accept blank cells,
validate non-empty values, and present a blank date as unavailable; never
substitute the billing period.

## Billing period and file provenance

**Decision**: Parse the month and year from the filename prefix `MM_YYYY`.
Retain the original filename as source provenance; do not treat the changing
version suffix as a billing period or use it to bypass the period ordering rule.

**Rationale**: The user confirmed the prefix carries the month and year and that
the version suffix increases for each newly received workbook. Only the prefix
is needed to identify the period. The precise file extension and all filename
delimiters still need verification against a sanitized workbook.

**Alternatives considered**: Use upload date, activation date, or a manually
entered period. These could mislabel a billing month or confuse the assignment
date with the billing period.

## Validation and publication

**Decision**: Parse and validate the entire workbook into a non-published
staging set; show validation results to the authorized publisher; publish only
after explicit confirmation and a second check of the current period. Replace
the current complete snapshot in one SQL transaction.

**Rationale**: Each workbook contains the complete monthly set. Transactional
replacement prevents employees from observing a partial import and preserves
the previous snapshot on any validation or database failure. The rule must be
rechecked at publication time to handle concurrent uploads.

**Alternatives considered**: Insert rows directly while parsing or merge the new
file into the current set. Both can expose partial data or leave stale
assignments. The exact SQL schema and locking strategy must be selected after
the existing database objects are available.

## Upload handling and data minimization

**Decision**: Enforce extension/content and size limits, cap workbook dimensions,
use a unique temporary file outside the web root, dispose of parser resources,
and remove the temporary file after processing. Do not log workbook values or
retain raw uploads beyond the established retention policy.

**Rationale**: The existing loader's fixed filenames are unsafe for concurrent
uploads, and spreadsheet files can consume excessive server resources. Upload
limits must be coordinated with ASP.NET and IIS configuration.

**Alternatives considered**: Fixed temporary paths or storing the raw workbook
under a browsable application directory. Both increase collision or disclosure
risk.

## Verification

**Decision**: Add focused tests in the recovered application's existing test
framework for filename period parsing, workbook/header/row validation,
identity and publisher authorization, full-snapshot replacement, same-month
correction, rejection of older periods, and preservation of the active set on
failure.

**Rationale**: The repository has no solution, project, or test files, so
commands and test framework cannot yet be chosen responsibly. The design
defines observable cases without inventing an execution environment.

**Alternatives considered**: Adding a new test framework or CI setup before the
application project is available. This would add tooling without evidence that
it fits the deployment.
