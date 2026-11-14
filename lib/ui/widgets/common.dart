import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../data/database_service.dart';
import '../../models/models.dart';

void message(BuildContext context, String text) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(content: Text(text)));
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.action,
    this.icon = Icons.inventory_2_outlined,
  });
  final String title, message;
  final Widget? action;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 40,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center),
        if (action != null) ...[const SizedBox(height: 16), action!],
      ],
    ),
  );
}

class StatusLabel extends StatelessWidget {
  const StatusLabel(this.status, {super.key});
  final String status;
  @override
  Widget build(BuildContext context) => Text(
    status,
    style: TextStyle(
      fontWeight: FontWeight.w600,
      color: switch (status) {
        'Active' => StockColors.of(context).healthy,
        'Obsolete' || 'Replaced' => StockColors.of(context).warning,
        'Damaged Beyond Repair' => Theme.of(context).colorScheme.error,
        _ => Theme.of(context).colorScheme.primary,
      },
    ),
  );
}

Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String description,
  required String action,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(description)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;

String? requiredText(String? text, [String label = 'This field']) =>
    text == null || text.trim().isEmpty ? '$label is required.' : null;

class SaveButton extends StatefulWidget {
  const SaveButton({
    super.key,
    required this.label,
    required this.onSave,
    this.icon = Icons.check,
  });
  final String label;
  final Future<void> Function() onSave;
  final IconData icon;
  @override
  State<SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends State<SaveButton> {
  bool busy = false;
  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: busy
        ? null
        : () async {
            setState(() => busy = true);
            try {
              await widget.onSave();
            } catch (error) {
              if (context.mounted) message(context, errorMessage(error));
            } finally {
              if (mounted) setState(() => busy = false);
            }
          },
    icon: busy
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(widget.icon),
    label: Text(busy ? 'Saving…' : widget.label),
  );
}

class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.firstDate,
  });
  final String label, value;
  final DateTime? firstDate;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => FormField<String>(
    initialValue: value,
    builder: (_) => InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        final now = DateTime.now();
        final chosen = await showDatePicker(
          context: context,
          initialDate: DateTime.parse(value),
          firstDate: firstDate ?? DateTime(1900),
          lastDate: now,
        );
        if (chosen != null) onChanged(day(chosen));
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_month_outlined),
        ),
        child: Text(displayDate(value)),
      ),
    ),
  );
}

class TransferTile extends StatelessWidget {
  const TransferTile(this.transfer, {super.key, this.onTap});
  final Transfer transfer;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
    leading: Icon(
      transfer.employeeTransfer
          ? Icons.person_outline
          : Icons.business_outlined,
    ),
    title: Text(transfer.assetName),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${transfer.from} → ${transfer.to}'),
        Text(
          '${transfer.employeeTransfer ? 'Employee accountability' : 'Unit transfer'} · ${displayDate(transfer.date)}',
        ),
        Text(
          'Recorded by ${transfer.actor} · ${displayTime(transfer.recordedAt)}',
        ),
        if (transfer.remarks.isNotEmpty) Text(transfer.remarks),
      ],
    ),
    onTap: onTap,
    trailing: onTap == null ? null : const Icon(Icons.chevron_right),
  );
}
