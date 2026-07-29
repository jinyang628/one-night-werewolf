import 'package:flutter_test/flutter_test.dart';
import 'package:one_night_werewolf/main.dart';

void main() {
  testWidgets('shows game mode choices on the home page', (tester) async {
    await tester.pumpWidget(const WerewolfApp());

    expect(find.text('How are you playing?'), findsOneWidget);
    expect(find.text('Pass & play'), findsOneWidget);
    expect(find.text('Create or join a room'), findsOneWidget);
  });
}
