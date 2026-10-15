import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anoya/core/ds.dart';
import 'package:anoya/core/theme.dart';

Widget _app(Widget home, {Brightness brightness = Brightness.dark}) =>
    MaterialApp(
      theme: buildAppTheme(brightness),
      home: Scaffold(body: home),
    );

void main() {
  testWidgets('every kind of button is one 48 pt height', (tester) async {
    await tester.pumpWidget(
      _app(
        Column(
          children: [
            DsButton(key: const Key('p'), label: 'Sign in', onPressed: () {}),
            DsButton.tonal(
              key: const Key('t'),
              label: 'Sign in with SSO',
              glyph: Glyph.briefcase,
              onPressed: () {},
            ),
            DsButton.destructive(
              key: const Key('d'),
              label: 'Remove configuration',
              glyph: Glyph.trash,
              onPressed: () {},
            ),
            const DsButton(key: Key('m'), label: 'Continue'),
          ],
        ),
      ),
    );
    for (final k in ['p', 't', 'd', 'm']) {
      expect(
        tester.getSize(find.byKey(Key(k))).height,
        kButtonHeight,
        reason: 'stacked buttons must not differ in height ($k)',
      );
    }
  });

  testWidgets('list rows are 56 with one line and 72 with two', (tester) async {
    await tester.pumpWidget(
      _app(
        DsCard(
          children: [
            DsRow(
              key: const Key('one'),
              glyph: Glyph.fileText,
              title: 'Logs',
              trailing: const [DsChevron()],
              onTap: () {},
            ),
            DsRow(
              key: const Key('two'),
              glyph: Glyph.layers,
              title: 'Rule sets',
              subtitle: '3 sets',
              trailing: [DsToggle(value: true, onChanged: (_) {})],
              onTap: () {},
            ),
          ],
        ),
      ),
    );
    expect(tester.getSize(find.byKey(const Key('one'))).height, kRowHeight);
    expect(
      tester.getSize(find.byKey(const Key('two'))).height,
      kRowHeightTwoLines,
    );
  });

  testWidgets('text fields are 56, with the label above the value', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const Padding(
          padding: EdgeInsets.all(16),
          child: TextField(
            decoration: InputDecoration(labelText: 'Server address'),
          ),
        ),
      ),
    );
    expect(
      tester.getSize(find.byType(TextField)).height,
      closeTo(kTextFieldHeight, 1),
    );
  });

  testWidgets('a toggle is 50 × 30 and a segmented control 48 tall', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        Column(
          children: [
            DsToggle(value: false, onChanged: (_) {}),
            DsSegmented<int>(
              segments: const [(0, 'Simple'), (1, 'Advanced')],
              value: 0,
              onChanged: (_) {},
            ),
          ],
        ),
      ),
    );
    expect(
      tester.getSize(find.byType(AnimatedContainer)),
      const Size(kToggleWidth, kToggleHeight),
    );
    expect(
      tester.getSize(find.byType(DsSegmented<int>)).height,
      kSegmentedHeight,
    );
  });

  testWidgets('both themes carry the DS tokens', (tester) async {
    for (final b in Brightness.values) {
      final theme = buildAppTheme(b);
      final ds = theme.extension<DsColors>()!;
      expect(ds, b == Brightness.dark ? DsColors.dark : DsColors.light);
      expect(theme.scaffoldBackgroundColor, ds.base);
      expect(theme.colorScheme.primary, ds.accent);
    }
  });
}
