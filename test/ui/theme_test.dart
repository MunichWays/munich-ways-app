import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:munich_ways/ui/theme.dart';

void main() {
  testWidgets('uses the documented action color pairs', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        theme: themeData,
        home: Builder(
          builder: (builderContext) {
            context = builderContext;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    void expectColors(
      ButtonStyle style,
      Color background,
      Color foreground,
    ) {
      expect(style.backgroundColor?.resolve({}), background);
      expect(style.foregroundColor?.resolve({}), foreground);
      expect(
        style.backgroundColor?.resolve({WidgetState.disabled}),
        AppColors.disabledBackground,
      );
      expect(
        style.foregroundColor?.resolve({WidgetState.disabled}),
        AppColors.disabledForeground,
      );
    }

    expectColors(
      AppButtonStyles.hero(context),
      AppColors.munichWaysOrange,
      AppColors.heroForeground,
    );
    expectColors(
      AppButtonStyles.primary(context),
      AppColors.uiPrimary,
      Colors.white,
    );
    expectColors(
      AppButtonStyles.secondary(context),
      AppColors.secondaryButtonBackground,
      AppColors.uiPrimary,
    );
    expectColors(
      AppButtonStyles.quiet(context),
      Colors.transparent,
      AppColors.uiPrimary,
    );
    expect(Theme.of(context).colorScheme.primary, AppColors.uiPrimary);
    expect(Theme.of(context).colorScheme.error, AppColors.danger);
  });
}
