# device_safety_info example

One small page per feature. Open a page to see the feature working on your device, and the
code to copy into your app.

```sh
flutter run
```

## Where things are

| File | What it shows |
|---|---|
| [lib/main.dart](lib/main.dart) | `DeviceSafety.initialize` with a few settings (optional) |
| [lib/home_page.dart](lib/home_page.dart) | The list of features |
| [lib/features/](lib/features) | One file per feature, e.g. [root_page.dart](lib/features/root_page.dart), [clipboard_page.dart](lib/features/clipboard_page.dart) |
| [lib/common/](lib/common) | The shared page layout and the result card |

Each file in `lib/features/` starts with a comment containing the code to copy.

## Optional settings

| Flag | Used by |
|---|---|
| `--dart-define=EXPECTED_SIGNING_CERT=<sha-256>` | Tampering page (the page shows the value to use) |
| `--dart-define=PLAY_CLOUD_PROJECT_NUMBER=<number>` | App integrity page (Android) |
| `--dart-define=INTEGRITY_SERVER_URL=http://<ip>:5080` | App integrity page: verify tokens with [server_dotnet](server_dotnet) |

## Tests

```sh
flutter test          # widget tests: every page renders
patrol test           # on a device: real native checks (see patrol_test/)
```
