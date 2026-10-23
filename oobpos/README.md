# OOB POS: offline cashier and customer ordering

The cashier app lives in **`oobpos/`**. The existing Flutter customer menu remains at the repository root. Both are native Android apps. The original menu had no cart or checkout; its browsing screens and admin tools remain in place, with an added **Order** route.

The POS tablet itself runs the HTTPS server and stores orders in SQLite. No laptop, mobile data, cloud service, GCash integration, or third device connection is used during store operation. GCash checking happens independently; **Approve payment** records the cashier's manual decision.

## Architecture

```text
Customer tablet                             Cashier tablet / hotspot host
Root Flutter app                            oobpos Flutter app
  Existing three browsing tabs                Order queue, history, connection
  Order + cart + staff pairing                Private MethodChannel: oob/pos
  Persisted cart/request/order                    |
       |                                    Android foreground OrderService
       +--------- pinned HTTPS :8443 ------>   SQLite orders.db
                 2-second polling             Android Keystore TLS key
```

- `lib/ordering/order_client.dart`: pinned HTTPS, persistent cart, frozen submission, retry and reconciliation.
- `lib/ordering/order_screen.dart`: order builder, customer status and staff connection settings.
- `oobpos/lib/main.dart`: cashier queue, filters, details, approval confirmation and connection screen.
- `oobpos/android/app/src/main/kotlin/dev/luminatech/oob_pos/OrderService.kt`: bounded HTTPS listener, pairing and foreground service.
- `OrderStore.kt`: catalog validation, transactional SQLite and snapshots.
- `MainActivity.kt`: local-only cashier bridge and Android document export.
- `oobpos/lib/operations.dart`: shift counts, owner settings and staged payment dialogs.
- `CashierOperations.kt`: owner authentication, cashier PINs, shifts, payment methods and beeper queue rules.
- `tools/export_catalog.dart`: derives stable product IDs and centavo prices from the existing `MenuData`.
- `assets/catalog.json` and `oobpos/android/app/src/main/assets/catalog.json`: matching offline catalogs.

The foreground service is independent of the Flutter activity. Closing the cashier screen does not stop the service. Force-stop, Android's Stop-app control, a reboot, or aggressive manufacturer battery management can stop it; reopen the POS and tap Start local service. Orders and decisions survive these interruptions.

## Test on a MacBook

See [the two-emulator setup guide](../docs/testing-on-mac.md). On this configured Mac, run `./tools/test-on-mac.sh` from the repository root to open both Android apps and restore their local forwarding connection.

## Build and install

Prerequisites on the build computer: Flutter stable (verified with 3.44.3 / Dart 3.12.2), Android SDK including the compile SDK requested by Flutter, and JDK 17 or newer compatible with Gradle 9.1 (Android Studio's bundled JDK works). The apps target Android SDK 34 and require Android 7 / API 24+. Build dependencies need internet once on the build computer; the installed apps do not.

From the repository root:

```sh
flutter pub get
dart run tools/export_catalog.dart
flutter build apk --release --target-platform android-arm64
cd oobpos
flutter pub get
flutter build apk --release --target-platform android-arm64
```

Ready-built APK copies for this delivery are in `../dist/OOB-Menu-arm64.apk` and `../dist/OOB-POS-arm64.apk`, with hashes in `../dist/SHA256SUMS`.

Build outputs:

- Menu: `build/app/outputs/flutter-apk/app-release.apk`
- POS: `oobpos/build/app/outputs/flutter-apk/app-release.apk`

Install each APK on its respective tablet by USB/ADB or copying it to the tablet and allowing installation from that file source:

```sh
adb -s MENU_SERIAL install -r build/app/outputs/flutter-apk/app-release.apk
adb -s POS_SERIAL install -r oobpos/build/app/outputs/flutter-apk/app-release.apk
```

Use `adb devices` to get serials. These build commands produce arm64 APKs; for older 32-bit tablets omit `--target-platform android-arm64` to build a universal APK. Existing menu application ID: `dev.luminatech.oob_menu`. POS: `dev.luminatech.oob_pos`.

Release builds use the repository's existing debug signing convention so they can be installed for testing. For managed deployment, configure your own release keystore in both Gradle projects and retain it for updates. Never uninstall or clear POS app data to update: that deletes history and pairing identity. An APK signed with a different key cannot update an already-installed app in place.

## Start the store

1. On the **POS tablet**, enable a password-protected Wi-Fi hotspot manually in Android Settings. Disable its automatic hotspot timeout if available. Mobile data can remain off. Keep the POS powered during service.
2. Open **OOB POS → Connection → Start local service**. Wait for **HTTPS service running**.
3. The screen lists actual IPv4 addresses and interface names. Choose the hotspot interface's address, not an unrelated upstream Wi-Fi address. The port is **8443**, bound to **0.0.0.0**, not loopback. If no address is listed, enable the hotspot and wait for refresh.
4. Tap **Generate pairing code**. The code is single-use and valid for five minutes. Five wrong attempts lock setup for five minutes, including across service restarts.
5. On the **menu tablet**, connect Android Wi-Fi to the POS hotspot. Accept Android's **stay connected / use this network without internet** prompt if shown.
6. Open **OOB Menu → Order → gear**. Authenticate with the existing menu admin password (the unchanged initial default is `oob123`; change it in the existing admin panel).
7. Enter the POS IPv4 address, port, pairing code, and **all 64 characters** of the SHA-256 certificate fingerprint shown directly on the POS. Spaces/colons in fingerprints are accepted. Compare it on the physical cashier screen; do not trust a fingerprint received from the network.
8. Tap **Test connection and save**. Wait for **Connected**. The POS shows that the menu tablet has checked in within the last ten seconds.

The fingerprint authenticates the first TLS connection before sending the setup code. It is deliberately longer than the setup code. Subsequent connections use the saved certificate pin and random device credential.

## Taking an order

The customer can browse the original menu or open **Order** to choose drinks, quantities, allowed modifiers and notes. The ordering catalog shows POS prices. An offline cart remains editable, but checkout is disabled until connected.

On **Submit order**, the customer chooses **Cash** or **QR**. The chosen method appears on the customer status screen and in the POS incoming queue, order details and payment dialog. It is a requested method, not proof of payment; the cashier still records the actual method and approval. The original QR image has not been supplied in this repository, so the QR option currently directs customers to ask the cashier for the payment QR.

After the choice, the menu first commits a random request ID and the exact request to local storage. Repeated taps are blocked. The POS validates every product, integer quantity (1–99), permitted modifier, duplicate modifier, note length and expected unit price. It calculates totals in centavos from its catalog. A stale price gets an explicit rejection; remove/re-add the affected line to review the current price and submit deliberately again.

Only a committed POS response causes **Awaiting payment** and an order number to appear. If the response is lost, **Submitting** stays visible, the cart is frozen, and only that exact attempted request is retried. Ordinary unsent carts never submit automatically.

The cashier opens the matching order and taps **1. Recheck verbally with customer**. Read back items, quantities, modifiers, notes and total, then confirm. An active shift is required. If the shift changes before payment, the new cashier must recheck the order.

Tap **2. Verify payment**, select Cash, GCash or a custom payment method, and manually check payment. Cash methods require the received amount and show change. Transfer methods instruct the cashier to check the separate unrelated device. Enter the beeper number (1–9999), optionally enter a reference, and check the payment confirmation box. Tap **Continue**. The final dialog displays the order number, exact total, method, beeper and assigned cashier; enter the cashier's four-digit PIN if the owner has enabled it. **Approve payment and queue** commits payment and queue entry together.

The **Queued** filter shows paid orders oldest by approval time, with beeper numbers. A beeper cannot be assigned to another queued order. **Order collected / beeper returned** completes the order and releases the beeper for reuse. History retains the number and all payment details. Unpaid orders can be cancelled with an optional reason; PIN checks also apply to cancellations when enabled. Paid orders cannot be cancelled or refunded in this app.

The customer receives **Payment confirmed**, the order number and beeper number on the next successful poll (normally within two seconds). **Start new order** clears the customer session after a final payment/cancellation decision and preserves POS history and the preparation queue.

## Cashier shifts and owner settings

On first use, open the POS **Owner settings** shield icon and create a password of at least eight characters. There is no default POS owner password; the existing customer-menu admin password is unrelated. Add each cashier's name and four-digit PIN. Owner access expires after five minutes, locks when this screen closes, and is lost on restart. Reopen/unlock if a settings save reports an expired session. Owner settings also allow changing the owner password. Keep it safely: there is no password-recovery bypass.

**Require cashier PIN per transaction** defaults on. Only the authenticated owner can change it. With it off, the active shift still determines who approved each payment, but possession of the unlocked POS is sufficient for approvals/cancellations. Shift opening and closing always require the assigned cashier PIN. Five wrong password/PIN attempts lock that identity for five minutes, including across process restarts. Never share cashier PINs.

Open the **Cashier shifts** lockbox icon. Select the cashier, count physical cash and enter the opening count in pesos, then enter that cashier's PIN. Only one shift can be active for the shared lockbox. Counts and active cashier survive restarts. To hand over, close the current shift first and let the next cashier independently count their opening cash.

**Close shift and count cash** records the actual closing cash and cashier PIN. The completed report shows opening count, payment totals by method, cash sales, expected lockbox cash, actual closing count and shortage/overage. Expected cash = opening count + approved sales whose payment method adds physical cash. Cash change is deducted from tendered cash, so only the order total contributes. GCash and bank transfers do not contribute unless the owner explicitly configures them as cash. Example: opening ₱1,000 + ₱170 cash sale = ₱1,170 expected; a ₱1,165 closing count records a ₱5 shortage. Closed shift history is persistent and immutable. Queued paid orders can still be collected after a shift closes.

This version assumes **no cash drops, expenses or other lockbox movements during a shift**. Such movements will appear as differences; there is no cash-movement ledger. Cashier accounts cannot be edited or disabled during their active shift. Legacy payments from before version 1.1 remain in order history without invented shifts or beeper assignments.

## Custom payment methods

Owner settings starts with **Cash** (adds to lockbox) and **GCash** (non-cash). Use **Add payment method** for names such as **Monique BPI**, then choose whether it **Adds physical cash to lockbox**. Leave this off for bank transfers and e-wallets. The owner can rename or disable any method. Disabled methods are unavailable for new payments. Names and cash treatment are snapshotted at approval, so edits do not rewrite old receipts or shift totals. The app does not contact any payment provider or verify any transfer.

## Recovery

- **Wi-Fi interruption:** reconnect to the hotspot. The menu polls again and reads the authoritative order. Payment approval while disconnected is retained.
- **Lost submission acknowledgement:** leave the attempted order open. It retries with the saved request ID and returns the same order, even if already paid.
- **POS address changed:** update the address/port in menu staff settings, keep the same fingerprint, and leave pairing code blank. The credential and pending order stay intact.
- **POS process stopped or tablet rebooted:** reopen POS, start the service, then reconnect. Order numbers and decisions come from SQLite, not memory.
- **Menu app restarted:** the cart, pending body/request ID, accepted order and pairing settings reload from one saved session record.
- **Wrong certificate / expired certificate / wrong clock:** the connection fails closed. Compare the actual POS fingerprint and correct tablet time. Do not disable TLS validation. The POS certificate is generated for ten years and persists in Android Keystore; replacing the POS installation requires fresh pairing.
- **Revoke paired menu devices:** available on POS Connection after confirmation. Complete active orders first. Old credentials become unusable; pairing creates a new device identity, which cannot retrieve orders owned by the old identity. There is intentionally no cross-device recovery bypass. Revocation does not delete POS history.
- **Local storage failure:** no new request is sent before its local retry identity is saved. A restore failure keeps browsing available and disables ordering rather than discarding an uncertain order.

## Catalog and existing admin tools

The POS is initialized from all 20 drinks and six powder variants in `lib/data/menu_data.dart`, with the existing coffee add-ons and mutually exclusive whisking choices. No products are invented. IDs are generated from names (powder IDs use enum names); keep IDs stable if changing names in a future catalog migration.

The existing menu admin's on-device edits, featured cards and availability settings continue to control its original browsing screens. They are **not** authorized to change POS prices or create sellable products. This version has no inventory or POS catalog editor. To change the sellable catalog, edit the source menu data, run `dart run tools/export_catalog.dart`, rebuild and update both apps. Review any previously saved menu-admin overrides so the browsing display agrees with the sellable catalog. Every accepted order retains its original names, modifier names, quantities and prices even after a catalog update.

## Security and Android behavior

- TLS 1.2/1.3 only. Every menu request validates the exact certificate SHA-256 fingerprint, expected address/port and validity period. The HTTP client's trust store is empty; its certificate callback approves **only** this pin, never arbitrary self-signed certificates. No cleartext fallback, disabled certificate validation, browser flags, CA service or internet is required.
- The POS P-256 ECDSA private TLS key is non-exportable in Android Keystore. Its key policy permits the pre-hashed signature operation used by Android Conscrypt. Device secrets are 256-bit random tokens; only their SHA-256 hashes are stored on POS. Menu credentials are in app-private preferences; Android backups are disabled for both apps.
- The API exposes only `POST /v1/pair`, authenticated `GET /v1/catalog`, `POST /v1/orders` and `GET /v1/orders/<id>` scoped to the caller. Customers may also POST `/v1/orders/<id>/cancel` for their own unpaid order only. No network approval, unrestricted history or cashier control endpoint exists.
- Cashier authority uses the **physical POS app**, its active shift and optional transaction PIN, through its in-process native channel. Owner settings require a separate password. There is no administrator secret in the menu or shared assets. Use Android screen lock and restrict access to the cashier tablet. Rooted/compromised devices and people with access to the unlocked POS are outside this trust boundary. The menu's existing admin password is only a local settings gate, not payment authority.
- Requests are bounded (64 KiB bodies, 16 KiB headers, four workers, bounded queue, socket timeouts). Pairing is globally rate-limited to resist source-address changes. Hostile hotspot clients can still cause denial of service; use a private WPA2/WPA3 hotspot password.
- Both manifests request `INTERNET` and disallow cleartext traffic. POS additionally requests `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_CONNECTED_DEVICE`, `CHANGE_NETWORK_STATE` and `WAKE_LOCK`. The connected-device foreground type is appropriate for serving the other tablet over a local network. Hotspot toggling is manual; no privileged tethering API is used. The service starts from the visible POS UI and maintains an ongoing notification and CPU wake lock while running.
- No SMS, notification-reading, payment-provider, camera, location, storage-wide or GCash permissions are requested. File export uses Android's document picker. Android 13+ can hide the service notification when notification permission is denied; the foreground service still appears in Android's active-app controls. This app does not rely on notification permission to serve orders.
- Target SDK 34 does not require a separate runtime LAN permission for these IP sockets. Reassess local-network permissions before raising the target SDK. IPv4 hotspot hosting is required in this version; IPv6-only LANs and browsers/iOS are not supported.
- OEM hotspot isolation and battery management vary. The physical checklist must be run on the actual tablets, including locked-screen/background operation. This implementation does not promise uninterrupted hosting after Android force-stop or battery shutdown.

Owner passwords and cashier PINs use individual random salts with PBKDF2-HMAC-SHA1 (210,000 iterations), supported on all app target devices ([Android algorithm support](https://developer.android.com/reference/javax/crypto/SecretKeyFactory)). Four-digit PINs are low entropy: throttling protects online attempts, but a compromised/rooted device with database access can attack them offline. Keep Android device security enabled.

References: [Android foreground service types](https://developer.android.com/develop/background-work/services/fgs/service-types), [Android Keystore certificate generation](https://developer.android.com/reference/android/security/keystore/KeyGenParameterSpec), [Dart certificate callback](https://api.dart.dev/dart-io/HttpClient/badCertificateCallback.html).

## Storage and export

POS SQLite is in app-private `databases/orders.db`. Tables: `devices`, `orders`, `payments`, `pos_settings`, `cashiers`, `payment_methods`, `shifts`, `sales_ledger`, `journal`, `saved_reports`. Database version 3 automatically migrates versions 1 and 2 without clearing orders or approvals; earlier payments are imported once into the sales ledger and explicitly identified as pre-audit history. A transaction and unique `(device, request)` constraint prevent duplicate accepted orders. One payment row per order is enforced by primary key. SQLite uses full synchronous commits before returning success. Repeated reads/polls expose committed state; there is no transient event log to lose.

Menu cart/session data uses the existing Android SharedPreferences plugin's synchronous commit API and is awaited before submission. Credentials are never part of the shared catalog.

On POS **Connection → Export order history to a local file**, select Downloads, local storage or a USB drive in Android's system file picker. The JSON archive contains schema version, export time, accepted snapshots, payment/cancellation decisions, cashier names, payment-method configuration and shift reconciliation reports, signed audit entries, sales ledger and saved readings; it excludes PIN/password hashes, owner sessions, device credentials and TLS keys. Export periodically and before device maintenance. This is a readable order-history backup, not an automatic restore mechanism or full device migration. There is no import UI in v1. Uninstalling, clearing app data or losing the tablet without an export loses its history. Protect exported files as cashier records.

## Automated checks

From repository root:

```sh
flutter analyze lib tools test
flutter test
cd oobpos
flutter analyze
flutter test
cd android
# Set JAVA_HOME to your supported JDK (Android Studio's bundled JDK is suitable).
./gradlew :app:testDebugUnitTest
```

Native tests use Robolectric to exercise the actual SQLite store, request validation, network permissions and setup-code rate limiting. Flutter tests exercise customer persistence/retries and the cashier confirmation dialog. See [`../docs/pos-verification.md`](../docs/pos-verification.md) for results actually obtained and the physical checklist.


## Reports and POS-only custom orders (1.2)

Use the **Reports** pill below the cashier header. Select Daily, Weekly or Monthly and a date. Reports use Asia/Manila midnight boundaries, Monday–Sunday weeks and calendar months. They recognize revenue when the POS approves payment, not when the customer submits an order. Cash tendered and change are excluded from revenue. Cashier and payment-method breakdowns preserve accepted names, including custom bank names after renaming. Unpaid cancellations appear separately and do not reduce paid sales. Zero-sales periods are supported.

**Save summary** retains a permanent snapshot with its generation timestamp. **Save X-reading** saves a non-closing snapshot for the selected day. **Close day: Z-reading** requires an owner password and saves one final reading per day. Closing today blocks further approvals and unpaid cancellations today; use it only after the final transaction. Close dates in chronological order. A repeated close returns the same record. The lifetime grand total never resets. Saved readings stay unchanged when new sales are added. Later summaries can include later sales; compare matching generation cutoffs.

Select a saved reading, then **Save as PDF**. Android opens its system print dialog: choose **Save as PDF** and a local destination. Reports are rendered on the tablet without internet. The journal records each request, including repeat requests, before the dialog opens; a cancelled/failed print request is still a request, never proof that paper was printed. **Receipt printing is deferred at the owner's request.** There is no thermal-printer integration or customer receipt button.

**Business details** requires owner unlock. Enter the registered business name, TIN, address, VAT/non-VAT status, machine serial, PTU, POS model/accreditation number and MIN from actual registration documents. Unknown fields stay explicitly unconfigured. Saving these fields does not register or accredit the app. New sales and saved reports retain business-detail snapshots; edits do not rewrite old records.

**Custom order** is a POS-only pill. During an active shift, enter one custom line (item name, quantity 1–99, positive unit price in PHP and optional notes). It does not modify the product catalog or customer menu. The native POS computes the centavo total, creates an awaiting-payment order with a request ID, and applies normal verbal review, payment verification, optional cashier PIN and beeper requirements. Accepted custom items cannot be edited: cancel the unpaid order and create a corrected one. The menu API rejects custom product IDs and cannot access POS-local orders. These sales contribute to all sales reports and cashier lockbox totals when paid with a cash method.

## Audit integrity and compliance limits

`Reports.kt` manages an append-only SQLite sales ledger, journal and saved reports. SQLite triggers reject updates/deletes; each journal entry signs its sequence, previous signature and canonical event data using an HMAC key held in Android Keystore. Financial changes, grand total, order/payment and journal entries commit together. Verification checks the signature chain and reconciles signed sale/report snapshots with their stored rows. Startup, custom-order creation, acceptance/review/payment/cancellation, shift changes, business-profile changes, saved readings and export-to-PDF requests leave a trail. The journal began with this upgrade; it cannot establish how pre-upgrade payments were handled.

This is **tamper-evident app storage, not absolute tamper-free hardware**. Root access, complete database rollback, clearing app data, uninstalling or destroying the tablet are outside its guarantee. HMAC validation needs the original tablet's Keystore key, which is deliberately not exported. Keep dated JSON exports outside the tablet to retain independent history/checkpoints; JSON export is not a supported restoration or device-migration format. Loss of the key cannot be silently repaired by claiming old signatures are valid. SQLite in flash survives ordinary app/device restarts, not hardware loss. A backwards clock blocks new payment approval until corrected; keep the offline tablet date/time accurate.

These are operational X/Z and sales summaries, **not a claim of BIR accreditation or full statutory-format compliance**. Tax classification, VAT/exempt/zero-rated breakdowns, statutory discounts, returns/void adjustments and official invoice issuance/numbering still require a separate fiscal implementation and review against the applicable business registration. No fake PTU/accreditation details are supplied. References: [BIR RMO 24-2023, including reading formats](https://bir-cdn.bir.gov.ph/local/pdf/RMO%20No.%2024-2023.pdf) and [BIR invoicing guidance RMC 77-2024](https://bir-cdn.bir.gov.ph/BIR/pdf/RMC%20No.%2077-2024%20Digest.pdf). Receipt printing remains out of the current scope.

Physical checklist for this extension:
- Verify daily/weekly/monthly boundaries and offline date/time on the actual POS tablet.
- Create a POS-only custom order; confirm it stays out of the menu and becomes one paid sale after the normal cashier checks.
- Save X, approve a later payment, verify X remains unchanged and a refreshed summary increases.
- At actual end of day, save Z once; retry it and confirm there is no second Z and no same-day approval/cancellation.
- Restart the POS and confirm readings, grand total and audit verification survive.
- Save reports as PDFs to local storage and retain an audit JSON export on another storage device.

## Simplified counter workflow (1.2.1)

Owner settings can turn off **Cashier tracking and shifts** temporarily. This hides the active cashier and skips transaction PINs; approvals record **POS operator**. Existing accounts, shift counts and history remain. Cash sales still contribute to an already-open lockbox shift until it is closed with the original cashier credentials. Re-enable tracking to restore the normal shift flow.

The queue shows **Uncompleted** and **Completed**, with **Don't show completed orders** on by default. Payment status remains separately recorded; cancelled orders are in completed history. Payment methods automatically follow the kiosk choice when one enabled method matches: Cash selects Cash, QR selects GCash when GCash is the only enabled non-cash method. The owner can disable custom methods without removing earlier payment snapshots.

The customer can cancel their own unpaid order only after POS acknowledgement. Paid confirmation returns to general browsing after five seconds, or immediately using **Start new order**. Powder names use OOB Level 1, 2 and 3, preserving catalog IDs and old order snapshots.

The awaiting QR modal loads the original supplied `assets/images/oobqr.jpeg` offline until approval. A display-only crop preserves the QR, recipient name and masked mobile number while hiding festive artwork. The source file is unchanged. The cream/navy modal cannot be dismissed accidentally; Cancel order confirms cancellation with the POS, and staff connection settings are available from the menu Admin Panel via its POS connection button. Connection status and settings controls are hidden on Your order and the QR modal.

## Automatic daily cutoff

**Reports → Automatic cutoff** lets the owner change the time or disable the schedule. It defaults to **enabled, 20:30 (8:30 PM), Asia/Manila**. The cutoff saves the final Z-reading, then blocks payment approvals and unpaid cancellations until midnight. Changing or disabling the schedule does not reopen an already-closed day. Cashier shifts remain open until their actual closing cash is counted manually.

The Android foreground service checks every 15 seconds, including when its UI is in the background. Payment authorization enforces the exact deadline independently of that timer. The existing service wake lock is used; no exact-alarm permission, internet clock or extra computer is needed. Keep the service running and the tablet clock correct. Android force-stop, power-off or a stopped service prevents background execution; reopening the POS catches up missed daily cutoffs in chronological order. A durable cursor, one-Z-per-day index and atomic journal/report transaction prevent duplicate closing after restart. No days before this feature was enabled are automatically closed. A missed cutoff records its scheduled time separately from actual generation time.

## Release reminder: re-enable sales day

Sales-day enforcement is temporarily paused on the development emulator for continued testing after cutoff. Before any live APK handover or live use, open **Reports → Automatic cutoff**, authenticate as owner, turn **Enforce sales day ON**, keep **Enable automatic cutoff ON**, and confirm **20:30**. A fresh install defaults to enforcement on. Updating an existing tablet preserves its settings, so an APK update alone does not re-enable a paused test tablet.

Pausing is owner-only, journaled and local to that tablet. It skips automatic closing and closed-day payment blocks, retains audit/clock checks and does not edit saved Z-readings. Sales recorded while paused are marked `salesDayEnforced: false` in their ledger snapshot. Use this mode only for testing: later test sales are not retroactively inserted into a previously finalized Z-reading. Re-enable before live use.

Payment verification no longer has a separate checkbox. The final **Approve payment and queue** action records the cashier's explicit confirmation; transfer checking remains manual on the unrelated payment device.

## Menu sleep/idle lock and owner passwords (1.2.2)

The customer menu prompts for its four-digit unlock code after five minutes without touch/keyboard activity, after Android sleep/backgrounding, and on a cold app start. Default code: **1234**. The lock covers all routes and payment dialogs while leaving the cart and POS synchronization intact. Five incorrect attempts impose a persistent five-minute retry delay. The local app lock is separate from Android's device lock.

Menu owner password defaults to **oob12345** (the previous built-in `oob123` is migrated). Open the existing Admin Panel using the settings icon on Most Ordered. Its PIN icon changes the menu unlock code with confirmation; the lock icon changes the owner password. Saved custom passwords remain effective after restart and are loaded before authentication.

The POS owner password defaults to **oob12345** on a new installation. Change it through **Owner settings → Change owner password**. Existing custom POS passwords are never overwritten by updates; the development emulator's owner password was explicitly changed to the requested value through its owner UI. Owner credentials and menu unlock codes are local to each tablet, not cloud-synchronized. The earlier temporary sales-day pause remains in effect on the test POS and must be re-enabled before live use.
