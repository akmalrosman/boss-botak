# Boss Botak – Frozen Food Ordering & SME Management App

Flutter app for **Boss Botak**, a home-based SME selling frozen **otak-otak** and **pepes**
that currently takes every order manually through WhatsApp.
BIM30603 Mobile Application Development – final group project.

**Problem:** Orders, stock and money are tracked by hand in WhatsApp chats. That causes
missed or duplicated orders, overselling when stock runs out, no record of who the
customers are, and no idea whether the business is actually making a profit.

**Solution:** one app with two roles.

| Customer | Owner (Boss) |
|---|---|
| Browse and search the catalogue | Financial dashboard: sales, profit/loss, charts, best sellers |
| Cart (saved on the device) | Manage all orders and update their status |
| Checkout: pickup or delivery, date, notes | Record WhatsApp / walk-in sales ¹ |
| GPS + OpenStreetMap address, delivery fee by distance | Products and inventory, restock, low-stock alerts |
| Pay by **DuitNow QR** (upload receipt) or **FPX online banking** | Verify DuitNow receipts (approve / reject) |
| Track the order status, cancel while pending | Customer database, WhatsApp promo / call ¹ |
|  | Expense tracking with a category chart ¹ |
| PDF invoice, WhatsApp the boss | PDF invoices, mark orders paid |

¹ Built but **switched off** for the progress presentation. Turn it back on in
[`lib/config/features.dart`](lib/config/features.dart) by setting `expenses`, `customers` or
`recordSale` to `true`.

### Payments (prototype)
- **DuitNow QR**: the app shows a **dummy** DuitNow QR with the amount and the order reference.
  The customer pays and then uploads a screenshot of the receipt. The order shows
  *Verifying receipt* until the owner taps **Approve** (paid) or **Reject** (back to unpaid).
  In cloud mode receipts go to a **private** storage bucket and are viewed through short-lived signed links.
- **FPX Online Banking**: a **dummy** flow: choose a bank → simulated bank approval page →
  success screen with an FPX reference. No real bank is contacted. A real FPX gateway
  replaces it in the next phase.

---

## Install on a new laptop (Windows)

Follow the steps in order. Expect about an hour the first time, mostly downloads.

### Step 1: Install the tools

| Tool | Where | Notes |
|---|---|---|
| Git | https://git-scm.com/download/win | Keep the default options |
| Flutter **3.47.5 or newer** (stable) | https://docs.flutter.dev/install | Extract to a short path such as `C:\flutter`, **not** inside OneDrive or Program Files, and add `C:\flutter\bin` to your PATH |
| Android Studio | https://developer.android.com/studio | Needed for the Android SDK and the emulator |
| VS Code | https://code.visualstudio.com | Then install the **Flutter** extension (it also installs Dart) |

Java does not need to be installed separately. Android Studio includes it.

### Step 2: Finish the Android setup

1. Open Android Studio once and complete its setup wizard.
2. Go to **More Actions → SDK Manager → SDK Tools**, tick **Android SDK Command-line Tools (latest)** and click **Apply**.
3. Open a **new** PowerShell window and accept the Android licences (type `y` for each one):
   ```powershell
   flutter doctor --android-licenses
   ```
4. Check the installation. **Flutter** and **Android toolchain** must have a tick:
   ```powershell
   flutter doctor
   ```
   A warning about *Visual Studio* can be ignored. It is only for Windows desktop apps.

### Step 3: Download the project

The repository is private, so the owner must first add your GitHub account under
**Settings → Collaborators**. Git will ask you to sign in with your browser.

```powershell
git clone https://github.com/akmalrosman/boss-botak.git
cd boss-botak
flutter pub get
```

### Step 4: Add the Supabase keys

The keys are not stored in GitHub, so each laptop needs its own copy of `env/env.json`.

1. Create the file from the example:
   ```powershell
   Copy-Item env\env.example.json env\env.json
   ```
2. Open `env\env.json` and replace both values. Ask a teammate, or copy them from the
   Supabase dashboard under **Project Settings → API Keys**:
   - `SUPABASE_URL`: the base address only, like `https://xxxx.supabase.co` (no `/rest/v1/` at the end)
   - `SUPABASE_PUBLISHABLE_KEY`: starts with `sb_publishable_`

Never put the **secret** or **service_role** key here, and never commit `env/env.json`.

If you use the team's existing Supabase project, the database is already set up, so do
**not** run `schema.sql` again. For a brand-new project, follow
[Cloud mode](#2-cloud-mode-supabase-needed-for-the-cloud-database-requirement).

You can skip this step and use Demo mode, which needs no keys.

### Step 5: Start a device

- **Emulator:** Android Studio → **Device Manager → Create device → Pixel 8** → choose a
  **Google Play, x86_64** image → **Finish** → press ▶.
- **Real phone:** turn on **Developer options → USB debugging** and plug it in.

Check that it is listed:
```powershell
flutter devices
```

### Step 6: Run the app

**VS Code:** open the `boss-botak` folder, press **Ctrl+Shift+D**, choose
**Boss Botak (Supabase cloud)** or **Boss Botak (Demo mode - offline sample data)**, then press **F5**.

**Terminal:**
```powershell
# Cloud mode
flutter run --dart-define-from-file=env/env.json

# Demo mode
flutter run
```

The first Android build takes several minutes because it downloads Gradle and SDK files.

### If something goes wrong

| Message | Fix |
|---|---|
| `flutter is not recognized` | Add `C:\flutter\bin` to PATH, then open a new terminal |
| `version solving failed` or `requires SDK version ^3.13.4` | Run `flutter upgrade` |
| `cmdline-tools component is missing` or licence errors | Repeat Step 2 |
| `Did not find the file passed to "--dart-define-from-file"` | Create `env/env.json` (Step 4) and run from the project folder |
| App shows the **Demo mode** box when you wanted cloud mode | It was started without the keys file. Use the cloud option in Step 6 |
| `Repository not found` while cloning | Your GitHub account has not been added as a collaborator |
| **Use my location** says the address is too far | Emulator: **⋯ → Location**, set it to Batu Pahat |
| Strange build errors | Run `flutter clean`, then `flutter pub get`, then try again |

---

## 1. Quick start (Demo mode, no setup needed)

```powershell
flutter pub get
flutter run
```

Without cloud keys the app starts in **Demo mode**. All data lives on the device and comes
with about 75 days of sample orders and expenses. Use the **Customer** or **Boss (owner)**
buttons on the sign-in screen.

Build the APK:

```powershell
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

## 2. Cloud mode (Supabase), needed for the "cloud database" requirement

1. Create a free project at https://supabase.com.
2. **SQL Editor:** paste and run all of [`supabase/schema.sql`](supabase/schema.sql).
   It creates the tables, Row Level Security, server functions, the storage bucket and the sample products.
3. **Authentication → Providers → Email:** for an easy demo, turn off *Confirm email*.
4. Copy `env/env.example.json` to `env/env.json` and fill in the values from
   **Project Settings → API**: Project URL and the *publishable* (or legacy anon) key.
   `env/env.json` is git-ignored.
5. Run with the config file:
   ```powershell
   flutter run --dart-define-from-file=env/env.json
   flutter build apk --release --dart-define-from-file=env/env.json
   ```
6. Register the owner's account in the app, then make it the admin in the SQL Editor:
   ```sql
   update public.profiles set role = 'admin' where email = 'owner@example.com'
   returning email, role;
   ```

---

## 3. How the project meets the assessment requirements

| Requirement | Implementation |
|---|---|
| **6–12 interfaces** | 12 screens: Login/Register, Shop, Product Detail, Cart & Checkout, DuitNow QR Payment, FPX Payment, My Orders, Order Detail/Invoice, Profile & Settings, Dashboard, Manage Orders, Inventory (+ product form). Expenses and Customers can be switched on later |
| **Material Design 3** | `useMaterial3`, `ColorScheme.fromSeed` with brand colours, NavigationBar/Rail/Drawer, SegmentedButton, SearchBar, FilterChip, Cards, FAB, Badges, SnackBars, Dialogs, BottomSheets |
| **Accessibility** | Material 3 tonal colour pairs (contrast ratios not measured yet); layouts grow with the system font size (no fixed heights on text); `Semantics` labels on images, charts, KPI tiles and the order tracker; tooltips on every icon button; live regions for status messages |
| **Screen sizes & orientation** | NavigationBar in portrait, NavigationRail at ≥ 640 dp (landscape/tablet); adaptive product grid; two-pane layouts for checkout, product detail and login on wide screens; content width limited for readability |
| **Navigation patterns** | Bottom NavigationBar (customer and owner), NavigationRail, Navigation Drawer (owner) |
| **Visual feedback** | Ripple on every card and button; buttons show a spinner and turn off while working (`LoadingButton`); pull-to-refresh; progress bars; SnackBars with Undo; animated status tracker and page transitions |
| **Cloud database** | Supabase PostgreSQL: `profiles`, `products`, `orders`, `order_items`, `expenses`, plus Storage for product photos and payment receipts |
| **Local cache / offline** | `shared_preferences`: cart per user, theme setting, cached catalogue and orders. When the network is down the app shows the saved data with an "offline" banner |
| **External API + location permission** | `geolocator` runtime permission + **OpenStreetMap Nominatim** reverse/forward geocoding (HTTPS) → delivery address, distance and delivery fee |
| **Security (≥ 2)** | 1) Supabase Auth email/password with a password-strength check; session tokens kept in **encrypted secure storage** (Keystore/Keychain). 2) **HTTPS/TLS only**: the URL must be `https://` and Android cleartext traffic is disabled. 3) **No hardcoded keys**: values come in through `--dart-define-from-file`. 4) **Row Level Security**, a role check, and server-side order pricing and stock checks. 5) Payment receipts are kept in a **private** bucket |
| **Business / e-commerce (≥ 2)** | 1) Product listing, search, cart, ordering and checkout. 2) **Malaysian payments**: DuitNow QR with receipt verification, and an FPX online-banking sandbox flow. 3) **Monetisation**: distance-based delivery fee, free-delivery threshold, 5% bulk "Open House" discount with upsell hints |
| **SME concept** | Inventory, sales and gross-profit dashboard, digital PDF invoice, sales analytics, low-stock notification. Sales recording (WhatsApp/walk-in), customer database and expense tracking are built but switched off ¹ |

## 4. Architecture

```
Flutter UI (lib/ui)            Material 3 screens & widgets
      │ Provider (ChangeNotifier)
State (lib/state)              Session · Catalog · Cart · Orders · Finance · Settings
      │
Services (lib/services)        Location (GPS + Nominatim) · Contact (WhatsApp/tel/maps) · Invoice (PDF)
      │
Data (lib/data)                Backend interface
      ├── SupabaseBackend  ──HTTPS──► Supabase Auth / PostgreSQL (RLS + RPC) / Storage (product photos, private receipts)
      ├── DemoBackend      (on-device, same business rules)
      └── LocalCache       (shared_preferences) + SecureSessionStorage (flutter_secure_storage)
Core (lib/core)                Pricing rules · Analytics (P&L, series, customers) · Validators · Theme
```

Business rules such as pricing, delivery fee, discount, stock checks and permissions are
written twice: in Dart (`lib/core/pricing.dart`, `DemoBackend`) and in SQL (`place_order`,
`set_order_status`, `adjust_stock`, `submit_payment_receipt`, `review_payment_receipt`, `simulate_fpx_payment`). The server is the source of truth in cloud mode.

## 5. Testing

```powershell
flutter analyze
flutter test
```

27 automated tests:

- `pricing_test.dart`: delivery fee, free delivery, discount, distance.
- `analytics_test.dart`: profit and loss, sales series, merging customers.
- `demo_backend_test.dart`: authentication, stock reduction, overselling blocked, delivery radius, permissions, cancel and restock, owner sales, DuitNow receipt approve/reject, FPX sandbox.
- `widget_test.dart`: sign-in validation, browsing and add to cart, owner sign-out (menu and profile), owner dashboard in landscape with NavigationRail.

## 6. Things to customise

- Real prices and products: edit them in the app (Inventory). For demo mode, edit `lib/data/demo_seed.dart`; for the cloud, edit the seed at the bottom of `supabase/schema.sql`.
- Kitchen location and phone number: `lib/config/shop_config.dart`. Keep the coordinates in sync with the constants in `place_order` in `schema.sql`.
- Delivery fee and discount rules: `lib/core/pricing.dart` together with `place_order`.
