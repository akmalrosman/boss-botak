# Boss Botak

Flutter app for **Boss Botak**, a small business selling frozen **otak-otak** and **pepes** that
currently takes orders by hand through WhatsApp.
BIM30603 Mobile Application Development, final group project.

## Features

| Customer | Owner (Boss) |
|---|---|
| Browse and search products | Dashboard: sales, gross profit, best sellers |
| Cart and checkout (pickup or delivery) | Manage orders and update their status |
| Delivery fee by distance (GPS + OpenStreetMap) | Approve or reject DuitNow receipts |
| Pay by DuitNow QR or FPX | Manage products and stock, low-stock alerts |
| Track orders, PDF invoice | PDF invoice, contact customers |

DuitNow QR and FPX are **prototypes**: no real payment is made.

**Built with:** Flutter, Supabase (PostgreSQL, Auth, Storage), Provider

## Install on a new laptop (Windows)

### 1. Download the project

The repository is private, so ask the owner to add you as a collaborator first.

```powershell
git clone https://github.com/akmalrosman/boss-botak.git
cd boss-botak
flutter pub get
```

### 2. Add the Supabase keys

```powershell
Copy-Item env\env.example.json env\env.json
```

Open `env\env.json` and fill in both values (ask a teammate, or see **Supabase → Project Settings → API Keys**):

- `SUPABASE_URL`: `https://xxxx.supabase.co`, without `/rest/v1/`
- `SUPABASE_PUBLISHABLE_KEY`: starts with `sb_publishable_`

Never use the secret or `service_role` key, and never commit this file.

### 3. Run the app

1. Start an emulator (Android Studio → **Device Manager**) or plug in a phone with USB debugging on.
2. Open the folder in VS Code and run this in its terminal (**Ctrl + `**):

```powershell
flutter run --dart-define-from-file=env/env.json
```

Plain `flutter run` (or **F5**) starts **Demo mode** with sample data on the device.

### Common problems

| Problem | Fix |
|---|---|
| `flutter is not recognized` | Add `C:\flutter\bin` to PATH and open a new terminal |
| `version solving failed` | `flutter upgrade` |
| Cannot find the `--dart-define-from-file` file | Create `env/env.json` (step 2) |
| `Repository not found` | Ask to be added as a collaborator |
| Strange build errors | `flutter clean`, then `flutter pub get` |

## New Supabase project (only once)

Skip this if you use the team's existing project.

1. Create a project and run all of `supabase/schema.sql` in the **SQL Editor**.
2. Turn off **Confirm email** under **Authentication → Sign In / Providers**.
3. Register the owner in the app, then run:
   ```sql
   update public.profiles set role = 'admin' where email = 'owner@example.com' returning email, role;
   ```

## Build the APK

```powershell
flutter build apk --release --dart-define-from-file=env/env.json
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

## Tests

```powershell
flutter test
```
