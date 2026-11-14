# AssetKeeper implementation

The current UI adapts Smart Stock's `ui/stitch-mobile-redesign` branch, as
explicitly selected by the owner: Executive Precision navy/slate palette,
20 px cards, 14 px fields, pill buttons, compact type, initials tiles, status
chips, dashboard actions and grouped forms. The branch theme was checked against
GitHub (blob `ce5e62e2878fb7b85a8c4c0afcee22ecb7f0a762`).

Navigation deliberately follows JANITRA: a floating frosted surface with 26 px
corners and 16 px side insets, visible labels and neutral selection. The PC
sidebar and phone top bar follow the page background. High contrast uses a solid
surface, and large text keeps a wrapping navigation layout. AssetKeeper's data
and accountability features remain its own. No reference-project files changed.

## Scope

Models, SQLite migration, database service, controller, responsive screens,
asset editor, transfers, employee/branch/category management, dashboard,
audit trail, settings, application branding, tests and setup documentation.

The reference uses Flutter, sqflite, native SQLite/FFI and a local controller.
It has no server authentication, user accounts, or roles to migrate. AssetKeeper
uses the same approach; the operator name identifies audit entries, but is not
an authenticated identity. OS/device access controls protect local access.
There is no cross-device synchronization. Do not expose this as a shared server.

## Storage and safety

Versioned SQLite migrations are bundled with the app. Each asset has a database
ID and case-insensitive unique property number. Prices are integer centavos.
Foreign keys connect employees, categories and branches. Only reference values
(Equipment, Furniture, Valencia Branch) are seeded. No sample people or assets.

Edits use optimistic version checks. Assignment changes, unit transfers,
current state and audit entries commit in one transaction. History stores
reference IDs and name snapshots, so renaming employees preserves old entries.
Triggers prevent editing/deleting transfer and audit rows. Assets are archived,
retaining property numbers and history. Referenced branches, employees and
categories cannot be deleted.

Native persistence now uses SQLCipher via sqlite3 build hooks and sqflite FFI on
all native targets. Keys are random 256-bit values in platform secure storage under
a separate v3 namespace. Database and WAL pages remain encrypted while open; app
shutdown is no longer a security prerequisite. Native opening fails closed if the
cipher engine or key is unavailable. SQL temp data stays in memory.

The previous envelope cipher is retained only for migration. Its ciphertext is
preserved until a verified SQLCipher replacement is promoted. Plaintext-source
migration also verifies row counts, schema version, page HMACs and SQLite integrity.
The browser continues to use unencrypted IndexedDB through the web worker; the
UI states this explicitly. See docs/security/automatic-encryption.md.

## UI and delivery

Desktop: sidebar at 760 px and up, inventory/detail split at larger widths.
Phones: Assets, Dashboard, Transfers and More; full-page details and editors,
scrollable forms above the keyboard. Large text/short landscape falls back to
compact navigation. Shared colors and components follow the approved prototype.

No destructive reset, sales workflows, fabricated dashboard numbers, invented
roles, cloud backend, production publishing or signing credentials. Windows
and Apple builds require their native hosts.
