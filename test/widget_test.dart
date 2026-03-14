import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grindmode/theme/app_theme.dart';

void main() {
  testWidgets('GrindModeApp theme smoke test', (WidgetTester tester) async {
    // Verify the theme system builds correctly without Firebase.
    await tester.pumpWidget(
      MaterialApp(
        home: GrindThemeRoot(
          initialTheme: GrindTheme.defaultBlue,
          child: Builder(
            builder: (context) {
              final c = AppColors.of(context);
              return Scaffold(
                backgroundColor: c.bg,
                body: const Center(child: Text('GrindMode')),
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('GrindMode'), findsOneWidget);
  });

  testWidgets('AppColors theme variants apply correctly', (WidgetTester tester) async {
    for (final theme in GrindTheme.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: GrindThemeRoot(
            initialTheme: theme,
            child: Builder(
              builder: (context) {
                final c = AppColors.of(context);
                return ColoredBox(color: c.bg);
              },
            ),
          ),
        ),
      );
      // Verify each theme variant renders without error.
      expect(find.byType(ColoredBox), findsOneWidget);
    }
  });
}
