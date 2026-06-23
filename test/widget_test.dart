import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kubely/core/theme/kubely_theme.dart';
import 'package:kubely/ui/shared/kubely_logo.dart';
import 'package:kubely/ui/shared/status_dot.dart';
import 'package:kubely/ui/shared/segmented_control.dart';
import 'package:kubely/core/theme/kubely_colors.dart';

void main() {
  testWidgets('KubelyLogo renders', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: KubelyTheme.dark,
        home: const Scaffold(
          body: Center(child: KubelyLogo(size: 80, showHex: true)),
        ),
      ),
    );
    expect(find.byType(KubelyLogo), findsOneWidget);
  });

  testWidgets('StatusDot renders with correct color', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatusDot(color: KubelyColors.running, size: 9, glow: true),
        ),
      ),
    );
    expect(find.byType(StatusDot), findsOneWidget);
  });

  testWidgets('SegmentedControl switches', (tester) async {
    int selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: KubelyTheme.dark,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SegmentedControl(
              segments: const ['A', 'B', 'C'],
              selectedIndex: selected,
              onChanged: (i) => setState(() => selected = i),
            ),
          ),
        ),
      ),
    );

    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);

    await tester.tap(find.text('B'));
    await tester.pumpAndSettle();

    expect(selected, 1);
  });
}
