CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL);
CREATE TABLE branches (
 id INTEGER PRIMARY KEY AUTOINCREMENT,
 name TEXT NOT NULL COLLATE NOCASE UNIQUE CHECK(length(trim(name)) BETWEEN 1 AND 100)
);
CREATE TABLE categories (
 id INTEGER PRIMARY KEY AUTOINCREMENT,
 name TEXT NOT NULL COLLATE NOCASE UNIQUE CHECK(length(trim(name)) BETWEEN 1 AND 100)
);
CREATE TABLE employees (
 id INTEGER PRIMARY KEY AUTOINCREMENT,
 name TEXT NOT NULL CHECK(length(trim(name)) BETWEEN 1 AND 120),
 code TEXT NOT NULL COLLATE NOCASE UNIQUE CHECK(length(trim(code)) BETWEEN 1 AND 60),
 unit TEXT NOT NULL DEFAULT '' CHECK(length(unit) <= 100)
);
CREATE TABLE assets (
 id INTEGER PRIMARY KEY AUTOINCREMENT,
 name TEXT NOT NULL CHECK(length(trim(name)) BETWEEN 1 AND 120),
 category_id INTEGER NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
 property_number TEXT NOT NULL COLLATE NOCASE UNIQUE CHECK(length(trim(property_number)) BETWEEN 1 AND 60),
 serial_number TEXT NOT NULL DEFAULT '' CHECK(length(serial_number) <= 100),
 description TEXT NOT NULL DEFAULT '' CHECK(length(description) <= 2000),
 price_centavos INTEGER NOT NULL CHECK(typeof(price_centavos) = 'integer' AND price_centavos BETWEEN 0 AND 999999999999),
 acquisition_date TEXT NOT NULL CHECK(length(acquisition_date) = 10),
 employee_id INTEGER NOT NULL REFERENCES employees(id) ON DELETE RESTRICT,
 branch_id INTEGER NOT NULL REFERENCES branches(id) ON DELETE RESTRICT,
 status TEXT NOT NULL CHECK(status IN ('Active','Obsolete','Damaged Beyond Repair','Replaced','Transferred to Other Unit')),
 current_unit TEXT NOT NULL DEFAULT '' CHECK(length(current_unit) <= 100),
 destination_unit TEXT NOT NULL DEFAULT '' CHECK(length(destination_unit) <= 100),
 archived INTEGER NOT NULL DEFAULT 0 CHECK(archived IN (0,1)),
 version INTEGER NOT NULL DEFAULT 1,
 created_at TEXT NOT NULL,
 updated_at TEXT NOT NULL,
 CHECK(status != 'Transferred to Other Unit' OR length(trim(destination_unit)) > 0)
);
CREATE TABLE accountability_transfers (
 id INTEGER PRIMARY KEY AUTOINCREMENT,
 asset_id INTEGER NOT NULL REFERENCES assets(id) ON DELETE RESTRICT,
 previous_employee_id INTEGER NOT NULL REFERENCES employees(id) ON DELETE RESTRICT,
 new_employee_id INTEGER NOT NULL REFERENCES employees(id) ON DELETE RESTRICT,
 previous_employee_name TEXT NOT NULL,
 new_employee_name TEXT NOT NULL,
 transfer_date TEXT NOT NULL,
 recorded_at TEXT NOT NULL,
 actor TEXT NOT NULL,
 remarks TEXT NOT NULL DEFAULT '',
 CHECK(previous_employee_id != new_employee_id)
);
CREATE TABLE unit_transfers (
 id INTEGER PRIMARY KEY AUTOINCREMENT,
 asset_id INTEGER NOT NULL REFERENCES assets(id) ON DELETE RESTRICT,
 previous_unit TEXT NOT NULL CHECK(length(trim(previous_unit)) > 0),
 destination_unit TEXT NOT NULL CHECK(length(trim(destination_unit)) > 0),
 transfer_date TEXT NOT NULL,
 recorded_at TEXT NOT NULL,
 actor TEXT NOT NULL,
 remarks TEXT NOT NULL DEFAULT '',
 CHECK(lower(trim(previous_unit)) != lower(trim(destination_unit)))
);
CREATE TABLE audit_log (
 id INTEGER PRIMARY KEY AUTOINCREMENT,
 asset_id INTEGER REFERENCES assets(id) ON DELETE RESTRICT,
 action TEXT NOT NULL, actor TEXT NOT NULL, recorded_at TEXT NOT NULL, details TEXT NOT NULL
);
CREATE INDEX asset_category ON assets(category_id);
CREATE INDEX asset_branch ON assets(branch_id);
CREATE INDEX asset_employee ON assets(employee_id);
CREATE INDEX asset_status ON assets(status,archived);
CREATE INDEX asset_serial ON assets(serial_number COLLATE NOCASE);
CREATE INDEX accountability_asset ON accountability_transfers(asset_id,id DESC);
CREATE INDEX unit_transfer_asset ON unit_transfers(asset_id,id DESC);
CREATE INDEX audit_asset ON audit_log(asset_id,id DESC);
CREATE TRIGGER accountability_no_update BEFORE UPDATE ON accountability_transfers BEGIN SELECT RAISE(ABORT,'Transfer history cannot be changed'); END;
CREATE TRIGGER accountability_no_delete BEFORE DELETE ON accountability_transfers BEGIN SELECT RAISE(ABORT,'Transfer history cannot be deleted'); END;
CREATE TRIGGER unit_transfer_no_update BEFORE UPDATE ON unit_transfers BEGIN SELECT RAISE(ABORT,'Transfer history cannot be changed'); END;
CREATE TRIGGER unit_transfer_no_delete BEFORE DELETE ON unit_transfers BEGIN SELECT RAISE(ABORT,'Transfer history cannot be deleted'); END;
CREATE TRIGGER audit_no_update BEFORE UPDATE ON audit_log BEGIN SELECT RAISE(ABORT,'Audit history cannot be changed'); END;
CREATE TRIGGER audit_no_delete BEFORE DELETE ON audit_log BEGIN SELECT RAISE(ABORT,'Audit history cannot be deleted'); END;
INSERT INTO branches(name) VALUES ('Valencia Branch');
INSERT INTO categories(name) VALUES ('Equipment');
INSERT INTO categories(name) VALUES ('Furniture');
