import 'package:flutter/material.dart';

import '../../data/database_service.dart';
import '../../models/models.dart';
import '../../state/assetkeeper_controller.dart';
import '../widgets/common.dart';

Future<int?> editAsset(
  BuildContext context,
  AssetKeeperController controller, {
  Asset? asset,
}) => Navigator.of(context).push<int>(
  MaterialPageRoute(
    builder: (_) => AssetEditor(controller: controller, asset: asset),
  ),
);

class AssetEditor extends StatefulWidget {
  const AssetEditor({super.key, required this.controller, this.asset});
  final AssetKeeperController controller;
  final Asset? asset;
  @override
  State<AssetEditor> createState() => _AssetEditorState();
}

class _AssetEditorState extends State<AssetEditor> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.asset?.name ?? '');
  late final property = TextEditingController(
    text: widget.asset?.property ?? '',
  );
  late final serial = TextEditingController(text: widget.asset?.serial ?? '');
  late final description = TextEditingController(
    text: widget.asset?.description ?? '',
  );
  late final price = TextEditingController(
    text: widget.asset == null ? '' : priceInput(widget.asset!.price),
  );
  late final unit = TextEditingController(text: widget.asset?.unit ?? '');
  late final destination = TextEditingController(
    text: widget.asset?.destination ?? '',
  );
  late int? category =
      widget.asset?.categoryId ?? widget.controller.categories.firstOrNull?.id;
  late int? employee = widget.asset?.employeeId;
  late int? branch =
      widget.asset?.branchId ?? widget.controller.branches.firstOrNull?.id;
  late String acquired = widget.asset?.acquired ?? day(DateTime.now());
  late String status = widget.asset?.status ?? 'Active';
  bool busy = false, dirty = false, leaving = false;
  String? error;
  @override
  void dispose() {
    for (final controller in [
      name,
      property,
      serial,
      description,
      price,
      unit,
      destination,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> close() async {
    if (busy) return;
    if (dirty &&
        !await confirm(
          context,
          title: 'Discard changes?',
          description: 'Your unsaved asset changes will be lost.',
          action: 'Discard',
        )) {
      return;
    }
    if (!mounted) return;
    setState(() => leaving = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> save() async {
    if (!form.currentState!.validate() || busy) return;
    final assignmentChanged =
        widget.asset != null && employee != widget.asset!.employeeId;
    final unitChanged =
        status == transferredStatus &&
        (widget.asset?.status != status ||
            widget.asset?.destination != destination.text.trim());
    if ((assignmentChanged || unitChanged) &&
        !await confirm(
          context,
          title: 'Confirm transfer changes',
          description: 'The changed accountability or destination will be recorded permanently in transfer history.',
          action: 'Save and record transfer',
        )) {
      return;
    }
    if (!mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final id = await widget.controller.database.saveAsset(
        AssetDraft(
          name: name.text,
          property: property.text,
          categoryId: category!,
          employeeId: employee!,
          branchId: branch!,
          price: parseCentavos(price.text),
          acquired: acquired,
          serial: serial.text,
          description: description.text,
          status: status,
          unit: unit.text,
          destination: destination.text,
        ),
        existing: widget.asset,
      );
      await widget.controller.refresh();
      if (mounted) {
        setState(() => leaving = true);
        Navigator.pop(context, id);
      }
    } catch (e) {
      if (mounted) setState(() => error = errorMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget text(
    TextEditingController controller,
    String label, {
    int max = 120,
    bool required = false,
    int lines = 1,
    bool readOnly = false,
  }) => TextFormField(
    controller: controller,
    readOnly: readOnly,
    maxLength: max,
    maxLines: lines,
    decoration: InputDecoration(labelText: label, counterText: ''),
    validator: required
        ? (s) => requiredText(s, label.replaceAll(' *', ''))
        : null,
  );
  Widget reference(
    String label,
    List<Reference> entries,
    int? selected,
    ValueChanged<int?> change,
  ) => DropdownButtonFormField<int>(
    initialValue: selected,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: entries
        .map(
          (e) => DropdownMenuItem(
            value: e.id,
            child: Text(
              e is Employee ? e.label : e.name,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        )
        .toList(),
    onChanged: (value) {
      dirty = true;
      change(value);
    },
    validator: (value) => value == null ? 'Select $label.' : null,
  );
  Widget section(String title, IconData icon, List<Widget> children) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: leaving || (!dirty && !busy),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) close();
    },
    child: Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: busy ? null : close),
        title: Text(widget.asset == null ? 'Add asset' : 'Edit asset'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Form(
                key: form,
                onChanged: () {
                  dirty = true;
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'One record per physical asset. Required fields are marked *.',
                    ),
                    const SizedBox(height: 20),
                    if (error != null) ...[
                      Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    section(
                      'Asset identification',
                      Icons.inventory_2_outlined,
                      [
                        text(name, 'Asset name *', required: true),
                        const SizedBox(height: 16),
                        text(
                          property,
                          'Property number *',
                          required: true,
                          max: 60,
                        ),
                        const SizedBox(height: 16),
                        text(serial, 'Serial number (optional)', max: 100),
                        const SizedBox(height: 16),
                        reference(
                          'Category *',
                          widget.controller.categories,
                          category,
                          (v) => setState(() => category = v),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                    const SizedBox(height: 16),
                    section('Location & acquisition', Icons.business_outlined, [
                      reference(
                        'Branch location *',
                        widget.controller.branches,
                        branch,
                        (v) => setState(() => branch = v),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: price,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Acquisition price (₱) *',
                        ),
                        validator: (s) {
                          try {
                            parseCentavos(s ?? '');
                            return null;
                          } on FormatException catch (e) {
                            return e.message;
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      DateField(
                        label: 'Acquisition date *',
                        value: acquired,
                        onChanged: (v) => setState(() {
                          acquired = v;
                          dirty = true;
                        }),
                      ),
                      const SizedBox(height: 16),
                    ]),
                    const SizedBox(height: 16),
                    section(
                      'Accountability & condition',
                      Icons.person_outline,
                      [
                        reference(
                          'Accountable employee *',
                          widget.controller.employees,
                          employee,
                          (v) => setState(() => employee = v),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: status,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Status *',
                          ),
                          items: assetStatuses
                              .map(
                                (s) =>
                                    DropdownMenuItem(value: s, child: Text(s)),
                              )
                              .toList(),
                          onChanged: (v) => setState(() {
                            status = v!;
                            dirty = true;
                          }),
                        ),
                        const SizedBox(height: 16),
                        text(
                          unit,
                          status == transferredStatus &&
                                  (widget.asset?.unit ?? '').isEmpty
                              ? 'Previous unit *'
                              : 'Organizational unit (optional)',
                          max: 100,
                          required:
                              status == transferredStatus &&
                              (widget.asset?.unit ?? '').isEmpty,
                          readOnly:
                              widget.asset != null &&
                              widget.asset!.unit.isNotEmpty,
                        ),
                        if (widget.asset != null)
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Text(
                              'Use Transfer to move an existing asset to another unit.',
                            ),
                          ),
                        if (status == transferredStatus) ...[
                          const SizedBox(height: 16),
                          text(
                            destination,
                            'Destination unit *',
                            required: true,
                            max: 100,
                          ),
                        ],
                        const SizedBox(height: 16),
                      ],
                    ),
                    const SizedBox(height: 16),
                    text(description, 'Description', max: 2000, lines: 4),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      alignment: WrapAlignment.end,
                      children: [
                        TextButton(
                          onPressed: busy ? null : close,
                          child: const Text('Cancel'),
                        ),
                        FilledButton.icon(
                          onPressed: busy ? null : save,
                          icon: busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check),
                          label: Text(busy ? 'Saving…' : 'Save asset'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
