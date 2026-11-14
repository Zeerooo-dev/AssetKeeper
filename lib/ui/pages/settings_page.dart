import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../state/assetkeeper_controller.dart';
import '../widgets/common.dart';
import '../widgets/update_prompt.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.controller,
    this.firstRun = false,
  });
  final AssetKeeperController controller;
  final bool firstRun;
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final form = GlobalKey<FormState>();
  late final operatorName = TextEditingController(
    text: widget.controller.operatorName,
  );
  late AssetKeeperTheme theme = widget.controller.theme;
  @override
  void dispose() {
    operatorName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.firstRun ? 'Set up AssetKeeper' : 'Settings',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  widget.firstRun
                      ? 'Start with your operator name. This name is recorded when you register assets and make transfers.'
                      : 'Your name is recorded on future changes. Existing history keeps its original operator.',
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: operatorName,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'Operator name *',
                  ),
                  validator: (v) => requiredText(v, 'Operator name'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<AssetKeeperTheme>(
                  initialValue: theme,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Appearance'),
                  items: AssetKeeperTheme.values
                      .map(
                        (v) => DropdownMenuItem(value: v, child: Text(v.label)),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => theme = v!),
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: SaveButton(
                    label: widget.firstRun
                        ? 'Start using AssetKeeper'
                        : 'Save settings',
                    onSave: () async {
                      if (!form.currentState!.validate()) return;
                      await widget.controller.database.saveSettings(
                        operatorName.text,
                        theme.name,
                      );
                      await widget.controller.refresh();
                      if (context.mounted && !widget.firstRun) {
                        message(context, 'Settings saved.');
                      }
                    },
                  ),
                ),
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 16),
                Text(
                  'Local storage',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Records are stored on this device. PC and phone installations have separate inventories. The operator name is an audit label, not a sign-in account.',
                ),
                const SizedBox(height: 16),
                SelectableText(widget.controller.database.path),
                const SizedBox(height: 12),
                Text(
                  kIsWeb
                      ? 'Browser storage is not encrypted. Use the native PC or phone app for protected records. Clearing site data removes browser records.'
                      : 'Database files are encrypted automatically while AssetKeeper is running, saving, or closed. Keys stay in this device’s secure storage. No manual close is needed. Keep device access restricted.',
                ),
                if (!widget.firstRun) ...[
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 16),
                  Text(
                    'App updates',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'AssetKeeper checks for new GitHub releases when you open the app and periodically when you return. Checking sends no inventory records.',
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SaveButton(
                      label: 'Check for updates',
                      onSave: () async {
                        final result = await UpdatePromptHost.checkForUpdates(
                          context,
                        );
                        if (context.mounted && result != null) {
                          message(context, result);
                        }
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ],
  );
}
