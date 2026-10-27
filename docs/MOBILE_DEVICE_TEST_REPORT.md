# AquaFlow Mobile Device Test Report

## Result

The current Customer/Admin Flutter source passes analysis and widget/unit
tests, and the current Android debug APK builds successfully. Physical-device
installation, launch, API access, catalog/cart interaction, and visual
verification remain **unverified**. The report does not treat an APK build as
device validation.

## APK artifact

The latest `flutter build apk --debug` completed with exit code 0. The output
was verified to exist and be readable:

- Path: `mobile/build/app/outputs/flutter-apk/app-debug.apk`
- Absolute path: `C:\Users\DELL\water-commerce-platform\mobile\build\app\outputs\flutter-apk\app-debug.apk`
- Size: 184,505,923 bytes

This debug APK uses the Android Emulator host default
`http://10.0.2.2:3000/api/v1`. A physical phone requires a reachable host LAN
URL supplied by `AQUAFLOW_API_BASE_URL`, or a configured USB reverse mapping
with a matching `127.0.0.1` API URL.

## Physical device attempt

The OPPO A73 with device ID `c650f532` was reported by
`adb devices -l` as online (`device`) in the prior device session. An APK
installation attempt targeted that physical device using `adb install -r`;
the operation timed out after 90 seconds without a package-manager error
message. The identified timed-out ADB install process was stopped; no
unrelated process was intentionally stopped.

Because installation did not complete, the following were not verified on the
phone:

- app installation or launch;
- USB reverse on port 3000 or phone-to-host API connectivity;
- customer catalog/cart interaction or authenticated login;
- startup logs from the installed app; or
- a device screenshot/visual inspection.

No credentials or tokens were entered or reported.

## Backend and emulator evidence

At the prior local-service check, `GET /api/v1/health/live` and
`GET /api/v1/health/ready` on localhost:3000 returned HTTP 200; readiness
reported the database connected. That verifies local service health only, not
phone connectivity.

An earlier emulator session reported successful APK installation and
`MainActivity` launch, but Android's launcher/System UI became unresponsive
during accessibility inspection. It did not provide reliable customer
catalog/cart visual validation. Do not treat this historical launch as
physical-device verification.

## Current code-level validation

The latest source passed `flutter analyze` (no issues), the full Flutter suite
(38 tests), `git diff --check` after report changes, and
`flutter build apk --debug` (exit 0). These checks validate code/build
behavior, not installation or runtime behavior on a device.

## Remaining device-test steps

1. Retry only when the physical phone and ADB connection are responsive; do
   not repeatedly reinstall while ADB shell/installer hangs.
2. Install the verified APK on `c650f532` and capture the actual installer
   result.
3. Configure the API for the phone's reachable network route (LAN URL or
   explicitly established `adb reverse`) and confirm the health endpoint from
   the device context.
4. Launch the app, capture startup logs and screenshots, then exercise the
   public catalog and cart before attempting login with an authorized test
   account.
5. Record results here only after observing them directly.
