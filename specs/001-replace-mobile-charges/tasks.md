# Tasks: Reemplazo de Mobile Device Charges

**Input**: Design documents from `specs/001-replace-mobile-charges/`

**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`,
`contracts/mobile-charges-ui.md`, `quickstart.md`

**Organization**: Tasks are grouped by user story. Automated tests are included
to satisfy the project constitution's verification requirement.

**Scope update (2026-11-12)**: User approved preparing only the employee mobile
replacement and new upload support, with no SQL changes until DBA approval.
The `LeaseInvoice/` source is an overlay, not a restored full site. Do not modify
the existing menu, cost-center reports, serial report or `MCMConnectionString`.
Paths below reflect the prepared overlay; unchecked tasks include live
integration work that is not claimed complete.

## Phase 1: Setup

**Purpose**: Restore the application context and establish reproducible build
and test commands before changing the legacy site.

- [ ] T001 Restore the Web Forms site source under `LeaseInvoice/` and verify the referenced SQL objects on the server; preserve its Web Site deployment model if no project file exists, exclude credentials, and use local configuration placeholders. Do not require an `App_Data` database.
- [ ] T002 [P] Inspect a sanitized source workbook and record the actual extension, `MM_YYYY` filename pattern, charge/date formats, and phone representation in `specs/001-replace-mobile-charges/research.md` without committing workbook data.
- [ ] T003 Identify the solution build command and test conventions from `LeaseInvoice/`; if no test project exists, establish `LeaseInvoice.Tests/` with a framework compatible with the recovered target, then record runnable commands in `specs/001-replace-mobile-charges/quickstart.md`.

## Phase 2: Foundational

**Purpose**: Establish verified employee identity and a persistence contract
shared by the employee view and monthly publisher. These tasks block all user
stories.

- [ ] T004 [P] Verify how `PeopleId_by_logoind` in `LeaseInvoice/App_Code/dbPeople.vb` maps the authenticated corporate login to `Description 2 - Emp Number`; document the confirmed mapping in `specs/001-replace-mobile-charges/research.md`.
- [ ] T005 [P] Define SQL persistence for `BillingPeriod`, `UploadBatch`, and complete monthly snapshots in `LeaseInvoice/Database/MobileCharges.sql`, following the recovered deployment conventions and these field rules from `specs/001-replace-mobile-charges/data-model.md`: `year` “Four-digit year”; `month` “`1` through `12`”; `batchId` “Unique per upload attempt”; `billingPeriod` “Derived from the filename prefix; required”; `sourceFileName` “Preserve for provenance; do not expose to employees”; `uploadedBy` must be “an authenticated, explicitly authorized publisher”; `uploadedAt` “Server-generated”; status “`Uploaded`, `Validated`, `Rejected`, `Published`, or `Failed`”; `validationErrors` “Row/column diagnostics with no sensitive values in logs”; and a rejected or failed batch “must not change the active published snapshot.”
- [ ] T006 Implement the shared employee identity resolver and mobile assignment repository in `LeaseInvoice/App_Code/MobileCharges/`, using the verified mapping from T004 and schema from T005; ensure employee queries cannot select an employee from request input.

**Checkpoint**: The application builds, identity mapping is confirmed, and the
shared storage model is available before story implementation begins.

## Phase 3: User Story 1 - Consultar las asignaciones móviles propias (Priority: P1) 🎯 MVP

**Goal**: An authenticated employee sees all and only their mobile assignments
for the published month, including phone, monthly charge, and activation date.

**Independent Test**: Publish synthetic rows for two employee numbers, including
two assignments for one employee, a zero charge, and a blank activation date.
Sign in as each mapped identity and verify that only its own rows appear with
the correct period and source values.

### Tests for User Story 1

- [ ] T007 [P] [US1] Add employee-isolation tests for identical display names, multiple assignments, zero monthly charge, and blank activation date in `LeaseInvoice.Tests/MobileCharges/EmployeeAssignmentQueryTests.vb`.

### Implementation for User Story 1

- [X] T008 [US1] Create the mobile assignment view model in `LeaseInvoice/App_Code/MobileCharges/Models.vb`, preserving these model rules: billing period “Required; part of the assignment key”; employee number “Read from `Description 2 - Emp Number`; required and matched to the employee mapping”; mobile number “Read from `Mobile Number`; required, preserve significant characters, unique within a billing period”; monthly charge “Read from `Equipment Payment Plan Charges`; required, source-faithful, zero is valid”; activation date “Read from `Activation Date`; blank is allowed, a supplied value must be valid, and it is distinct from billing period.”
- [ ] T009 [US1] Implement the published-period employee query in `LeaseInvoice/App_Code/MobileCharges/MobileAssignmentRepository.vb`, filtering only by the server-resolved employee number and returning the complete published period.
- [X] T010 [US1] Replace the mobile page data binding in `LeaseInvoice/rptMCMUserPeriodDetail.aspx.vb` so it uses the authenticated account mapping and repository, never a query-string employee ID.
- [X] T011 [US1] Render the employee context, published month, mobile number, monthly charge, and optional activation date in `LeaseInvoice/rptMCMUserPeriodDetail.aspx`; show a blank activation date as unavailable, not as the billing period, and identify currency only when defined by the source.

**Checkpoint**: Employee isolation and displayed source values pass the US1
independent test.

## Phase 4: User Story 2 - Navegar desde Asset Voucher y regresar (Priority: P2)

**Goal**: Employees can open the replacement through the existing Asset Voucher
choice, return to that choice, and continue using PC Asset Charges unchanged.

**Independent Test**: Open Mobile Device Charges from the existing selection,
return to the selection, and open PC Asset Charges. Verify keyboard operation
and readability at a narrow viewport.

### Tests for User Story 2

- [ ] T012 [P] [US2] Add navigation regression checks for the mobile entry/return links and unchanged PC Asset Charges route in `LeaseInvoice.Tests/MobileCharges/AssetVoucherNavigationTests.vb`.

### Implementation for User Story 2

- [ ] T013 [US2] Verify in staging that the existing Asset Voucher entry opens `LeaseInvoice/rptMCMUserPeriodDetail.aspx`; preserve the existing menu and the PC Asset Charges destination unchanged.
- [ ] T014 [US2] Add a labeled return link and keyboard-accessible, narrow-screen layout to `LeaseInvoice/rptMCMUserPeriodDetail.aspx`.

**Checkpoint**: Existing navigation works in both directions and the PC page
remains unchanged.

## Phase 5: User Story 3 - Publicar el Excel mensual de forma manual (Priority: P2)

**Goal**: Explicitly authorized TI publishers can validate and publish a complete
monthly workbook snapshot; employees never see partial or rejected uploads.

**Independent Test**: Validate and publish synthetic workbooks for a later month
and same-month correction; reject missing headers, invalid rows, duplicate
phones, unauthorized publishers, and an earlier month while preserving the
previous published snapshot.

### Tests for User Story 3

- [ ] T015 [P] [US3] Add workbook-reader and period-parser tests for the `Billing Data` sheet, the exact four source headers, `MM_YYYY` filename prefix, invalid months, blank activation dates, and invalid non-empty dates in `LeaseInvoice.Tests/MobileCharges/MobileWorkbookReaderTests.vb`.
- [ ] T016 [P] [US3] Add validation and publication tests for required employee/phone/charge values, duplicate phones, full-snapshot replacement, same-month correction, older-period rejection, unauthorized users, and rollback on failure in `LeaseInvoice.Tests/MobileCharges/MobileChargesPublicationTests.vb`.

### Implementation for User Story 3

- [ ] T017 [US3] Verify the prepared reader in `LeaseInvoice/App_Code/MobileCharges/Workbook.vb` against the actual anonymized workbook (T002); require `Billing Data` and exact headers `Description 2 - Emp Number`, `Mobile Number`, `Equipment Payment Plan Charges`, and `Activation Date`.
- [X] T018 [US3] Validate each workbook row in `LeaseInvoice/App_Code/MobileCharges/Workbook.vb` and `LeaseInvoice/App_Code/MobileCharges/Models.vb` using the data-model rules “missing/invalid employee number, missing/duplicate mobile number, invalid or missing monthly charge, invalid non-empty activation date, or duplicate phone within the period”; a blank activation date is valid, phones retain significant characters, and zero monthly charge is valid.
- [X] T019 [P] [US3] Implement server-side authorization for explicitly approved TI publishers in `LeaseInvoice/App_Code/MobileCharges/Access.vb`; deny other IT users and workbook preparers unless explicitly authorized.
- [ ] T020 [US3] Implement staging and transactional publication in `LeaseInvoice/App_Code/MobileCharges/MobileChargesPublicationService.vb`, replacing the full snapshot atomically, allowing same-month corrections and later months, rejecting earlier months, preventing duplicates, and rechecking the current period at publication time.
- [ ] T021 [US3] Add the restricted upload, validation preview with period, row count and actionable errors, and explicit publish-confirmation flow in `LeaseInvoice/MobileChargesUpload.aspx` and `LeaseInvoice/MobileChargesUpload.aspx.vb`; enforce application/IIS size limits, cap workbook dimensions, dispose parser resources, and clean up unique temporary files outside the web root.

**Checkpoint**: A valid complete workbook can be previewed and published; every
rejection leaves the previous published snapshot unchanged.

## Phase 6: User Story 4 - Distinguir ausencia de dispositivos de un error (Priority: P2)

**Goal**: Employees can distinguish a valid empty result from an unavailable
source, an unverified identity, or an internal query failure.

**Independent Test**: Exercise a valid employee with no rows, no published
period, unavailable database, unmapped login, and an internal query failure.
Verify distinct safe messages and no disclosure of another employee's data or
internal details.

### Tests for User Story 4

- [ ] T022 [P] [US4] Add page-state tests for empty results, missing publication, source failure, unmapped identity, and sanitized internal errors in `LeaseInvoice.Tests/MobileCharges/EmployeeQueryStateTests.vb`.

### Implementation for User Story 4

- [X] T023 [US4] Implement explicit empty, unavailable, unverified-identity, and query-failure states in `LeaseInvoice/rptMCMUserPeriodDetail.aspx.vb` and `LeaseInvoice/rptMCMUserPeriodDetail.aspx`.

**Checkpoint**: All empty and failure scenarios are distinguishable, and
employee-facing errors do not disclose internal details.

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Validate the complete feature, privacy constraints, and regression
boundaries before delivery.

- [ ] T024 Ensure mobile query and upload failures surface actionable safe messages without logging or rendering phone numbers, workbook contents, credentials, connection identifiers, or execution details in `LeaseInvoice/App_Code/MobileCharges/`.
- [ ] T025 Verify the employee query, upload, workbook validation, and publication logs in `LeaseInvoice/App_Code/MobileCharges/` omit phone numbers, workbook contents, credentials, and internal connection details.
- [ ] T026 Run the end-to-end scenarios in `specs/001-replace-mobile-charges/quickstart.md` against a non-production environment and record build/test commands and results in that guide.
- [ ] T027 Verify SC-003 response-time target and all PC Asset Charges/navigation regression scenarios; record results in `specs/001-replace-mobile-charges/quickstart.md`.

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: T001 is a hard prerequisite because application source and
  database definitions are absent from this repository. T002 can run in parallel
  when a sanitized workbook is available. T003 requires T001.
- **Foundational (Phase 2)**: Depends on restored sources in T001. T004 and T005
  can run in parallel. T006 depends on both verified identity mapping and storage.
- **User Stories (Phases 3-6)**: Depend on T006. US1, US2, and US3 can proceed
  independently after foundation; US4 depends on US1's page/query states.
- **Polish (Phase 7)**: Depends on all four user stories.

### User Story Dependencies

- **US1 (P1)**: Starts after the foundational identity resolver and repository;
  no dependency on another user story.
- **US2 (P2)**: Starts after foundation; navigation work can run independently
  from US1 and US3.
- **US3 (P2)**: Starts after foundation; publication uses the shared schema and
  can proceed independently from the employee view.
- **US4 (P2)**: Depends on US1's employee page and repository to present its
  empty, identity, and query failure states.

### Within Each User Story

- Tests are written first and should fail before their implementation tasks.
- Independent model/reader and test files marked `[P]` can be handled in parallel.
- Page integration follows shared services and models.

## Parallel Opportunities

- **Setup**: T002 can run alongside T001 when the sanitized workbook is available.
- **Foundation**: T004 identity mapping and T005 SQL persistence design can run in parallel after source restoration.
- **After foundation**: US1, US2, and US3 can be separate workstreams.
- **US1**: Run T007 tests first and confirm they fail before implementing T008-T011.
- **US3**: T015 parser tests and T016 publication tests can be prepared in parallel; after they fail, T017 workbook reading and T019 publisher authorization can proceed in parallel. T018 depends on T017; T020 depends on T018 and T019.
- **US4**: Run T022 tests first and confirm they fail before implementing T023.

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Restore the application and database context (Phase 1).
2. Verify identity mapping and establish shared persistence (Phase 2).
3. Implement and independently verify US1 employee-scoped read-only display.
4. Validate the MVP with synthetic data for multiple employees, zero charge,
   optional activation date, and no cross-employee disclosure.

### Incremental Delivery

1. Complete setup and foundation.
2. Deliver US1 employee consultation as the first user-facing increment.
3. Add US2 navigation and accessibility without changing PC Asset Charges.
4. Add US3 authorized workbook publication and atomic snapshot replacement.
5. Add US4 explicit empty/unavailable/error states and run cross-cutting checks.

## Notes

- `[P]` means tasks operate on separate files and have no dependency on unfinished work.
- Every implementation task targets the recovered Web Forms application under `LeaseInvoice/`; this repository currently contains only the planning documents.
- If the recovered solution uses different physical paths or test conventions, update these tasks after T001/T003 rather than creating duplicate projects or parallel storage mechanisms.
- Keep all workbook fixtures synthetic or anonymized; never commit production employee data or credentials.

## Prepared implementation evidence (2026-11-12)

`scripts/Test-EmployeeMobileCharges.ps1` compiles the new VB services and runs
34 synthetic assertions from `tests/MobileChargesTests.vb`.
`scripts/Test-MobileChargesPages.ps1` precompiles both new page implementations
using the configuration example. The SQL, identity and live regression tasks
remain unchecked: there is no approved target database and no SQL changes
were applied.

The prepared implementations corresponding to T005/T009/T020/T021 are in
`database/Install-EmployeeMobileCharges.sql`,
`LeaseInvoice/App_Code/MobileCharges/Store.vb`, and
`LeaseInvoice/MobileChargesUpload.aspx(.vb)`; they are not claimed verified
against live SQL. Session staging replaces the earlier temporary-file approach.
