import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonicmaster/ui/sonic_controls.dart';

void main() {
  testWidgets('isProportional gives a long label a wider segment', (
    tester,
  ) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: .ltr,
        child: Center(
          child: SonicSegmented<int>(
            value: 0,
            width: 300,
            segmentPadding: 6,
            isProportional: true,
            segments: const [
              (value: 0, label: 'On'),
              (value: 1, label: 'Desligado'),
            ],
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.text('DESLIGADO').first).width,
      greaterThan(tester.getSize(find.text('ON')).width),
    );
    final short = tester.getRect(
      find
          .ancestor(of: find.text('ON'), matching: find.byType(Container))
          .first,
    );
    final long = tester.getRect(
      find
          .ancestor(
            of: find.text('DESLIGADO'),
            matching: find.byType(Container),
          )
          .first,
    );

    expect(long.width, greaterThan(short.width));
  });
}
