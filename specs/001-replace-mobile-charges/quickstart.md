# Quickstart: Validar Mobile Device Charges

## Prerequisites

- The ASP.NET Web Forms application source and verified SQL objects/procedures.
  The supplied folder can be an ASP.NET Web Site without solution/project files;
  SQL data is server-hosted rather than stored in `App_Data`.
- A non-production environment with corporate authentication and an explicitly
  authorized test publisher.
- A synthetic or anonymized Excel workbook using the actual source format,
  sheet `Billing Data`, required headers, and a filename beginning `MM_YYYY`.
- Two synthetic employee identities, including one with multiple assignments.

Build and test commands must use the recovered solution's existing tooling; no
solution or test project is present here, so a repository command cannot yet be
specified without guessing.

For the reported legacy `CUS` login failure, use the separate diagnosis and
verification procedure in `docs/mobile-charges-database-access.md` at the
repository root. That repair does not implement the monthly Excel replacement.

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

## Prepared overlay checks (2026-11-12)

From the repository root, the isolated overlay can now be checked without SQL:

```powershell
& .\scripts\Restore-MobileCharges.ps1
& .\scripts\Test-EmployeeMobileCharges.ps1
& .\scripts\Test-MobileChargesPages.ps1
```

The first command restores the declared package; the latter two compile and run
synthetic service tests and precompile the Web Forms overlay respectively.
They do not apply SQL changes. Live identity resolution, publication/rollback
and concurrency checks still require an approved staging database. Confirm
the production CLR/runtime before deploying; the old error screenshot was v2.

## Deployment preparation update (2026-11-12)

The user reported the live IIS pool uses CLR v4 and the server's Framework
Release value is `533509` (.NET Framework 4.8.1), satisfying the Framework
minimum. The user subsequently approved the existing `MainInv` database on
`zcirving03`. The isolated `mobile` schema, three empty snapshot tables and
two procedures have been installed transactionally on SQL Server 2019.
Do not rerun the installer. The verified identity procedure has also been
installed in `MainInv`, mapping full `people.LOGONID` to `sap_number`.
No grants or IIS changes were applied; application permissions and staged
acceptance remain pending.

Check a secured staging site copy with:

```powershell
& .\scripts\Test-MobileChargesDeployment.ps1 -SitePath 'C:\staging\LeaseInvoice'
& .\tests\Test-MobileChargesDeployment.Tests.ps1
```

The preflight is offline and reports missing/placeholder settings without
printing credentials. The example configuration must fail until approved
values are supplied. It cannot verify the SQL identity procedure or replace DBA
approval. See `docs/mobile-charges-database-access.md` for precise scope.

## Local read-only demo

`scripts/New-MobileChargesDemo.ps1` prepared an ignored
`tests\bin\MobileChargesDemo` site with a separate landing page, Windows
authentication, secure cookies and an empty publisher allowlist. It uses
the approved `MainInv` read/identity targets but cannot publish. Do not
overwrite the legacy site with it.

Local IIS is not installed and the session is not elevated. An administrator
must provision the separate HTTPS/Windows-authenticated CLR v4 site and an
approved SQL runtime identity before a browser demo can run.
To demonstrate publication, approve a separate demo database first; never
publish synthetic rows into the active `MainInv` snapshot.

```powershell
& .\tests\Test-MobileChargesIdentity.Tests.ps1 -Server zcirving03 -Database MainInv
& .\tests\Test-MobileChargesDemo.Tests.ps1
```

Eight temporary SQL fixture cases passed; the installed resolver returned
exactly one mapping for the current Windows account without saving employee
values. Demo safeguards and all three ASP.NET pages compile. These checks do
not verify IIS authentication, SQL runtime permissions or live browser behavior.
