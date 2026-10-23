# Testing both apps on this MacBook

Use the two **Android emulator windows**, not `flutter run -d macos` or browser tabs. The POS host service, SQLite bridge and Keystore are Android-specific.

The configured persistent virtual tablets are:

| Role | Android virtual device | ADB serial |
|---|---|---|
| Cashier POS | `Medium_Tablet` | `emulator-5554` |
| Customer menu | `OOB_Menu` | `emulator-5556` |

Both apps are installed and paired. Open them again from Terminal:

```sh
cd /Users/yobi/oobmenu
./tools/test-on-mac.sh
```

The launcher preserves existing app data and installs an APK only if its app is missing. It restores the Mac-only network forwarding rule. If the POS service has stopped, tap **Connection → Start local service**. The menu should reconnect automatically; there is no need for a new pairing code each time.

## Test the flow

1. POS: open **Cashier shifts** (lockbox icon), select **Alex**, enter a test opening cash count such as `1000`, and PIN `1234`.
2. Menu: back out of Connection to **Your order**, choose a drink, add it, and submit. The status must be Connected first.
3. POS: return to Orders and select the new matching order. Recheck verbally, then **Verify payment**.
4. Choose Cash, GCash or **Monique BPI**. For Cash, enter cash received and check the change. For transfer testing, simulate the external manual check; no real transfer is needed in this emulator dataset.
5. Enter a free beeper number, check the payment confirmation box, Continue, enter Alex's PIN `1234`, then **Approve payment and queue**.
6. Confirm the menu shows Payment confirmed and the same beeper/order number. POS **Queued** shows the order. Complete it when simulating collection/beeper return.
7. Close the shift with a physical/test cash count. Cash sales increase expected cash; transfer sales do not. Count below/above expected to test shortage/overage.

Existing emulator-only setup credentials:

- POS owner password: `EmulatorOnly2026`
- Cashier Alex PIN: `1234`
- Customer-menu staff password: `oob123`

These are test data in these emulators, **not defaults embedded in the APK**. New POS installations require owner setup. Owner settings controls cashier PIN requirements and payment methods.

## Connection details

For this Mac test, the menu uses **10.0.2.2:18443**. Android's host alias reaches a local ADB forward into port **8443 inside the POS emulator**:

```sh
~/Library/Android/sdk/platform-tools/adb -s emulator-5554 forward tcp:18443 tcp:8443
```

TLS remains pinned to the POS certificate, and pairing/device authorization is unchanged. The server does not run as a macOS development server. Direct `10.0.2.16:8443` access between these two emulator instances returned connection refused, so the working test uses the forwarding route. This route is for emulator development only; **physical tablets use the actual POS hotspot address and port 8443 with no Mac/ADB dependency**. See [Android emulator interconnection documentation](https://developer.android.com/studio/run/emulator-networking-interconnect).

The fingerprint remains whatever is displayed in POS Connection. If you need to pair again, generate a fresh code there and use that code plus the complete fingerprint on the menu. A different POS certificate requires deliberate re-pairing after resolving active orders.

To simulate an interruption, stop the POS local service, then start it again. To test approval while the menu cannot synchronize, turn Wi-Fi off on the menu emulator, approve on POS, then re-enable Wi-Fi. Do not clear app data. Test actual hotspot/sleep behavior separately on two physical tablets.

## Install rebuilt APKs without deleting history

```sh
~/Library/Android/sdk/platform-tools/adb -s emulator-5554 install -r dist/OOB-POS-arm64.apk
~/Library/Android/sdk/platform-tools/adb -s emulator-5556 install -r dist/OOB-Menu-arm64.apk
./tools/test-on-mac.sh
```

App updates may stop the POS service, so start it again from Connection. Closing emulator windows preserves their data. The AVD definitions live in `~/.android/avd/`; they are local machine setup, not committed app source. Two emulators can use substantial RAM; if they are slow, close other heavy apps.
