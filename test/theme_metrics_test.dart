import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_client/core/theme.dart';

/// Guards the metrics the design spec fixes, so a stray SizedBox or a Material
/// default can't quietly break alignment again:
///  - app-bar leading and trailing icons are inset equally;
///  - every button in a stack is the same height (48).
Widget _app(Widget home, {Brightness brightness = Brightness.dark}) =>
    MaterialApp(theme: buildAppTheme(brightness), home: home);

void main() {
  testWidgets('app-bar leading and action icons are inset equally', (tester) async {
    await tester.pumpWidget(_app(Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.add), onPressed: () {}),
        title: const Text('VPN'),
        centerTitle: true,
        actions: [IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () {})],
      ),
    )));

    final bar = tester.getRect(find.byType(AppBar));
    final leftCentre = tester.getCenter(find.byIcon(Icons.add)).dx;
    final rightCentre = tester.getCenter(find.byIcon(Icons.settings_outlined)).dx;

    final insetLeft = leftCentre - bar.left;
    final insetRight = bar.right - rightCentre;
    // 28 = half of the 56pt leading slot. The number matters
    // less than both sides agreeing, which is what actually looked broken.
    expect(insetLeft, closeTo(28, 1), reason: 'leading icon should sit 28pt from the edge');
    expect(insetRight, closeTo(insetLeft, 1),
        reason: 'action icon inset ($insetRight) must match the leading one ($insetLeft)');
  });

  testWidgets('filled and outlined buttons share one height', (tester) async {
    await tester.pumpWidget(_app(Scaffold(
      body: Column(children: [
        FilledButton(onPressed: () {}, child: const Text('Sign in')),
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.login, size: 18),
          label: const Text('Sign in with SSO'),
        ),
        FilledButton.tonal(onPressed: () {}, child: const Text('Download')),
      ]),
    )));

    final filled = tester.getSize(find.byType(FilledButton).first).height;
    final outlined = tester.getSize(find.byType(OutlinedButton).first).height;
    expect(filled, 48);
    expect(outlined, filled, reason: 'stacked buttons must not differ in height');
  });

  testWidgets('list rows use the spec paddings and a rounded hover shape', (tester) async {
    await tester.pumpWidget(_app(const Scaffold(
      body: Card(child: ListTile(title: Text('Rule sets'), subtitle: Text('3 sets'))),
    )));

    final theme = Theme.of(tester.element(find.byType(ListTile)));
    expect(theme.listTileTheme.contentPadding, const EdgeInsets.symmetric(horizontal: 16));
    // A rounded shape is what keeps the pointer highlight a pill inside the
    // card instead of a full-bleed band with square corners.
    expect(theme.listTileTheme.shape, isA<RoundedRectangleBorder>());
  });
}
