# Restoring the legacy mobile page's database access

The reported `Cannot open database "CUS" requested by the login` failure occurs
when `SqlDataSource1` opens `MCMConnectionString`, before the mobile SELECT
executes. The supplied configuration points that connection at `CUS` on a SQL
Server instance; it does not attach an `App_Data` database.

The supplied source uses `CodeFile` pages and `App_Code`, consistent with an
ASP.NET Web Site. Missing `.sln`/`.vbproj` files alone do not prevent that
deployment model from working.

## What this repair can and cannot change

The legacy query reads `[CUS].[dbo].[MCM_Movs]` and joins the unqualified
`vw_peopledevice` view. Do not change the connection to `MainInv` merely because
the PC page works: the query still depends on `CUS`.

The error does not prove which of these causes applies:

- The deployed connection targets the wrong SQL instance.
- `CUS` is missing, offline, restoring, or unavailable to application users.
- `MisWebusr` has no database user, or the database user SID no longer matches
  the SQL login after a restore/migration.
- Access is denied by SQL permissions or the login credentials/configuration
  are no longer valid.

A local page change cannot restore server-side database access. The scripts
below provide diagnosis and a narrowly scoped repair for the user-mapping case;
the repair has not been executed against the SQL server.

### Observed from the supplied configuration (2026-11-12)

The read-only application-account probe reproduced SQL error `4060` opening
`CUS`. Using the same credentials to open `master` succeeded, and the login
matched the one in the reported error. The `CUS` metadata lookup and
`HAS_DBACCESS('CUS')` returned `NULL` for that account.

This confirms the credentials work for `master`, but it does not prove whether
`CUS` is missing on this instance or hidden/unavailable to this login. A DBA
with catalog visibility must establish that distinction before applying the
repair. No permissions or database contents were changed by these probes.

## Diagnosis

1. Inspect the **deployed application's effective** `MCMConnectionString`
   privately in IIS. Confirm the SQL instance and `Initial Catalog=CUS`.
   Do not paste credentials into chat, source control, or command-line arguments.
2. On that exact SQL instance, have a DBA execute
   `database/Diagnose-MobileChargesAccess.sql` in SSMS. It reads only system
   metadata. Confirm that `CUS` exists, is online, the login is enabled, and
   the database user maps to its SID. Check the SQL Server error log for the
   login failure state. The supplied configuration may differ from production.
3. If the instance or catalog is wrong, correct the deployed connection
   securely. If `CUS` is missing/unavailable, have the DBA recover the intended
   database. Do not create an empty `CUS`, reset passwords speculatively, enable
   guest access, or give the web login `sysadmin`/`db_owner`.

## Mapping/permission repair

Only when the DBA confirms the existing login should read these objects:

1. Review `database/Repair-MobileChargesAccess.sql`. It defaults to
   `@Apply = 0`, which reports the planned actions without changing anything.
2. Save the existing user mapping, role membership, and explicit permissions
   before applying. Review existing `DENY` entries and cross-database view
   dependencies manually; this script does not remove denials or enable
   cross-database ownership chaining.
3. Set `@Apply = 1` in the DBA's local copy and execute on the confirmed instance.
   The transaction creates/remaps only the database user and grants `CONNECT`
   plus object-level `SELECT` on the existing table and view. It refuses to
   create missing application tables, databases, or SQL logins.
4. Verify using the application's actual login. A successful DBA query is not
   evidence that the web account can read the same objects.

If rollback is needed, the DBA must restore the captured prior mapping and
permissions; do not drop a pre-existing user or revoke rights used by other
pages blindly. This legacy SQL login may serve other application paths.

## Application-account verification

On the web server, run Windows PowerShell with read access to the deployed
configuration:

```powershell
& .\scripts\Test-MobileChargesConnection.ps1 -WebConfigPath 'C:\path\to\LeaseInvoice\web.config'
```

The probe opens `CUS` with the configured application credentials, then compiles
the existing mobile query with `TOP (0)`. It returns no employee rows and does
not modify SQL data, logins, users, or permissions. It exits `0` only after
both checks pass; failures exit `1` and show a sanitized reason/error number.
It does not print the connection string or raw SQL exception.

For encrypted, inherited, or external connection settings, use effective IIS
configuration and an equivalent DBA-approved probe; the script intentionally
does not decrypt or guess those settings. For integrated authentication, run
under the IIS worker identity rather than a developer/admin identity. Network
access and installed SQL client/provider compatibility must also match the web
server. A successful probe is not a replacement for the page verification.

Finally, open the mobile page with an authorized test employee account and
verify that PC Asset Charges still works. If the query probe fails on the view,
check its actual schema, default-schema resolution and any dependent database
permissions. Grant only the additional permissions the DBA confirms necessary.

## Remaining replacement work

This restores access to the legacy data source; it does not implement Excel
ingestion or change the page's authorization model. The replacement must still
map the authenticated account to the workbook employee number rather than
trusting the legacy `id` URL parameter.

The screenshot reports ASP.NET/.NET 2.0, whereas the supplied configuration
targets 4.7.1. Confirm which deployed site and application-pool runtime produced
the error before deploying any replacement code. Do not assume the supplied
folder is an exact copy of production.

## Isolated Excel-backed replacement (prepared, not deployed)

The user elected to replace only the employee mobile page without changing
legacy reports. On 2026-11-12, the user approved installing the isolated schema
in the existing `MainInv` database on `zcirving03`. Installation completed in
one transaction using Windows authentication: the `mobile` schema, three
snapshot tables, and `mobile.ReadEmployee`/`mobile.Publish` procedures.
The initial snapshot is empty. The verified identity procedure was subsequently
installed as described below. No permission grants, IIS changes, or live
webpage deployment have been performed.

### Scope of the patch

- Replace only `rptMCMUserPeriodDetail.aspx` and its code-behind.
- Add `App_Code/MobileCharges/`, `MobileChargesUpload.aspx` and its code-behind,
  and the ExcelDataReader runtime assembly.
- Do not overwrite any other existing pages, `dbPeople.vb`, datasets, menus,
  themes, or `MCMConnectionString`. In particular, leave
  `rptMCMCostCenterDetail.aspx`, `rptMCMPeriodDetail.aspx`, and
  `rptMCMSerialDetail.aspx` unchanged.
- New employee-view, identity and publisher connections have dedicated names.
  No new page queries `CUS` or reuses the legacy connection setting.

The repository's `LeaseInvoice/` folder is an **overlay**, not a complete site.
Never replace the deployed directory with it. Shared App_Code compilation and
configuration still require staging/regression checks before release.

### Approval and integration gates

Runtime update reported by the user on 2026-11-12: the LeaseInvoice IIS pool
uses CLR v4 and the web-server Framework Release value is `533509` (.NET
Framework 4.8.1). This satisfies the prepared overlay's Framework minimum
without changing the application pool. A direct connection to the approved
target confirmed SQL Server version `15.0.4500.2` (SQL Server 2019).
The identity procedure has been installed and checked with the current
Windows account. Application SQL identities/permissions, IIS hosting and staged
legacy-report regressions remain pending.

1. Confirm the production runtime. The prepared code needs .NET Framework
   **4.7.1 or later** on CLR v4 and SQL Server **2012 or later**. The error
   screenshot showed ASP.NET 2.0. Do not upgrade the shared application's pool
   merely to install this patch: that can affect other reports. If production
   is still on CLR v2, stop and agree a separately isolated application/routing
   plan or a runtime migration before deployment.
2. Database approval and isolated schema installation are complete for
   `zcirving03` / `MainInv`; application SQL identities still need approval.
   Do not rerun the installer on this database. Review
   `database/Install-EmployeeMobileCharges.sql`; it defaults to no execution.
   The DBA must select the approved non-system database and deliberately enable
   installation in a local copy. It creates only the new `mobile` schema,
   snapshot tables, `mobile.ReadEmployee`, and `mobile.Publish`; existing tables
   and reports are untouched. Do not use the legacy CUS repair script for this.
3. `database/MobileChargesIdentityContract.sql` now contains the guarded,
   verified implementation installed in `MainInv`. It maps the full corporate
   login through `dbo.people.LOGONID` to `sap_number` (the workbook employee
   number), not the separate internal `peopleid`. Do not rerun it on the
   existing procedure. It preserves missing, null and duplicate results so
   the application rejects invalid/ambiguous mappings rather than choosing
   a record with `TOP` or concealing duplicates with `DISTINCT`.
4. Merge only the additions in `LeaseInvoice/MobileCharges.config.example`
   into the deployed configuration. Set an approved publisher allowlist using
   semicolon-separated full corporate logins, and the actual application-local
   Asset Voucher return page. Leave the existing authentication and connection
   strings intact. Keep secrets in secured deployment configuration, never Git.
5. Grant only the needed procedure EXECUTE rights: read on the view connection,
   publish on the publisher connection, and identity resolution on the identity
   connection. Use distinct SQL credentials or appropriately isolated Windows
   identities if separate database permissions are required; identical integrated
   connection strings use the same IIS identity. Do not grant table writes,
   `db_owner` or general database read access.
6. Require HTTPS and verified corporate authentication. Test missing and
   ambiguous identity mappings, unauthorized publishers, and cross-employee
   URL manipulation. The old `id` parameter is ignored.

### Workbook and publication behavior

Only explicitly allowlisted publishers can validate or publish. Upload
validation reads the whole `Billing Data` sheet by its four exact headers,
rejects invalid rows and formatted duplicate phones, and shows the period and
row count before an explicit confirmation. No employee rows are displayed
in the administrative preview.

The code reads `.xls` and `.xlsx`, up to 10 MB, 20,000 data rows and 128 columns.
For `.xlsx`, archive metadata is bounded to 2,000 entries and 64 MB expanded
content. Header names must be on the first row. The sample configuration adds
page-scoped ASP.NET/IIS request limits with room for multipart overhead.
Over-limit requests may be rejected by IIS before page code runs.

Raw workbooks are never written by application code: parsing is bounded and
uses the request stream. IIS/ASP.NET can still buffer uploads temporarily using
its own protected storage. Validated rows are held in server-side session until
confirmation/session expiry, not in hidden fields or the web root.

Employee/phone identifiers are preserved as text. Simple numeric identifiers
and zero-padding formats are supported; ambiguous numeric formatting is
rejected rather than silently dropping significant characters. Charges must
be numeric, with no currency symbol, up to 15 integer and 4 decimal digits;
zero is valid. Currency is not inferred. Activation dates may be blank, native
Excel dates, or text in `yyyy-MM-dd` or `M/d/yyyy` form. SQL date storage starts
at 1753; unsupported dates are explicitly rejected.

Publication atomically replaces the whole active snapshot, permits same-month
correction and later periods, and rechecks ordering under a database lock.
Reconfirming the current batch does not duplicate records. The read procedure
returns the period and assignments from one consistent snapshot. Previous
snapshots are deleted transactionally; this is not historical reporting or a
backup mechanism. A header-only valid workbook is an empty complete snapshot;
its zero row count is shown before confirmation.

### Local verification

Before deployment, run the **read-only, offline** preflight against a secured
staging copy of the complete site after merging the new settings:

```powershell
& .\scripts\Test-MobileChargesDeployment.ps1 -SitePath 'C:\staging\LeaseInvoice'
```

It checks the installed Framework on the machine running the script, required
overlay files, ExcelDataReader assembly identity/version, inline connection
targets, explicit publisher entries, local return-page existence, compression
reference, and page-specific upload limits. It never opens a SQL connection,
changes IIS, writes configuration, or prints connection strings/publisher names.
It exits `1` for missing, placeholder or invalid local prerequisites.

The committed example intentionally fails this check: it has no approved
database, publisher or return route. Do not invent these values just to obtain
a pass. Inherited/encrypted/external settings require manual review of effective
IIS configuration; the script requires explicit inline settings in the secured
site copy and does not decrypt configuration.

A pass is only a local configuration preflight, not DBA approval, verification
of the identity procedure, SQL availability or permissions, IIS authentication
or HTTPS, application-pool runtime, or a release authorization. The approved schema is installed, but application deployment remains blocked
until application permissions and identity resolution under the IIS runtime
account are verified.

### Separate local demo preparation

The user selected a separate local IIS staging site. This computer runs
Windows 11 Enterprise, but IIS is not installed and the agent session is not
elevated. No IIS site, binding, certificate or application pool has been created.

Prepare a new site directory without copying or changing the legacy site:

```powershell
& .\scripts\New-MobileChargesDemo.ps1 `
    -SitePath (Join-Path $PWD 'tests\bin\MobileChargesDemo') `
    -Server 'zcirving03' -Database 'MainInv' -IdentityDatabase 'MainInv'
```

This directory has already been prepared locally; the command refuses to
overwrite an existing directory. Generated `web.config` stays under ignored
`tests\bin`, uses three dedicated encrypted Windows-authenticated SQL
connections, denies anonymous application access, requires secure cookies,
and leaves the publisher allowlist empty. The landing/return page is a new
demo-only `Default.aspx`, not the production menu. No personal identifiers
are embedded. The read-only demo will report no published period until a
snapshot is available; its upload route denies all publication.

An administrator must first install local IIS with ASP.NET 4.x, .NET
Extensibility 4.x, ISAPI extensions/filters, Windows Authentication, request
filtering and the management console. Then configure a distinct CLR v4 pool
and HTTPS-only, loopback-bound staging site, disable anonymous authentication,
and enable Windows Authentication. Copy the prepared files to a dedicated
secured IIS directory and grant that pool only the required filesystem access;
do not grant IIS access to the whole repository or user profile.

The approved IIS SQL runtime identity is still required. Integrated Security
uses the application identity, not automatically the employee browsing the
page. A local virtual pool identity normally reaches remote SQL as the
computer account; do not assume the agent's SQL access is inherited by IIS.
Approve the runtime identity and grant only EXECUTE on the appropriate
procedures. Do not configure a personal administrator account as the pool
identity or store its password in scripts.

For an upload/publication demo, first approve a separate demo snapshot
database, install its own `mobile` schema, configure the read/publish
connections to that database, and explicitly authorize the test publisher.
The identity connection may continue to use the verified `MainInv` resolver.
Never publish synthetic snapshots into `MainInv` merely to make a demo work:
publication replaces the complete active snapshot.

Focused checks:

```powershell
& .\tests\Test-MobileChargesIdentity.Tests.ps1 -Server zcirving03 -Database MainInv
& .\tests\Test-MobileChargesDemo.Tests.ps1
```

The identity cases execute the repository procedure body against
connection-scoped synthetic temporary tables/procedures, not real employee
records. The installed procedure was also checked for one mapping using the
current Windows account without printing or saving the employee number.
The demo checks verify authentication/configuration safeguards, refusal to
overwrite existing sites, forbidden database targets and ASP.NET precompilation.

From the repository root in Windows PowerShell:

```powershell
& .\scripts\Restore-MobileCharges.ps1
& .\scripts\Test-EmployeeMobileCharges.ps1
& .\scripts\Test-MobileChargesPages.ps1
& .\tests\Test-MobileChargesDeployment.Tests.ps1
```

The restore fetches the declared ExcelDataReader 3.7.0 NuGet package, whose
.NET Framework 4.6.2 build has no extra package dependencies. The assembly is
copied to the overlay's `bin`; package and compiled output folders are ignored.
The tests compile VB.NET services, read synthetic in-memory workbooks, and
precompile both ASP.NET pages with the configuration example. They do not open
SQL connections, use production employee records, or apply deployment scripts.
Preflight tests use temporary synthetic site copies (including failure cases)
and verify that credentials do not appear in output.

The local checks passed: 34 synthetic assertions, the existing seven probe
preflight cases, and ASP.NET precompilation with the example configuration.
SQL transaction/concurrency
tests, real corporate identity resolution, real monthly workbook compatibility,
browser usability, the five-second target, and regression checks against the
other reports **remain pending in an approved staging environment**.

### Staging acceptance and rollback

Seed synthetic identities and two synthetic monthly workbooks. Verify
employee isolation (including duplicate display names and changed URL IDs),
missing/ambiguous mappings, zero charge, optional activation date, invalid
headers/rows, duplicate phones, unauthorized upload and confirmation, CSRF
rejection, correction/later-month publication and older-month rejection.
Confirm that omitted assignments disappear, unpublished uploads are invisible,
and concurrent reads never mix a period with another snapshot's assignments.
Force a failed SQL publication and verify that the previous snapshot survives.

Back up the two original employee page files and deployed configuration before
release. Roll back by restoring those page files/configuration and removing
only the new mobile files/assemblies if nothing else depends on them. Do not
drop the new database schema or alter legacy SQL objects automatically; DBA
review and the organization's backup/retention policy govern database cleanup.
