import 'package:flutter/material.dart' show Icons; // Icons glyph font only
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../l10n/common_text.dart';
import '../l10n/midi_map_text.dart';
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
    // Always starts unread: rows shown before the read lands could be
    // edited and then silently replaced by it.
    final t = MidiMapText.current;
    final rows = useState<List<MidiMapEntry>?>(null);
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
      status.value = t.notSavedYet;
    }

    Future<void> save() async {
      isBusy.value = true;

      final isSaved = await saveMidiMap(ref, list!);

      if (!context.mounted) return;

      isBusy.value = false;
      status.value = isSaved ? t.saved : t.refused;
    }

    final count = list == null
        ? null
        : t.rows(list.length, MidiMapEntry.maxEntries);

    return SonicDialog(
      maxWidth: 760,
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t.title,
                  style: AppText.title.copyWith(color: Palette.onSurface),
                ),
              ),
              Text(
                list == null
                    ? (isBusy.value ? t.reading : t.notSent)
                    : '$count${status.value == null ? '' : ' · ${status.value}'}',
                style: AppText.ui.copyWith(color: Palette.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (list != null)
            Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              decoration: BoxDecoration(
                color: Palette.surfaceContainer,
                border: Border.all(color: Palette.outlineVariant),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: .stretch,
                children: [
                  const _RowHead(),
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
                        status.value = t.notSavedYet;
                      },
                    ),
                ],
              ),
            ),
          if (list != null) ...[
            const SizedBox(height: 16),
            Text(
              editing.value == null ? t.newRow : t.editRow,
              style: AppText.section.copyWith(color: Palette.outline),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: .end,
              children: [
                _Field(
                  label: t.typeLabel,
                  child: SonicDropdown<int>(
                    value: d.trigger,
                    width: 76,
                    fitLabels: true,
                    items: const [
                      (value: MidiMapEntry.cc, label: 'CC'),
                      (value: MidiMapEntry.pc, label: 'PC'),
                    ],
                    // A PC carries no value: the condition goes with the CC.
                    onChanged: (v) => draft.value = d.copyWith(
                      trigger: v,
                      value: v == MidiMapEntry.pc ? 0 : d.value,
                    ),
                  ),
                ),
                _Field(
                  label: t.from,
                  child: _Number(
                    value: d.from,
                    prefix: t.from,
                    onChanged: (v) => draft.value = d.copyWith(
                      from: v,
                      to: v > d.to ? v : d.to,
                    ),
                  ),
                ),
                _Field(
                  label: t.to,
                  child: _Number(
                    value: d.to,
                    prefix: t.to,
                    min: d.from,
                    onChanged: (v) => draft.value = d.copyWith(to: v),
                  ),
                ),
                _Field(
                  label: t.channelLabel,
                  child: SonicDropdown<int>(
                    value: d.channel,
                    width: 112,
                    fitLabels: true,
                    items: [
                      (value: 0, label: 'MIDI CH'),
                      for (var ch = 1; ch <= 16; ch++)
                        (value: ch, label: 'Ch $ch'),
                    ],
                    onChanged: (v) => draft.value = d.copyWith(channel: v),
                  ),
                ),
                if (d.trigger == MidiMapEntry.cc)
                  _Field(
                    label: t.valueLabel,
                    child: SonicDropdown<int>(
                      value: d.value,
                      width: 100,
                      fitLabels: true,
                      items: [
                        for (final v in {0, 1, 2, d.value})
                          (value: v, label: MidiMapEntry.valueLabel(v)),
                      ],
                      onChanged: (v) => draft.value = d.copyWith(value: v),
                    ),
                  ),
                _Field(
                  label: t.functionLabel,
                  child: SonicDropdown<int>(
                    value: d.function,
                    width: 230,
                    items: [
                      for (final f in MidiMapEntry.functions.entries)
                        (value: f.key, label: f.value),
                      if (!MidiMapEntry.functions.containsKey(d.function))
                        (value: d.function, label: t.function(d.function)),
                    ],
                    onChanged: (v) => draft.value = d.copyWith(
                      function: v,
                      which: 0,
                      switchMode: MidiMapEntry(function: v).hasSwitch
                          ? d.switchMode
                          : 0,
                    ),
                  ),
                ),
                if (options.isNotEmpty)
                  _Field(
                    label: t.optionLabel,
                    child: SonicDropdown<int>(
                      value: d.which,
                      width: 170,
                      items: [
                        for (final (i, o) in options.indexed)
                          (value: i, label: o),
                        if (d.which >= options.length)
                          (value: d.which, label: t.option(d.which)),
                      ],
                      onChanged: (v) => draft.value = d.copyWith(which: v),
                    ),
                  ),
                if (d.hasSwitch)
                  _Field(
                    label: t.modeLabel,
                    child: SonicDropdown<int>(
                      value: d.switchMode & 3,
                      width: 130,
                      items: [
                        (value: 0, label: t.onAt64),
                        (value: 1, label: t.toggle),
                        (value: 2, label: t.momentary),
                      ],
                      onChanged: (v) => draft.value = d.copyWith(switchMode: v),
                    ),
                  ),
                SonicButton(
                  label: editing.value == null ? t.addRow : t.updateRow,
                  onPressed: editing.value == null && isFull
                      ? null
                      : commitDraft,
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Container(height: 1, color: Palette.outlineVariant),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: .end,
            children: [
              if (list == null && !isBusy.value) ...[
                SonicButton(label: t.readAgain, onPressed: read),
                const SizedBox(width: 10),
              ],
              SonicButton(
                label: CommonText.current.close,
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 10),
              SonicButton(
                label: t.saveToPedal,
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

/// The column titles above the rows.
class _RowHead extends StatelessWidget {
  const _RowHead();

  @override
  Widget build(BuildContext context) {
    final t = MidiMapText.current;
    final style = AppText.section.copyWith(color: Palette.outline);

    return SizedBox(
      height: 28,
      child: Row(
        children: [
          const SizedBox(width: 10),
          SizedBox(width: 96, child: Text(t.colOrigin, style: style)),
          const SizedBox(width: 12),
          Expanded(child: Text(t.colFunction, style: style)),
          SizedBox(width: 200, child: Text(t.colOption, style: style)),
          const SizedBox(width: 72),
        ],
      ),
    );
  }
}

/// One stored row: source, function and option, with edit and remove.
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
    final t = MidiMapText.current;
    final e = entry;
    final source =
        '${e.trigger == MidiMapEntry.pc ? 'PC' : 'CC'} ${e.from}'
        '${e.to == e.from ? '' : '–${e.to}'}';
    final name = MidiMapEntry.functions[e.function] ?? t.function(e.function);
    final option = [
      ?e.optionLabel(),
      if (e.channel != 0) 'ch ${e.channel}',
      if (e.value != 0) MidiMapEntry.valueLabel(e.value),
      if (e.hasSwitch)
        [
          t.onAt64,
          t.toggle.toLowerCase(),
          t.momentary.toLowerCase(),
          t.onAt64,
        ][e.switchMode & 3],
    ].join(' · ');

    return Container(
      height: 44,
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.only(left: 10, right: 4),
      decoration: BoxDecoration(
        color: Palette.field,
        borderRadius: BorderRadius.circular(10),
        border: isSelected ? Border.all(color: Palette.primary) : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              source,
              style: AppText.mono.copyWith(color: Palette.primary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              overflow: .ellipsis,
              style: AppText.ui.copyWith(color: Palette.onSurface),
            ),
          ),
          SizedBox(
            width: 200,
            child: Text(
              option,
              overflow: .ellipsis,
              style: AppText.ui.copyWith(color: Palette.onSurfaceVariant),
            ),
          ),
          SonicIconButton(icon: Icons.edit, size: 16, onPressed: onEdit),
          Semantics(
            label: t.removeRow(source),
            child: SonicIconButton(
              icon: Icons.close,
              size: 16,
              onPressed: onDelete,
            ),
          ),
        ],
      ),
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
    fitLabels: true,
    items: [
      for (var n = min; n <= 127; n++) (value: n, label: '$prefix $n'),
      if (value < min) (value: value, label: '$prefix $value'),
    ],
    onChanged: onChanged,
  );
}

/// A form control with its small caption above.
class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: .min,
    crossAxisAlignment: .start,
    children: [
      Text(
        label,
        style: AppText.ui.copyWith(
          fontSize: 12,
          color: Palette.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 4),
      child,
    ],
  );
}
