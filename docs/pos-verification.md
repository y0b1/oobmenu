# Version 1.2: reports, audit journal and POS-only custom orders

- 24 native Android/Robolectric tests and 6 POS Flutter tests passed. Native tests cover Philippine period boundaries, revenue vs tender/change, renamed payment methods, saved X/Z snapshots, idempotent closing, closed-day enforcement, restart persistence, immutable triggers and signature/ledger tamper detection, PDF request trails, custom-order validation/idempotency, menu access denial and normal payment approval. Existing payment/shift/menu API tests still pass. Root menu source was unchanged in this extension; its tests were not rerun.
- POS `flutter analyze` and `git diff --check` passed. ARM64 release APK 1.2.0+5 built successfully, copied to `dist/OOB-POS-arm64.apk`, checksums updated. Existing Gradle/Kotlin deprecation warnings remain.
- Installed over the existing POS emulator without clearing data. SQLite migration retained both old paid orders and the active cashier shift. Reports showed PHP 360 for the current day, PHP 720 lifetime, and verified the new journal (two explicitly imported legacy sales).
- Saved X-reading #1, generated and saved a PDF to emulator Downloads, and pulled the resulting file to `docs/verification/pos-x-reading-1.2.pdf`. Inspected the report UI and PDF preview for readable totals and no clipping. Captured the custom-order dialog; a native integration test created and paid a custom order without adding it to the menu catalog. No new test sale was added to the running emulator.
- Force-stopped/reopened the POS. Lifetime/current-day totals remained the same, the audit chain verified with the original Android Keystore key, and the startup trail increased. Z-close was tested automatically, not applied to the running emulator's current day.
- The final APK was installed, its local service restarted, and the unchanged menu emulator displayed `Order · Connected`.
- Receipt printing is excluded at the owner's request. PDF reports use Android Save as PDF; no physical receipt printer or two-tablet hardware verification was performed.
- These are operational reports and tamper-evident records. BIR accreditation, statutory tax/discount/adjustment breakdowns and official invoice issuance remain unfinished; see `oobpos/README.md` for the explicit limits and physical checklist.

---

# Version 1.1.2: original menu styling and larger top controls

- Ordering, connection, cashier and shift screens reuse the original menu palette, Mulish/Manrope/Cormorant Garamond fonts, navy PillHeader and FooterWordmark. The original browsing screens remain unchanged; transactional layouts retain their functional structure.
- Header icons are 48dp with 96dp tap targets and 96dp toolbars, twice the previous sizes.
- 11 menu and 4 cashier Flutter tests passed. Menu source/test analysis and POS analysis passed. Native payment/server code was unchanged; the 17 native tests recorded for 1.1.1 were not rerun for this styling change.
- Both ARM64 release APKs built and were installed on the two Android emulators. POS service restarted and both apps displayed connected status. Inspected screenshots for menu ordering and POS queue/details with the larger controls. Existing order/shift history survived installation.
- Version 1.1.2+4 APKs and refreshed SHA-256 checksums are in `dist/`. Physical two-tablet checks remain pending.
- Screenshots: `verification/menu-style-1.1.2.png`, `verification/pos-style-1.1.2.png`.

---

# Version 1.1.1: customer Cash / QR choice

- Submit order opens a Cash / QR selection and freezes that choice in the request before sending.
- POS validates and stores the choice, and shows it in incoming orders, details and the payment verification dialog. It does not mark the order paid.
- 32 automated tests passed: 11 menu Flutter, 4 POS Flutter and 17 native Android tests. Added checks cover Cash/QR payloads, invalid choices, lost-acknowledgement/restart recovery, immutable idempotent requests, SQLite persistence and POS labels.
- Menu source/test analysis and POS analysis pass. The previously documented full-root asset lint findings remain outside this change.
- The previous QR image is not available in the repository; QR checkout currently asks the customer to obtain the QR from the cashier. No placeholder or fabricated payment QR is used.
- Both version 1.1.1+3 release ARM64 APKs built successfully and were copied to `dist/` with refreshed checksums.
- Physical two-tablet testing of this new choice remains pending.

---

# Version 1.1 verification: cashier shifts, PIN and payment methods

Run on 2026-09-11. POS remains in `oobpos/`; menu remains at root.

- **29 automated tests passed:** 16 native Android/Robolectric tests, 9 root Flutter tests, 4 POS Flutter tests.
- Native coverage includes required shift/review/payment confirmation/PIN, wrong-cashier PIN, owner-only settings, optional transaction PIN with mandatory shift PIN, persisted lockout, cash/change math, cash plus GCash/custom transfers, historical method snapshots, closing shortage/overage, beeper collision rollback/reuse, idempotent approval, shift handover, and SQLite version-1 migration. Existing pairing, API authorization and request-id tests also pass.
- Root `flutter analyze lib tools test`: clean. POS `flutter analyze`: clean. Full-root `flutter analyze` exits 1 with the same eight pre-existing informational findings in `assets/powered_by_peur_screen.dart` (one prefer-const, seven deprecated Matrix4 calls).
- Both release arm64 APK builds succeeded. Copies are in `dist/`, version 1.1.0+2, with refreshed SHA-256 hashes. The repository still uses development signing, as documented in the installation guide.
- On one Android API-35 tablet emulator, installed the update, created an owner password, added cashier Alex and non-cash method “Monique BPI”, opened a shift with ₱1,000, and closed it with ₱995. The native app displayed a ₱5 shortage. These emulator-only credentials/data are not bundled into either APK.
- Screenshot: `docs/verification/pos-owner-methods.png`. New POS screens reuse the palette and fonts, but are functional Material interfaces, not a full reproduction of the menu's custom UI/motion.
- The final native changes additionally guard against a shift changing between authorization and commit, and export orders plus reconciliation within one consistent database transaction. Native tests passed after those changes; the final APK was rebuilt and installed. Reopening Cashier shifts after that update/restart showed the persisted ₱995 closing count and ₱5 shortage.

Physical-device checks still required:

- [ ] Run the entire order → verbal recheck → manual payment check → optional PIN → beeper queue flow on two physical tablets with mobile data/internet off.
- [ ] Check cash, GCash and a custom bank transfer. Confirm only cash methods affect expected lockbox cash.
- [ ] Close and hand over between two cashiers; verify balanced, short and over counts.
- [ ] Try wrong PINs, disable/re-enable transaction PIN as owner, and verify staff cannot change the setting without owner authentication.
- [ ] Interrupt Wi-Fi before/after payment; reconnect and confirm the same paid order and beeper appear.
- [ ] Restart the POS during an active shift and after closing. Confirm cash counts, approvals and history survive.
- [ ] Complete an order, return/reuse its beeper, and export shift/order history to local storage.
- [ ] Check actual tablet hotspot isolation, background/sleep behavior and portrait/landscape layout.

Earlier version 1.0 verification follows. Its emulator flow is historical evidence, not physical two-tablet verification or a claim that every new screen was manually exercised.

---

# Offline POS verification

Environment: Flutter 3.44.3, Dart 3.12.2, Android Gradle Plugin 9.0.1, Gradle 9.1, Android Studio bundled JDK. Tested on 11 September 2026.

## Automated checks actually run

| Check | Result |
| --- | --- |
| Menu `flutter analyze lib tools test` | Passed, no issues |
| Menu `flutter test` | Passed, 9 tests (3 existing and 6 new) |
| POS `flutter analyze` | Passed, no issues |
| POS `flutter test` | Passed, cashier confirmation test |
| POS `./gradlew :app:testDebugUnitTest` | Passed, 9 Robolectric tests, zero failures/errors |
| Menu arm64 release APK | Built successfully, approximately 20 MB |
| POS arm64 release APK | Built successfully, approximately 17 MB |
| `git diff --check` | Passed |

Native tests exercise the production SQLite store and server request dispatcher: concurrent duplicate submissions, mismatched retry payload, price/quantity/modifier/note validation, device scoping, credential revocation, restart persistence, repeated payment approval, terminal cancellation, forbidden payment/history routes, setup-code expiry/single use/rate limiting across restarts. Customer tests exercise a simulated network against the production client state machine: lost acknowledgement, double tap, persisted frozen request, offline approval reconciliation, ordinary offline-cart behavior and certificate-pin validation. The cashier widget test checks that no approval call happens before the exact-number/exact-total confirmation dialog is confirmed.

The repository-wide unscoped `flutter analyze` also scans the pre-existing, unused `assets/powered_by_peur_screen.dart`. It reports eight pre-existing informational lints (one prefer-const and seven deprecated Matrix4 scale/translate uses). Those unrelated asset sources were not rewritten. Executable app sources and the new code are checked separately above.

The first Kotlin build exposed explicit-type requirements for heterogeneous SQLite bind arrays; these were fixed. AGP 9's Robolectric host packaging needed an explicit dependency on Flutter's asset-copy task; this is included in the POS Gradle setup. Existing Flutter/Gradle plugins emit deprecation notices about legacy Kotlin configuration; current builds work, but a future Flutter/AGP upgrade may require plugin migration.

`flutter doctor -v` reports missing Android command-line tools / unknown license status on this workstation; the already-installed SDK builds both apps successfully. It finds no physical Android tablet. iOS/macOS/browser deployment is outside this Android-native implementation.

## Emulator checks

One Android 15 / API 35 arm64 tablet emulator (`Medium_Tablet`) is available. Both release APKs were installed. The actual native POS foreground service starts, generates an Android Keystore certificate and displays its non-loopback LAN address. The original customer menu renders with bundled fonts. The installed-app walkthrough exposed an Android Keystore RSA signing mismatch. Switching to P-256 ECDSA with the pre-hashed signing operation required by Android Conscrypt fixed it. A real TLS 1.3 handshake then completed against the emulator service; its self-signed certificate is authenticated by the menu’s exact fingerprint pin, not by the workstation’s CA store.

The installed apps successfully paired over pinned HTTPS using the displayed LAN IPv4 address. A configured Handpicked Matcha (Traditional), 36000 centavos, was submitted with repeated checkout taps: exactly one order, `OOB-000001`, appeared. The menu showed Awaiting payment only after the server response. The menu process was then force-stopped. Cashier approval was recorded while the menu was offline, including operator and time. The POS process was also force-stopped and reopened: the Paid history entry persisted. After restarting the service and customer app, the menu restored `OOB-000001` and displayed Payment confirmed with the same total. The confirmation also fit in landscape, and Start new order returned to an empty customer cart. Paid history remained after that action and after installing the final POS APK in place. These checks used the actual installed release apps, native TLS and SQLite, not browser tabs or a mock server.

Screenshots: [cashier paid state](verification/pos-paid.png), [customer confirmation after both process restarts](verification/menu-payment-confirmed.png). The emulator clock was set to 31 July 2026, so test-order timestamps in screenshots reflect that simulated clock; the workstation test date was 11 September 2026.

This is one emulator, not two physical tablets, and it does not establish hotspot interoperability, radio behavior, sleep reliability or disconnected mobile-data operation on store hardware.

## Physical two-tablet acceptance checklist (not run)

Record tablet models, Android versions, hotspot interface/address, APK hashes, tester and date. Install the APKs on the actual tablets. Disable mobile data on both and disconnect the POS from internet-backed Wi-Fi. Connect the menu only to the POS hotspot. Do not run any server on a computer.

- [ ] Start POS service and confirm its actual hotspot address is shown. Pair using the directly compared full fingerprint and current code. Confirm both connection indicators.
- [ ] Submit a drink with quantity, paid modifier and notes. Confirm a single queue entry, correct centavo-derived total, snapshots and time. Customer must show Awaiting payment only after persistence acknowledgement.
- [ ] Tap checkout repeatedly. Retry after disrupting the first response. Confirm the same request returns the same order number and only one history entry.
- [ ] On the cashier tablet, open the matching order. Confirm the dialog shows the exact number and total. Approve after manual GCash checking; customer must show Payment confirmed with that order number. No connection to the separate GCash device is made.
- [ ] Repeat approval taps. Confirm one decision/time/operator and one payment record. Test cancellation of a different unpaid order with a reason. Confirm paid orders cannot be cancelled and cancelled orders cannot be paid.
- [ ] Disconnect menu Wi-Fi before approval, approve on POS, then reconnect. Confirm Paid appears without a duplicate submission.
- [ ] Disconnect before acknowledgement and restart the menu app. Confirm it restores the frozen request and resolves the original order. Confirm an ordinary unsent offline cart remains editable and never submits itself.
- [ ] Restart/force-stop POS and reopen/start its service. Confirm orders, sequence numbers, decisions and payment records survive. Repeat after a POS tablet reboot.
- [ ] Change the hotspot address. Update only the saved address on menu, retaining fingerprint/credentials and a blank code. Confirm the active order recovers.
- [ ] Enter an incorrect certificate fingerprint, expired code and five wrong codes. Confirm rejection and the five-minute lockout. Restart the service during lockout; confirm it remains locked.
- [ ] Attempt approval and history routes using a menu credential; expect rejection. Cancel an owned unpaid order, retry and reconnect; expect one saved cancellation. Attempt cancellation of a paid or another device’s order; expect rejection. Try another paired device's order ID; expect 404.
- [ ] Leave POS in the background and with its screen locked for at least 30 minutes; test another submission afterward. Check manufacturer power-saving behavior and hotspot timeout. Keep devices powered for store operation.
- [ ] Verify portrait and landscape, keyboard entry, large text, long notes/modifiers, queue scrolling, cancellation reasons and terminal-state actions without overflow.
- [ ] Export history to local storage or USB while offline. Open the JSON and check an approved and cancelled order. Confirm the export contains no credentials or TLS private keys.
- [ ] Disable all internet/mobile data again and repeat the complete order → manual approval → confirmation flow using only these two tablets and the hotspot. This is required before claiming fully offline physical deployment verified.

## Remaining repository-wide analyzer output

The unchanged asset-source file keeps unscoped analysis nonzero (exit 1):

```text
assets/powered_by_peur_screen.dart:135:28  prefer_const_constructors
assets/powered_by_peur_screen.dart:183:9   deprecated_member_use (scale)
assets/powered_by_peur_screen.dart:184:9   deprecated_member_use (translate)
assets/powered_by_peur_screen.dart:186:9   deprecated_member_use (translate)
assets/powered_by_peur_screen.dart:192:9   deprecated_member_use (scale)
assets/powered_by_peur_screen.dart:193:9   deprecated_member_use (translate)
assets/powered_by_peur_screen.dart:195:9   deprecated_member_use (scale)
assets/powered_by_peur_screen.dart:196:9   deprecated_member_use (translate)
8 issues found.
```

## Installable artifacts

The final arm64 APKs are copied to `dist/OOB-Menu-arm64.apk` and `dist/OOB-POS-arm64.apk`. `dist/SHA256SUMS` records their hashes. Both use the existing local development signing configuration, documented in the deployment README. Rebuilding changes APK hashes; regenerate the checksum file after rebuilding.

## 1.2.1 workflow and automatic cutoff checks (2026-09-11)

- Menu `flutter test`: 17 passed, including the supplied QR modal lifecycle, five-second/manual return to general menu, cancellation acknowledgement loss, approval/cancellation conflict and disconnected cancellation.
- POS `flutter test`: 9 passed, including automatic Cash/GCash selection with a disabled custom bank method, optional PIN and completed-order filtering.
- Native `:app:testDebugUnitTest`: 30 passed (12 order, 9 cashier, 9 report tests). New checks cover owned unpaid-only cancellation, idempotent restart recovery, default 20:30 cutoff, owner-only schedule changes, deadline enforcement, midnight reopening and multi-day catch-up without duplicate Z-readings.
- The existing emulator's Monique BPI method and cashier tracking were disabled through owner settings; earlier histories and lockbox counts retained.
- Original payment QR was subsequently supplied as `assets/images/oobqr.jpeg` and bundled unchanged. The themed modal clips only the surrounding artwork in its display, preserving the QR, recipient name and masked mobile number. Physical scan verification remains outstanding.
- Physical two-tablet tests remain outstanding. Automated clock-controlled cutoff tests do not constitute a physical overnight/background test.

Additional physical checks:
- [ ] Schedule a near-future cutoff on test hardware. Keep service running and UI backgrounded; confirm exactly one Z-reading is saved and further approvals fail until Philippine midnight.
- [ ] Power off before cutoff and reopen afterward; confirm catch-up, original payment totals and a single cutoff trail. Repeat across multiple missed days.
- [ ] Verify owner-only time changes and disabling the schedule; already-finalized days must stay closed.
- [ ] Test original QR readability/scanning after the exact supplied image is bundled; it remains visible until POS approval. Verify customer cancellation races safely with payment approval.

Final build checks: menu scoped `flutter analyze lib tools test` and POS `flutter analyze` both passed. Both arm64 release APK builds succeeded, were installed with update-in-place on emulator-5554/5556, and their saved pairing reconnected. Version 1.2.1+6 copies are in `dist/` with refreshed SHA-256 checksums. Root unscoped asset-source lint findings remain as documented above. Gradle reports existing Kotlin plugin/deprecation migration warnings, with successful builds.

UI inspection on Android emulators confirmed the active cashier is hidden, completed orders hidden by default, the report screen displays the daily 20:30 schedule, and the menu shows Connected with its existing unpaid order plus Cancel order. No test payment or cancellation was applied to that user's order.

The running Android POS emulator crossed the actual 20:30 deadline during this session. Without pressing Close day, Reports changed from Last closed day: None to 2026-09-11 and the audit journal increased from 21 to 23 entries. This verifies a scheduled cutoff on the emulator, not physical tablet power-management behavior.

Final QR visual check: the rebuilt menu APK was installed and opened on emulator-5556. Its saved OOB-000004 order reconnected and automatically opened the cream/navy PAY WITH QR modal. The original QR, AR***L C. recipient name and masked mobile number are fully visible, with a pill-shaped Cancel order button and staff connection control. Screenshot: `verification/menu-cancel-1.2.1.png`. The original JPEG remains untouched. Final menu tests: 17 passed; final scoped analyzer: no issues. QR scanning with an actual customer phone has not been performed.

## Customer controls and temporary sales-day pause (2026-09-11)

Removed Connected/settings controls from Your order and its QR modal. Staff connection settings now live in the existing authenticated Admin Panel. Removed the cashier payment-check checkbox; the final Approve payment and queue action sends the explicit confirmation. Menu tests: 17 passed; POS widget tests: 9 passed; native tests: 31 passed, including owner-only pause/re-enable with unchanged saved Z-readings. Both analyzers and arm64 builds passed.

Applied Enforce sales day OFF through owner-authorized Reports settings on emulator-5554. Reports visibly confirms “Sales day paused for testing. Re-enable before live use.” The existing closed day and ₱900 lifetime grand total remain unchanged. Automatic cutoff time remains configured at 20:30 for re-enabling. Fresh APK installs default to enforcement ON; updates preserve the test tablet's setting. The release reminder is in both READMEs. Both updated APK artifacts and SHA256SUMS have been refreshed.

## 1.2.2 menu lock and passwords (2026-09-11)

- Menu `flutter test`: 22 passed. Tests cover cold-start locking, inactivity reset by touch, five-minute locking, Android lifecycle pause/resume, unlock code persistence, persistent retry limiting, and owner password loading before the first authentication after restart.
- Native `:app:testDebugUnitTest`: 32 passed, including new default owner password initialization, authorized password change and no reset on restart.
- Scoped menu analyzer passed with no issues. Both arm64 release APK builds succeeded and version 1.2.2+7 was installed in place on the emulators; dist artifacts and checksums refreshed.
- Emulator verification: menu starts locked, accepts 1234, returns to existing browsing, and shows its code prompt again after Android KEYCODE_SLEEP / KEYCODE_WAKEUP. Screenshot: `verification/menu-lock-1.2.2.png`. POS local service reconnected while the menu lock was visible.
- Existing POS emulator owner password was changed through authorized owner settings to oob12345. Fresh POS installs initialize that default; custom passwords are preserved on later updates. Menu's legacy built-in oob123 is migrated to oob12345, while other saved passwords are retained.
- Five-minute idle timing was verified with controlled widget-test time, not by claiming an actual five-minute hardware wait. Physical tablet sleep/battery behavior still requires hardware testing.

Additional physical checks: sleep and wake the real menu tablet on a cart, QR dialog and general menu; enter the code and verify the same session is retained. Wait five actual idle minutes and confirm blocking. Change both codes in owner settings, restart and confirm old codes no longer work. Keep POS orders/history and the requested sales-day testing pause intact during development; re-enable cutoff before live use.
