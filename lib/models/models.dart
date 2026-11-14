import 'package:intl/intl.dart';

const assetStatuses = [
  'Active',
  'Obsolete',
  'Damaged Beyond Repair',
  'Replaced',
  'Transferred to Other Unit',
];
const transferredStatus = 'Transferred to Other Unit';

String money(int centavos) {
  final whole = NumberFormat.decimalPattern('en_PH').format(centavos ~/ 100);
  return '₱$whole.${(centavos % 100).toString().padLeft(2, '0')}';
}

int parseCentavos(String text) {
  final value = text.trim();
  if (!RegExp(r'^\d{1,10}(\.\d{1,2})?$').hasMatch(value)) {
    throw const FormatException(
      'Enter a positive price with up to 2 decimal places.',
    );
  }
  final parts = value.split('.');
  final result =
      int.parse(parts[0]) * 100 +
      (parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0);
  if (result > 999999999999) {
    throw const FormatException('Acquisition price is too large.');
  }
  return result;
}

String priceInput(int centavos) =>
    '${centavos ~/ 100}.${(centavos % 100).toString().padLeft(2, '0')}';
String day(DateTime value) => DateFormat('yyyy-MM-dd').format(value);
String displayDate(String value) =>
    DateFormat.yMMMd().format(DateTime.parse(value));
String displayTime(String value) =>
    DateFormat('MMM d, yyyy · h:mm a').format(DateTime.parse(value).toLocal());

class Reference {
  const Reference(this.id, this.name);
  final int id;
  final String name;
  factory Reference.fromMap(Map<String, Object?> row) =>
      Reference(row['id'] as int, row['name'] as String);
}

class Employee extends Reference {
  const Employee(super.id, super.name, this.code, this.unit);
  final String code, unit;
  String get label => '$name · $code';
  factory Employee.fromMap(Map<String, Object?> row) => Employee(
    row['id'] as int,
    row['name'] as String,
    row['code'] as String,
    row['unit'] as String,
  );
}

class Asset {
  const Asset(this.row);
  final Map<String, Object?> row;
  int get id => row['id'] as int;
  int get version => row['version'] as int;
  String get name => row['name'] as String;
  String get property => row['property_number'] as String;
  String get serial => row['serial_number'] as String;
  String get description => row['description'] as String;
  int get price => row['price_centavos'] as int;
  String get acquired => row['acquisition_date'] as String;
  int get categoryId => row['category_id'] as int;
  String get category => row['category_name'] as String;
  int get employeeId => row['employee_id'] as int;
  String get employee => row['employee_name'] as String;
  String get employeeCode => row['employee_code'] as String;
  int get branchId => row['branch_id'] as int;
  String get branch => row['branch_name'] as String;
  String get status => row['status'] as String;
  String get unit => row['current_unit'] as String;
  String get destination => row['destination_unit'] as String;
  bool get archived => row['archived'] == 1;
}

class AssetDraft {
  AssetDraft({
    required this.name,
    required this.property,
    required this.categoryId,
    required this.employeeId,
    required this.branchId,
    required this.price,
    required this.acquired,
    this.serial = '',
    this.description = '',
    this.status = 'Active',
    this.unit = '',
    this.destination = '',
  });
  final String name,
      property,
      serial,
      description,
      acquired,
      status,
      unit,
      destination;
  final int categoryId, employeeId, branchId, price;
  Map<String, Object?> toMap() => {
    'name': name.trim(),
    'property_number': property.trim(),
    'serial_number': serial.trim(),
    'description': description.trim(),
    'category_id': categoryId,
    'employee_id': employeeId,
    'branch_id': branchId,
    'price_centavos': price,
    'acquisition_date': acquired,
    'status': status,
    'current_unit': unit.trim(),
    'destination_unit': status == transferredStatus ? destination.trim() : '',
  };
}

class Transfer {
  const Transfer(this.row);
  final Map<String, Object?> row;
  int get id => row['id'] as int;
  int get assetId => row['asset_id'] as int;
  bool get employeeTransfer => row['kind'] == 'employee';
  String get assetName => row['asset_name'] as String;
  String get property => row['property_number'] as String;
  String get from => row['from_name'] as String;
  String get to => row['to_name'] as String;
  String get date => row['transfer_date'] as String;
  String get recordedAt => row['recorded_at'] as String;
  String get actor => row['actor'] as String;
  String get remarks => row['remarks'] as String;
}

class InventoryQuery {
  String search = '', status = '', sort = 'Name';
  int? categoryId, branchId, employeeId;
  bool archived = false;
  void clear() {
    search = '';
    status = '';
    sort = 'Name';
    categoryId = null;
    branchId = null;
    employeeId = null;
    archived = false;
  }
}
