import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_night_werewolf/main.dart';

void main() {
  testWidgets('shows game mode choices on the home page', (tester) async {
    await tester.pumpWidget(const WerewolfApp());

    expect(find.text('How are you playing?'), findsOneWidget);
    expect(find.text('Pass & play'), findsOneWidget);
    expect(find.text('Create or join a room'), findsOneWidget);
  });

  testWidgets('toggles from English to Chinese', (tester) async {
    await tester.pumpWidget(const WerewolfApp());

    expect(find.text('How are you playing?'), findsOneWidget);

    await tester.tap(find.text('中文'));
    await tester.pumpAndSettle();

    expect(find.text('选择游戏方式'), findsOneWidget);
    expect(find.text('传递手机'), findsOneWidget);
    expect(find.text('创建或加入房间'), findsOneWidget);
  });

  testWidgets('opens the pass-and-play role composition picker', (
    tester,
  ) async {
    await tester.pumpWidget(const WerewolfApp());

    await tester.tap(find.text('Pass & play'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Configure roles · 6 cards'));
    await tester.pumpAndSettle();

    expect(find.text('Choose role composition'), findsOneWidget);
    expect(find.text('Minion'), findsOneWidget);
    expect(find.text('Troublemaker'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Insomniac'),
      200,
      scrollable: find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Insomniac'), findsOneWidget);
  });
}
