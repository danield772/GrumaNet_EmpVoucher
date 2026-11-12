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
