import 'package:flutter/material.dart';

import '../state/app_settings.dart';

void showSettingsSheet(BuildContext context, AppSettings settings) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => ListenableBuilder(
      listenable: settings,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reading settings',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            const Text('Theme'),
            const SizedBox(height: 8),
            SegmentedButton<ReaderTheme>(
              segments: [
                for (final t in ReaderTheme.values)
                  ButtonSegment(value: t, label: Text(t.label)),
              ],
              selected: {settings.theme},
              onSelectionChanged: (s) => settings.setTheme(s.first),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Text('Text size'),
                const Spacer(),
                Text('${settings.fontSize.round()}'),
              ],
            ),
            Row(
              children: [
                const Text('A', style: TextStyle(fontSize: 14)),
                Expanded(
                  child: Slider(
                    value: settings.fontSize,
                    min: AppSettings.minFont,
                    max: AppSettings.maxFont,
                    divisions: (AppSettings.maxFont - AppSettings.minFont).round(),
                    onChanged: settings.setFontSize,
                  ),
                ),
                const Text('A', style: TextStyle(fontSize: 26)),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
