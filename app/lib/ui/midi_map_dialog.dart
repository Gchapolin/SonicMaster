import 'package:flutter/material.dart' show Icons; // Icons glyph font only
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../model/midi_map.dart';
import '../state/cfw_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'sonic_controls.dart';

/// The editor of the CFW's custom MIDI map: the rows the pedal holds, a form
/// to add or change one, and "Save to pedal". Nothing is sent before the
/// save, which replaces the whole map. The map is read when the dialog
/// opens; while it is unknown nothing can be saved (an unread map must never
/// overwrite the pedal's).
class MidiMapDialog extends HookConsumerWidget {
  const MidiMapDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stored = ref.watch(midiMapProvider);
    final rows = useState<List<MidiMapEntry>?>(stored);
    final draft = useState(const MidiMapEntry());
    final editing = useState<int?>(null);
    final isBusy = useState(true);
    final status = useState<String?>(null);

    Future<void> read() async {
      isBusy.value = true;
      await refreshMidiMap(ref);
      if (!context.mounted) return;

      rows.value = ref.read(midiMapProvider);
      isBusy.value = false;
    }

    useEffect(() {
      read();

      return null;
    }, const []);

    final list = rows.value;
    final d = draft.value;
    final options = MidiMapEntry.optionsOf(d.function);
    final isFull = list != null && list.length >= MidiMapEntry.maxEntries;

    void commitDraft() {
      final i = editing.value;

      rows.value = i == null
          ? [...list!, d]
          : [
              for (final (j, e) in list!.indexed)
                if (j == i) d else e,
            ];
      editing.value = null;
      status.value = 'Not saved yet';
    }

    Future<void> save() async {
      isBusy.value = true;

      final isSaved = await saveMidiMap(ref, list!);

      if (!context.mounted) return;

      isBusy.value = false;
      status.value = isSaved
          ? 'Saved to the pedal'
          : 'The pedal did not take the map';
    }

    return SonicDialog(
      maxWidth: 620,
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        children: [
          const Text('Custom MIDI map', style: AppText.dialogTitle),
          const SizedBox(height: 4),
          Text(
            list == null
                ? (isBusy.value
                      ? 'Reading the map from the pedal…'
                      : 'The pedal did not send its map')
                : '${list.length} / ${MidiMapEntry.maxEntries} rows'
                      '${status.value == null ? '' : ' · ${status.value}'}',
            style: AppText.dialogBody.copyWith(color: Palette.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          if (list != null)
            for (final (i, e) in list.indexed)
              _RowLine(
                entry: e,
                isSelected: editing.value == i,
                onEdit: () {
                  editing.value = i;
                  draft.value = e;
                },
                onDelete: () {
                  rows.value = [
                    for (final (j, x) in list.indexed)
                      if (j != i) x,
                  ];
                  editing.value = null;
                  status.value = 'Not saved yet';
                },
              ),
          if (list != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: .center,
              children: [
                SonicDropdown<int>(
                  value: d.trigger,
                  width: 76,
                  items: const [
                    (value: MidiMapEntry.cc, label: 'CC'),
                    (value: MidiMapEntry.pc, label: 'PC'),
                  ],
                  onChanged: (v) => draft.value = d.copyWith(trigger: v),
                ),
                _Number(
                  value: d.from,
                  prefix: 'from',
                  onChanged: (v) => draft.value = d.copyWith(
                    from: v,
                    to: v > d.to ? v : d.to,
                  ),
                ),
                _Number(
                  value: d.to,
                  prefix: 'to',
                  min: d.from,
                  onChanged: (v) => draft.value = d.copyWith(to: v),
                ),
                SonicDropdown<int>(
                  value: d.channel,
                  width: 112,
                  items: [
                    (value: 0, label: 'MIDI CH'),
                    for (var ch = 1; ch <= 16; ch++)
                      (value: ch, label: 'Ch $ch'),
                  ],
                  onChanged: (v) => draft.value = d.copyWith(channel: v),
                ),
                if (d.trigger == MidiMapEntry.cc)
                  SonicDropdown<int>(
                    value: d.value,
                    width: 100,
                    items: [
                      for (final v in {0, 1, 2, d.value})
                        (value: v, label: MidiMapEntry.valueLabel(v)),
                    ],
                    onChanged: (v) => draft.value = d.copyWith(value: v),
                  ),
                SonicDropdown<int>(
                  value: d.function,
                  width: 230,
                  items: [
                    for (final f in MidiMapEntry.functions.entries)
                      (value: f.key, label: f.value),
                    if (!MidiMapEntry.functions.containsKey(d.function))
                      (value: d.function, label: 'Function ${d.function}'),
                  ],
                  onChanged: (v) =>
                      draft.value = d.copyWith(function: v, which: 0),
                ),
                if (options.isNotEmpty)
                  SonicDropdown<int>(
                    value: d.which,
                    width: 170,
                    items: [
                      for (final (i, o) in options.indexed)
                        (value: i, label: o),
                      if (d.which >= options.length)
                        (value: d.which, label: 'Option ${d.which}'),
                    ],
                    onChanged: (v) => draft.value = d.copyWith(which: v),
                  ),
                if (d.hasSwitch)
                  SonicDropdown<int>(
                    value: d.switchMode & 3,
                    width: 130,
                    items: const [
                      (value: 0, label: '≥ 64 on'),
                      (value: 1, label: 'Toggle'),
                      (value: 2, label: 'Momentary'),
                    ],
                    onChanged: (v) => draft.value = d.copyWith(switchMode: v),
                  ),
                SonicButton(
                  label: editing.value == null ? 'Add row' : 'Update row',
                  onPressed: editing.value == null && isFull
                      ? null
                      : commitDraft,
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: .end,
            children: [
              if (list == null && !isBusy.value) ...[
                SonicButton(label: 'Read again', onPressed: read),
                const SizedBox(width: 10),
              ],
              SonicButton(
                label: 'Close',
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 10),
              SonicButton(
                label: 'Save to pedal',
                isAccent: true,
                onPressed: list == null || isBusy.value ? null : save,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One stored row: what it does, with its edit and delete buttons.
class _RowLine extends StatelessWidget {
  const _RowLine({
    required this.entry,
    required this.isSelected,
    required this.onEdit,
    required this.onDelete,
  });

  final MidiMapEntry entry;
  final bool isSelected;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final extras = [
      if (entry.channel != 0) 'ch ${entry.channel}',
      if (entry.value != 0) MidiMapEntry.valueLabel(entry.value),
      if (entry.hasSwitch)
        const ['≥ 64 on', 'toggle', 'momentary', '≥ 64 on'][entry.switchMode &
            3],
    ];

    return Row(
      children: [
        Expanded(
          child: Text(
            [entry.describe(), ...extras].join(' · '),
            overflow: .ellipsis,
            style: AppText.dialogBody.copyWith(
              color: isSelected ? Palette.accent : Palette.onSurface,
            ),
          ),
        ),
        SonicIconButton(icon: Icons.edit, size: 18, onPressed: onEdit),
        SonicIconButton(icon: Icons.delete, size: 18, onPressed: onDelete),
      ],
    );
  }
}

/// A MIDI number, [min]..127.
class _Number extends StatelessWidget {
  const _Number({
    required this.value,
    required this.prefix,
    required this.onChanged,
    this.min = 0,
  });

  final int value;
  final String prefix;
  final int min;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => SonicDropdown<int>(
    value: value,
    width: 104,
    items: [
      for (var n = min; n <= 127; n++) (value: n, label: '$prefix $n'),
      if (value < min) (value: value, label: '$prefix $value'),
    ],
    onChanged: onChanged,
  );
}
