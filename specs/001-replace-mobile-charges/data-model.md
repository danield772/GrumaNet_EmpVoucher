# Data Model: Reemplazo de Mobile Device Charges

This is a logical model for the feature, not a physical SQL schema. Final table
names, keys, decimal precision, and transaction strategy depend on the
application's SQL definitions, which were not included in the supplied source.

## Entities

### BillingPeriod

Represents the month identified by the workbook filename prefix.

| Field | Type | Rules |
|---|---|---|
| year | Integer | Four-digit year parsed from the filename. |
| month | Integer | `1` through `12`, parsed from the `MM_YYYY` prefix. |

The period is distinct from the workbook receipt date and each assignment's
activation date. Compare periods chronologically for publication rules.

### UploadBatch

Represents one authorized upload and its validation/publication lifecycle.

| Field | Type | Rules |
|---|---|---|
| batchId | Identifier | Unique per upload attempt. |
| billingPeriod | BillingPeriod | Derived from the filename prefix; required. |
| sourceFileName | Text | Preserve for provenance; do not expose to employees. |
| uploadedBy | Corporate identity | Must be an authenticated, explicitly authorized publisher. |
| uploadedAt | Timestamp | Server-generated. |
| status | Enum | `Uploaded`, `Validated`, `Rejected`, `Published`, or `Failed`. |
| validationErrors | Collection | Row/column diagnostics with no sensitive values in logs. |

Only a completely validated batch may be published. A rejected or failed batch
must not change the active published snapshot.

### MobileAssignment

Represents one mobile line/device assigned to an employee for one billing period.

| Field | Type | Rules |
|---|---|---|
| billingPeriod | BillingPeriod | Required; part of the assignment key. |
| employeeNumber | Text | Read from `Description 2 - Emp Number`; required and matched to the employee mapping. |
| mobileNumber | Text | Read from `Mobile Number`; required, preserve significant characters, unique within a billing period. |
| monthlyCharge | Decimal | Read from `Equipment Payment Plan Charges`; required, source-faithful, zero is valid. |
| activationDate | Optional date | Read from `Activation Date`; blank is allowed, a supplied value must be valid, and it is distinct from billing period. |

One employee may have multiple assignments in the same billing period if their
mobile numbers differ. A phone number repeated within one period rejects the
batch, including when the employee number differs.

### EmployeeIdentity

Existing application identity mapping, not a new account store. Resolve the
authenticated corporate login server-side to one employee number. No user
supplied employee number can override that mapping.

## Relationships and lifecycle

- One `BillingPeriod` has many `MobileAssignment` records.
- One `UploadBatch` contains a complete staged set for exactly one
  `BillingPeriod`.
- A published batch replaces the complete active assignment set; it is not
  merged with the prior snapshot.
- A same-month correction replaces the published set for that month.
- A later month may replace the active set; a month earlier than the current
  published period is rejected.
- `Activation Date` belongs to the assignment and must never be used to derive
  the billing period.

## Workbook validation

The reader must locate the `Billing Data` worksheet and require these exact
headers:

1. `Description 2 - Emp Number`
2. `Mobile Number`
3. `Equipment Payment Plan Charges`
4. `Activation Date`

Reject an unreadable workbook, absent worksheet/header, invalid billing month,
missing/invalid employee number, missing/duplicate mobile number, invalid or
missing monthly charge, invalid non-empty activation date, or duplicate phone
within the period. A blank activation date is valid and must be shown as
unavailable. Stage and report row/column diagnostics without exposing other
employees' data to the publisher beyond what is necessary to correct the source
file.
