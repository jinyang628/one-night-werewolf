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
}
