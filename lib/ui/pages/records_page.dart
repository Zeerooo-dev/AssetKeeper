import 'package:flutter/material.dart';

import '../../data/database_service.dart';
import '../../models/models.dart';
import '../../state/assetkeeper_controller.dart';
import '../widgets/common.dart';

class RecordEditor extends StatefulWidget {
  const RecordEditor({
    super.key,
    required this.title,
    required this.labels,
    required this.values,
    required this.limits,
    required this.onSave,
    this.optional = const {},
  });
  final String title;
  final List<String> labels, values;
  final List<int> limits;
  final Set<int> optional;
  final Future<void> Function(List<String>) onSave;
  @override
  State<RecordEditor> createState() => _RecordEditorState();
}

class _RecordEditorState extends State<RecordEditor> {
  final form = GlobalKey<FormState>();
  late final fields = widget.values
      .map((s) => TextEditingController(text: s))
      .toList();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    for (final field in fields) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < fields.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: TextFormField(
                      controller: fields[i],
                      autofocus: i == 0,
                      maxLength: widget.limits[i],
                      decoration: InputDecoration(
                        labelText: widget.labels[i],
                        counterText: '',
                      ),
                      validator: widget.optional.contains(i)
                          ? null
                          : (v) => requiredText(v, widget.labels[i]),
                    ),
                  ),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: busy
              ? null
              : () async {
                  if (!form.currentState!.validate()) return;
                  setState(() {
                    busy = true;
                    error = null;
                  });
                  try {
                    await widget.onSave(fields.map((f) => f.text).toList());
                    if (context.mounted) Navigator.pop(context, true);
                  } catch (e) {
                    if (mounted) setState(() => error = errorMessage(e));
                  } finally {
                    if (mounted) setState(() => busy = false);
                  }
                },
          child: Text(busy ? 'Saving…' : 'Save'),
        ),
      ],
    ),
  );
}

class RecordsPage extends StatefulWidget {
  const RecordsPage({
    super.key,
    required this.controller,
    required this.section,
  });
  final AssetKeeperController controller;
  final AppSection section;
  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  String search = '';
  bool get people => widget.section == AppSection.employees;
  String get singular => people
      ? 'employee'
      : widget.section == AppSection.branches
      ? 'branch'
      : 'category';
  String get table =>
      widget.section == AppSection.branches ? 'branches' : 'categories';
  Future<void> edit([Reference? record]) async {
    final employee = record is Employee ? record : null;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RecordEditor(
        title:
            '${record == null
                ? 'Add'
                : people
                ? 'Edit'
                : 'Rename'} $singular',
        labels: people
            ? [
                'Employee name *',
                'Employee code *',
                'Organizational unit (optional)',
              ]
            : ['${singular[0].toUpperCase()}${singular.substring(1)} name *'],
        values: people
            ? [employee?.name ?? '', employee?.code ?? '', employee?.unit ?? '']
            : [record?.name ?? ''],
        limits: people ? [120, 60, 100] : [100],
        optional: people ? {2} : {},
        onSave: (fields) async {
          if (people) {
            await widget.controller.database.saveEmployee(
              fields[0],
              fields[1],
              fields[2],
              id: record?.id,
            );
          } else {
            await widget.controller.database.saveReference(
              table,
              fields[0],
              id: record?.id,
            );
          }
          await widget.controller.refresh();
        },
      ),
    );
    if (result == true && mounted) {
      message(
        context,
        '${singular[0].toUpperCase()}${singular.substring(1)} saved.',
      );
    }
  }

  Future<void> remove(Reference r) async {
    if (!await confirm(
      context,
      title: 'Remove $singular?',
      description:
          'Remove ${r.name}? Records referenced by assets or history cannot be removed. Rename a branch to preserve its assignments.',
      action: 'Remove',
    )) {
      return;
    }
    try {
      if (people) {
        await widget.controller.database.deleteEmployee(r.id);
      } else {
        await widget.controller.database.deleteReference(table, r.id);
      }
      await widget.controller.refresh();
      if (mounted) message(context, 'Record removed.');
    } catch (e) {
      if (mounted) message(context, errorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final records =
        (people
                ? widget.controller.employees
                : widget.section == AppSection.branches
                ? widget.controller.branches
                : widget.controller.categories)
            .where(
              (r) => '${r.name} ${r is Employee ? r.code : ''}'
                  .toLowerCase()
                  .contains(search.toLowerCase()),
            )
            .toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 12,
          alignment: WrapAlignment.spaceBetween,
          children: [
            Text(
              widget.section.label,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            FilledButton.icon(
              onPressed: edit,
              icon: const Icon(Icons.add),
              label: Text('Add $singular'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          people
              ? 'Employees can be accountable for assets without an application account.'
              : 'Renaming keeps existing asset assignments intact.',
        ),
        const SizedBox(height: 20),
        TextField(
          decoration: InputDecoration(
            labelText: 'Search ${widget.section.label.toLowerCase()}',
            prefixIcon: const Icon(Icons.search),
          ),
          onChanged: (v) => setState(() => search = v),
        ),
        const SizedBox(height: 16),
        if (records.isEmpty)
          EmptyState(
            title: search.isEmpty
                ? 'No ${widget.section.label.toLowerCase()} yet'
                : 'No matching records',
            message: people
                ? 'Add the employees responsible for your equipment and furniture.'
                : 'Add a $singular to use it when registering assets.',
          ),
        for (final r in records)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (r is Employee)
                      Text('${r.code}${r.unit.isEmpty ? '' : ' · ${r.unit}'}'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (people)
                          TextButton.icon(
                            onPressed: () => widget.controller.navigate(
                              AppSection.assets,
                              employeeId: r.id,
                            ),
                            icon: const Icon(Icons.inventory_2_outlined),
                            label: const Text('View assets'),
                          ),
                        TextButton.icon(
                          onPressed: () => edit(r),
                          icon: const Icon(Icons.edit_outlined),
                          label: Text(people ? 'Edit' : 'Rename'),
                        ),
                        TextButton(
                          onPressed: () => remove(r),
                          child: const Text('Remove'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
