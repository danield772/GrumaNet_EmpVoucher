# UI Contract: Mobile Device Charges

This internal Web Forms UI contract defines observable behavior, not an HTTP API.
The current application uses server-rendered `.aspx` pages.

## Employee view

**Entry**: Employee selects Mobile Device Charges from Asset Voucher.

**Identity**: Use the authenticated corporate account and the existing
server-side employee mapping. Do not accept an employee number from a URL,
query string, or form field as authorization.

**Successful response**:

- Show the employee context and published billing month.
- List the employee's rows with mobile number, monthly equipment payment charge,
  and activation date when supplied. If it is blank in the source, show that no
  activation date is available instead of treating it as the billing month.
- Preserve phone characters and show a valid zero monthly charge as zero.
- Include a clear return link to the Asset Voucher selection.

**Empty state**: If the identity is valid and there are no rows for the current
published month, state that no mobile assignments are listed for that month.

**Failure states**: Distinguish an unrecognized/unmapped identity, unavailable
data, and a failed query. Do not expose another employee's records, database
details, connection information, or credentials.

## Authorized upload and publication

1. Only a specifically authorized TI publisher can open or submit the upload flow.
2. The publisher selects a workbook. The application derives `MM_YYYY` from the
   filename prefix and reads `Billing Data` by the exact required headers.
3. The application validates the full set and presents the derived period,
   row count, and actionable validation errors. No employee view changes during
   this stage.
4. The publisher explicitly confirms publication. The application rechecks the
   current published period and authorization, then replaces the full snapshot
   atomically.
5. On success, confirm the published month. On rejection or failure, explain
   the actionable reason and keep the previous published snapshot unchanged.

Same-month correction and later-month publication are allowed. Earlier-month
publication is rejected. Re-uploading a valid file must not create duplicate
assignments.

## Accessibility and scope

The employee list and upload controls must be keyboard-operable, have
understandable labels, and remain readable on narrow screens. The replacement
must not alter PC Asset Charges behavior or navigation.
