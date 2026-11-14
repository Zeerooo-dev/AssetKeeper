import 'package:flutter/material.dart';

import '../../data/database_service.dart';
import '../../models/models.dart';
import '../../state/assetkeeper_controller.dart';
import '../widgets/common.dart';

Future<bool?> transferAsset(
  BuildContext context,
  AssetKeeperController controller,
  Asset asset,
) => Navigator.push<bool>(
  context,
  MaterialPageRoute(
    builder: (_) => TransferPage(controller: controller, asset: asset),
  ),
);

class TransferPage extends StatefulWidget {
  const TransferPage({
    super.key,
    required this.controller,
    required this.asset,
  });
  final AssetKeeperController controller;
  final Asset asset;
  @override
  State<TransferPage> createState() => _TransferPageState();
}

class _TransferPageState extends State<TransferPage> {
  final form = GlobalKey<FormState>();
  final destination = TextEditingController(),
      previous = TextEditingController(),
      remarks = TextEditingController();
  bool unitTransfer = false, busy = false, dirty = false, leaving = false;
  int? employee;
  String date = day(DateTime.now());
  String? error;
  @override
  void dispose() {
    destination.dispose();
    previous.dispose();
    remarks.dispose();
    super.dispose();
  }

  Future<void> close() async {
    if (busy) return;
    if (dirty &&
        !await confirm(
          context,
          title: 'Discard transfer?',
          description: 'No transfer will be recorded.',
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
    if (!await confirm(
      context,
      title: 'Confirm ${unitTransfer ? 'unit' : 'employee'} transfer',
      description: unitTransfer
          ? 'Move this asset to ${destination.text.trim()}? Employee accountability stays the same.'
          : 'Change the accountable employee? The previous assignment remains in history and asset status stays the same.',
      action: 'Record transfer',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.controller.database.transfer(
        widget.asset,
        employeeId: unitTransfer ? null : employee,
        destination: unitTransfer ? destination.text : null,
        previousUnit: previous.text,
        transferDate: date,
        remarks: remarks.text,
      );
      await widget.controller.refresh();
      if (mounted) {
        setState(() => leaving = true);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) setState(() => error = errorMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: leaving || (!dirty && !busy),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) close();
    },
    child: Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: close),
        title: const Text('Transfer asset'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Form(
                key: form,
                onChanged: () => dirty = true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.asset.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(widget.asset.property),
                    const SizedBox(height: 24),
                    DropdownButtonFormField<bool>(
                      isExpanded: true,
                      initialValue: unitTransfer,
                      decoration: const InputDecoration(
                        labelText: 'Transfer type',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: false,
                          child: Text('Employee accountability'),
                        ),
                        DropdownMenuItem(
                          value: true,
                          child: Text('Other organizational unit'),
                        ),
                      ],
                      onChanged: busy
                          ? null
                          : (v) => setState(() {
                              unitTransfer = v!;
                              dirty = true;
                              error = null;
                            }),
                    ),
                    const SizedBox(height: 20),
                    if (unitTransfer) ...[
                      if (widget.asset.unit.isNotEmpty)
                        Text('Previous unit: ${widget.asset.unit}')
                      else
                        TextFormField(
                          controller: previous,
                          maxLength: 100,
                          decoration: const InputDecoration(
                            labelText: 'Previous unit *',
                          ),
                          validator: (v) => requiredText(v, 'Previous unit'),
                        ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: destination,
                        maxLength: 100,
                        decoration: const InputDecoration(
                          labelText: 'Destination unit *',
                        ),
                        validator: (v) => requiredText(v, 'Destination unit'),
                      ),
                    ] else ...[
                      Text(
                        'Current employee: ${widget.asset.employee} · ${widget.asset.employeeCode}',
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        initialValue: employee,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'New accountable employee *',
                        ),
                        items: widget.controller.employees
                            .where((e) => e.id != widget.asset.employeeId)
                            .map(
                              (e) => DropdownMenuItem(
                                value: e.id,
                                child: Text(
                                  e.label,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        validator: (v) =>
                            v == null ? 'Select a different employee.' : null,
                        onChanged: busy
                            ? null
                            : (v) => setState(() => employee = v),
                      ),
                      if (widget.controller.employees.length < 2)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Add another employee before transferring accountability.',
                          ),
                        ),
                    ],
                    const SizedBox(height: 20),
                    DateField(
                      label: 'Transfer date *',
                      value: date,
                      firstDate: DateTime.parse(widget.asset.acquired),
                      onChanged: (v) => setState(() {
                        date = v;
                        dirty = true;
                      }),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: remarks,
                      maxLines: 3,
                      maxLength: 1000,
                      decoration: const InputDecoration(
                        labelText: 'Remarks (optional)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      unitTransfer
                          ? 'Sets status to Transferred to Other Unit. The accountable employee stays the same.'
                          : 'Records the previous and new employees. Asset status stays the same.',
                    ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        TextButton(
                          onPressed: busy ? null : close,
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: busy ? null : save,
                          child: Text(busy ? 'Recording…' : 'Confirm transfer'),
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
