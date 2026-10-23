# Cashier shifts and payment queue

The existing root menu and `oobpos/` Android host remain in place. SQLite version 2 adds local owner authentication, cashiers, configurable payment methods and shift records. Only the private Flutter/native channel exposes these controls; the paired menu API remains submission and own-order reads only.

One lockbox has one active cashier shift. Start requires a named cashier, their four-digit PIN and an opening count. Close requires that cashier's PIN and a closing count. Expected cash is opening cash plus payments whose method was marked as adding to the lockbox at approval time. Closing records signed overage/shortage. This version does not track cash drops or expenses; counts assume neither occurs within a shift.

Owner first-run setup uses a password (at least eight characters), with no default credential. Owner authentication is required for cashier/PIN administration and payment-method changes, and enabling/disabling transaction PIN checks. PIN checks default on. Passwords and PINs use salted PBKDF2 hashes; failed checks persist and are throttled. Starting/closing a shift always requires its cashier PIN even when transaction PIN prompts are disabled.

Orders remain `awaiting_payment` for protocol compatibility, with a separate verbal confirmation timestamp/cashier. Approval requires verbal confirmation, an active shift, a selected payment method, explicit manual payment confirmation, a free beeper number and, when enabled, the active cashier PIN. SQLite commits the payment, shift attribution, method/name/cash snapshot, and `fulfillment: queued` together. Repeated approval returns the existing payment. Completing a queued order releases its beeper; history retains the number. Existing paid orders are retained without inventing a shift or queue entry.

Cash and GCash are seeded. Owner can add, rename or disable methods such as “Monique BPI”, and specify whether a method contributes to physical cash. Historical payments retain the accepted name and cash treatment. Cash tender/change are recorded for cash methods. Transfers are checked manually outside this system.

The POS UI provides Orders, Shifts, Owner settings and Connection. Queued orders display beeper numbers. The menu continues to display authoritative payment status and additionally shows its assigned beeper. Exports include shift reconciliation and payment snapshots, never credential hashes.

Validation: native tests cover authorization, migrations, shift reconciliation, workflow sequencing, beeper reuse and idempotency; Flutter tests cover the payment confirmation steps. Build/analyze both apps. Physical two-tablet/hotspot tests remain explicitly pending unless hardware is available.

## Customer payment choice

Submit opens a Cash / QR choice. Choosing one freezes `paymentChoice` (`cash` or `qr`) in the durable submission alongside its request ID. POS validates and snapshots the choice, displays it in incoming orders and details, and retains it across retries/restarts. It is the customer's intended method, not payment verification; the cashier still selects the actual configured method and approves manually. Legacy requests without this field remain accepted and display no invented preference. The original QR asset is unavailable, so QR orders currently direct the customer to the cashier for the payment QR.
