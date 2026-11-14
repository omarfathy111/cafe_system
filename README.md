# Café Management System

A local Flutter Windows app for managing café tables, PlayStation rooms, orders, and sales.

## Run the Project

```powershell
cd D:\cafe_system
flutter pub get
flutter run -d windows
```

## Analysis and Tests

```powershell
flutter analyze
flutter test
```

The `analysis_options.yaml` file uses `flutter_lints` with additional rules to prevent `print` statements in the app, keep imports ordered, and prefer `final` for local variables. The tests in `test/cafe_models_test.dart` cover item and discount calculations, order totals, PlayStation sessions, and inventory.

The project uses `sqflite_common_ffi` to run SQLite on Windows. The app creates the database automatically on first launch. The database stores menu products, tables, PlayStation rooms, orders, product recipes, ingredient inventory, ingredient usage per invoice, removed ingredients per product, and settings.

```text
%LOCALAPPDATA%\CafeSystem\cafe_system.db
```

The app automatically upgrades the database version when the schema changes while preserving existing orders and sales. If it finds the legacy `cafe_data.json` file in the `CafeSystem` folder, it attempts to import it once, then renames it to `cafe_data.json.migrated.bak` to keep a backup.

## Ingredient Management

From the **Ingredients** tab, you can add an ingredient with its unit of measurement and current stock, restock it, and define how much of each ingredient is used in one cup or item. When an invoice is paid, the app deducts the used ingredients from inventory, excluding any ingredients the customer requested to leave out.

The app records ingredient usage at the time of sale, so historical reports remain accurate even if a recipe changes later. Default quantities and stock levels are examples; review and adjust them to match the café’s actual recipes and inventory.

## Menu Management, Daily Closing, and Backups

- From the **Menu** tab, you can add a product, edit its category, price, and removable ingredients, or hide it. Product names stay fixed so previous invoices and recipes remain linked correctly. Inventory recipes are managed from the Ingredients tab.
- From the **Reports** tab, you can close the current day once. The system saves the sales total and invoice count, then prevents new invoices from being paid for that day.
- From the **Backups** tab, you can create a full SQLite backup or restore a previous one. Backups are stored in `%LOCALAPPDATA%\CafeSystem\Backups\`. Before restoring, the app backs up the current data and checks the selected backup’s integrity.

## Code Organization

- `lib/core`: Shared constants and settings that do not depend on screens.
- `lib/data/database`: SQLite initialization, schema creation, and migrations.
- `lib/data/models`: Data models. `cafe_order_item.dart` represents an order line, `cafe_order.dart` represents a complete order, and `cafe_snapshot.dart` represents data loaded for the UI.
- `lib/data/models/default_cafe_products.dart`: The initial product catalog is separate from the `CafeProduct` model; saved menu changes are read from SQLite.
- `lib/data/repositories`: The source of truth for data and the read/write operations.
- `lib/ui/screens`: Screen composition and layout.
- `lib/ui/widgets`: UI components. Make components reusable when they have a clear use case, and keep tightly coupled private elements near the component they belong to.

The official Flutter architecture guidance separates the UI layer (Views and ViewModels) from the data layer (Repositories and Services). It recommends adding a separate logic layer only when business logic is complex or reused. It does not require one class per file; files are best organized by responsibility and cohesion, such as keeping a `State` class alongside its `StatefulWidget`.