# Implementation Plan: Reemplazo de Mobile Device Charges

**Branch**: `danield772-github-spec-kit` | **Date**: 2026-11-09 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/001-replace-mobile-charges/spec.md`

## Summary

Replace the broken mobile charges page in the existing Asset Voucher application
with an employee-scoped view of the published monthly workbook. The source is
the `Billing Data` sheet: employee number, mobile number, monthly
`Equipment Payment Plan Charges`, and `Activation Date`. Derive the billing
period from the filename prefix `MM_YYYY`; treat its changing version suffix as
file provenance, not as a separate period. Authorized IT staff validate a full
snapshot before an atomic publication. Resolve employee identity server-side
from the authenticated corporate account; never authorize using a query-string
employee ID.

The supplied LeaseInvoice source was inspected, but this repository contains
documentation only and no application project or database schema. The design
therefore targets the inspected ASP.NET Web Forms application while identifying
the integration points that must be verified when its source and database
definitions are available.

## Technical Context

**Language/Version**: VB.NET, ASP.NET Web Forms, .NET Framework 4.7.1 (from the supplied application source)

**Primary Dependencies**: Existing Web Forms controls and SQL Server access; a managed Excel reader compatible with .NET Framework 4.7.1 is preferred for `.xls`/`.xlsx`. The exact deployed package versions must follow the recovered solution.

**Storage**: SQL Server. The legacy page uses `MCMConnectionString`; the supplied source did not include the schema or database procedures needed to select the final storage design.

**Testing**: No solution, project, or test files are present in this repository. Add parser, validation, authorization, publication-atomicity, and page-flow tests to the recovered application using its existing test/build conventions.

**Deployment clarification (2026-11-12)**: The supplied `CodeFile`/`App_Code`
layout is consistent with an ASP.NET Web Site, which does not require a
`.sln`/`.vbproj` to run. SQL connections target a server database, not an
`App_Data` file. Missing project files or an empty `App_Data` folder are not
implementation blockers by themselves. Verify the deployed IIS configuration,
runtime, database objects and identity mapping rather than inventing a project.
The reported screenshot uses ASP.NET 2.0 while the supplied configuration targets
4.7.1, so establish the actual deployment baseline before introducing new code.

**Target Platform**: Existing corporate Asset Voucher Web Forms application on Windows/IIS and SQL Server.

**Project Type**: Server-rendered Web Forms application; employee read view and restricted administrative upload/publish workflow.

**Performance Goals**: Meet spec outcome SC-003: at least 95% of employee requests show data or an explicit state within five seconds under normal corporate access conditions.

**Constraints**:
- Preserve PC Asset Charges and existing Asset Voucher navigation.
- Use verified corporate identity and the server-side account-to-employee mapping; do not trust a submitted employee number.
- Verify how the existing `PeopleId` identity mapping corresponds to `Description 2 - Emp Number`; the supplied source did not establish that these values are identical.
- Validate the complete workbook before publication, and atomically replace the published snapshot only after rechecking the period rule.
- Use unique temporary files outside the web root and enforce upload limits at both application and IIS boundaries.
- Do not log employee phone numbers, workbook contents, credentials, or internal connection details.
- A sanitized source workbook and the SQL schema/procedures are required to finalize workbook format handling and database integration.

**Scale/Scope**: One current published monthly snapshot; each file represents all active mobile assignments for its billing month. Same-month correction and forward publication are allowed; earlier months are rejected. Historical employee browsing and automatic ingestion are out of scope.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Gate | Result |
|---|---|---|
| I. User Value and Clear Requirements | Design maps to employee consultation and authorized monthly update requirements without inventing policy. | PASS |
| II. Correctness and Data Integrity | Validate identity and source rows; stage first; publish a full snapshot transactionally; surface failures. | PASS |
| III. Privacy and Least Privilege | Restrict employee view to mapped identity, publisher flow to explicit IT authorization, and avoid sensitive logging. | PASS |
| IV. Verification Before Delivery | Define tests for source parsing, access control, atomic publication, and regressions; test execution awaits the application source. | PASS WITH DEPENDENCY |
| V. Simplicity and Usability | Reuse existing Web Forms navigation and a clear table/preview flow; avoid unrelated PC page changes. | PASS |

No constitution violations are proposed. Verification is planned, but the
solution and test projects were not included in the repository; implementation
must establish the runnable commands after the source is restored.

## Project Structure

### Documentation (this feature)

```text
specs/001-replace-mobile-charges/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── mobile-charges-ui.md
└── tasks.md                 # Created by /speckit-tasks
```

### Source Code (inspected application; not present in this repository)

```text
LeaseInvoice/
├── rptMCMUserPeriodDetail.aspx(.vb)  # Existing mobile page to replace
├── LeaseUpdate.aspx(.vb)             # Existing upload flow; reference only
├── App_Code/dbPeople.vb              # Existing corporate-login to PeopleId mapping
└── web.config                        # Existing SQL connection configuration
```

**Structure Decision**: Integrate into the existing ASP.NET Web Forms application
and reuse its verified identity mapping and navigation. Do not copy the existing
lease reader or fixed `LeaseSchedule$A1:G500` range: the mobile workbook uses
`Billing Data` and a different set of headers. The source ZIP lacked solution
files and database definitions, so exact page/service/storage file locations are
provisional until the application source is available in the implementation
workspace. The relationship between the login-mapped `PeopleId` and workbook
employee number must also be verified before wiring the employee query.

## Complexity Tracking

No constitution violations or additional architectural projects are proposed.

## Isolated implementation update (2026-11-12)

The user approved preparing an Excel-backed employee-page replacement and
deployment scripts, without applying SQL changes until a database is approved.
`LeaseInvoice/` now contains only that overlay; it is not the full legacy site.
`MCMConnectionString` and the other reports are unchanged. The new connections
are `MobileChargesConnectionString`, `MobileChargesPublisherConnectionString`
and `MobileChargesIdentityConnectionString`. The verified identity procedure
maps the full corporate `people.LOGONID` to workbook `sap_number`, not `peopleid`.

ExcelDataReader 3.7.0 is declared in `LeaseInvoice/packages.config`. Validation
stages rows in server-side session rather than temporary application files;
publication writes a complete snapshot in a SQL transaction. No raw workbook
is retained by application code. The proposed tables are confined to `mobile`.

The shared services and both ASP.NET pages compile locally; synthetic workbook
tests pass. Live SQL, identity, staging UX and legacy report regressions remain
deployment gates. Full instructions are in `docs/mobile-charges-database-access.md`.

The user subsequently reported CLR v4 and Framework Release `533509` (4.8.1)
on the web server. This meets the minimum Framework requirement without a
pool upgrade. `scripts/Test-MobileChargesDeployment.ps1` now provides offline
local configuration/file checks. It does not connect to SQL or verify the
identity procedure.

The user subsequently approved `zcirving03` / `MainInv` for the isolated
schema. A Windows-authenticated connection confirmed SQL Server 2019
(`15.0.4500.2`) and the required creation permissions. The installer was
executed in one transaction, creating only the `mobile` schema, three empty
snapshot tables and two procedures. Subsequently,
`dbo.MobileChargesResolveEmployee` was installed and checked for the current
Windows account. Eight synthetic SQL cases preserve fail-closed missing/null/
duplicate behavior without storing personal identifiers. No grants,
legacy-object changes or application deployment were performed.

The user selected a separate local IIS demo. `scripts/New-MobileChargesDemo.ps1`
prepares only the overlay and a demo landing page; publication stays disabled.
Its configuration safeguards and all three pages compile. Local IIS is absent
and the session is not elevated, so hosting has not been configured.
The approved IIS SQL identity/permissions, HTTPS/Windows Authentication,
separate demo publication database and staged regressions remain gates.
