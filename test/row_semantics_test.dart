import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anoya/core/ds.dart';
import 'package:anoya/core/theme.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget row) => tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(Brightness.light),
      home: Scaffold(body: row),
    ),
  );

  testWidgets('a row with a switch is read as one thing: its name and state', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var on = true;
    await pump(
      tester,
      StatefulBuilder(
        builder: (context, setState) => DsRow(
          title: 'Collect logs',
          onTap: () => setState(() => on = !on),
          trailing: [
            DsToggle(value: on, onChanged: (v) => setState(() => on = v)),
          ],
        ),
      ),
    );

    expect(
      tester.getSemantics(find.text('Collect logs')),
      isSemantics(
        label: 'Collect logs',
        hasToggledState: true,
        isToggled: true,
        hasTapAction: true,
      ),
    );
    expect(
      find.bySemanticsLabel('Collect logs'),
      findsOneWidget,
      reason: 'no second, nameless switch beside the row',
    );
    handle.dispose();
  });

  testWidgets('a row with a tick says whether it is ticked', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(
      tester,
      DsRow(
        title: 'Rule sets',
        onTap: () {},
        trailing: const [DsCheck(checked: true)],
      ),
    );

    expect(
      tester.getSemantics(find.text('Rule sets')),
      isSemantics(
        label: 'Rule sets',
        hasCheckedState: true,
        isChecked: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });
}
