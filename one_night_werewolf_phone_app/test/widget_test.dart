import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_night_werewolf/game.dart';
import 'package:one_night_werewolf/l10n.dart';
import 'package:one_night_werewolf/main.dart';

void main() {
  testWidgets('shows game mode choices on the home page', (tester) async {
    await tester.pumpWidget(const WerewolfApp());

    expect(find.text('How are you playing?'), findsOneWidget);
    expect(find.text('Pass & play'), findsOneWidget);
    expect(find.text('Create or join a room'), findsOneWidget);
    expect(find.byKey(const Key('home-button')), findsNothing);
  });

  testWidgets('home button appears off home and ends the current flow', (
    tester,
  ) async {
    await tester.pumpWidget(const WerewolfApp());

    await tester.tap(find.text('Pass & play'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-button')), findsOneWidget);
    expect(find.text('Who is at the table?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('home-button')));
    await tester.pumpAndSettle();

    expect(find.text('How are you playing?'), findsOneWidget);
    expect(find.byKey(const Key('home-button')), findsNothing);
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

  testWidgets('changes table orientation with one edge tap', (tester) async {
    await tester.pumpWidget(const _OrientationHarness());

    expect(find.text('0'), findsOneWidget);
    await tester.tap(find.byKey(const Key('orientation-right')));
    await tester.pump();

    expect(find.text('3'), findsOneWidget);

    await tester.tap(find.byKey(const Key('orientation-bottom')));
    await tester.pump();

    expect(find.text('0'), findsOneWidget);

    await tester.tap(find.byKey(const Key('orientation-top')));
    await tester.pump();

    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('keeps private handoff readable in landscape', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [AppLocalizationsDelegate()],
        home: Scaffold(
          body: PrivateHandoff(
            eyebrow: 'NIGHT ACTION',
            player: const Player(id: 'p1', name: 'Alex'),
            message:
                'Everyone else closes their eyes.\n'
                'Tap only when the phone faces you.',
            buttonLabel: 'Start my action',
            onContinue: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pass to Alex'), findsOneWidget);
    expect(find.text('Start my action'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _OrientationHarness extends StatefulWidget {
  const _OrientationHarness();

  @override
  State<_OrientationHarness> createState() => _OrientationHarnessState();
}

class _OrientationHarnessState extends State<_OrientationHarness> {
  int quarterTurns = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [AppLocalizationsDelegate()],
      home: Scaffold(
        body: Stack(
          children: [
            Center(child: Text('$quarterTurns')),
            TableOrientationControls(
              quarterTurns: quarterTurns,
              onChanged: (value) => setState(() => quarterTurns = value),
            ),
          ],
        ),
      ),
    );
  }
}
