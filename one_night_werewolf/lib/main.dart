import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'game.dart';
import 'l10n.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  runApp(const WerewolfApp());
}

class WerewolfApp extends StatefulWidget {
  const WerewolfApp({super.key});

  @override
  State<WerewolfApp> createState() => _WerewolfAppState();
}

class _WerewolfAppState extends State<WerewolfApp> {
  Locale locale = const Locale('en');

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => context.tr('app_title'),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE8B15D),
          brightness: Brightness.dark,
          surface: const Color(0xFF151B1D),
        ),
        scaffoldBackgroundColor: const Color(0xFF0C1113),
        useMaterial3: true,
        textTheme: const TextTheme(
          displaySmall: TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: -1.2,
          ),
          headlineMedium: TextStyle(fontWeight: FontWeight.w800),
          titleLarge: TextStyle(fontWeight: FontWeight.w700),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF20282B),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: GameShell(
        locale: locale,
        onLocaleChanged: (nextLocale) => setState(() => locale = nextLocale),
      ),
    );
  }
}

class GameShell extends StatefulWidget {
  const GameShell({
    super.key,
    required this.locale,
    required this.onLocaleChanged,
  });

  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;

  @override
  State<GameShell> createState() => _GameShellState();
}

class _GameShellState extends State<GameShell> {
  late final GameController controller;

  @override
  void initState() {
    super.initState();
    controller = GameController(languageCode: widget.locale.languageCode)
      ..addListener(_refresh);
  }

  @override
  void didUpdateWidget(GameShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.locale.languageCode != widget.locale.languageCode) {
      controller.setLanguage(widget.locale.languageCode);
    }
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    controller
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: switch (controller.phase) {
                GamePhase.home => HomeScreen(
                  controller: controller,
                  locale: widget.locale,
                  onLocaleChanged: widget.onLocaleChanged,
                ),
                GamePhase.setup => SetupScreen(controller: controller),
                GamePhase.roomEntry => RoomEntryScreen(controller: controller),
                GamePhase.roomLobby => RoomLobbyScreen(controller: controller),
                GamePhase.roleHandoff => PrivateHandoff(
                  key: ValueKey('role-${controller.activeIndex}'),
                  eyebrow: context.tr('role_reveal'),
                  player: controller.activePlayer,
                  message: context.tr('role_privacy'),
                  buttonLabel: context.tr('ready'),
                  onContinue: controller.showRole,
                ),
                GamePhase.roleReveal => RoleRevealScreen(
                  controller: controller,
                ),
                GamePhase.nightHandoff => PrivateHandoff(
                  key: ValueKey('night-${controller.activeIndex}'),
                  eyebrow: context.tr('night_action'),
                  player: controller.activePlayer,
                  message: context.tr('close_eyes'),
                  buttonLabel: context.tr('start_action'),
                  onContinue: controller.beginNightAction,
                ),
                GamePhase.nightAction => NightActionScreen(
                  key: ValueKey('action-${controller.activeIndex}'),
                  controller: controller,
                ),
                GamePhase.discussion => DiscussionScreen(
                  controller: controller,
                ),
                GamePhase.voteHandoff => PrivateHandoff(
                  key: ValueKey('vote-${controller.activeIndex}'),
                  eyebrow: context.tr('secret_vote'),
                  player: controller.activePlayer,
                  message: context.tr('pass_vote'),
                  buttonLabel: context.tr('cast_vote'),
                  onContinue: controller.beginVote,
                ),
                GamePhase.voting => VotingScreen(controller: controller),
                GamePhase.result => ResultScreen(controller: controller),
              },
            ),
            if (controller.busy)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x66000000),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            if (controller.error != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 12,
                child: Material(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(controller.error!),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    required this.locale,
    required this.onLocaleChanged,
  });
  final GameController controller;
  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;

  @override
  Widget build(BuildContext context) {
    return ScreenPadding(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'en', label: Text(context.tr('english'))),
                ButtonSegment(value: 'zh', label: Text(context.tr('chinese'))),
              ],
              selected: {locale.languageCode},
              showSelectedIcon: false,
              onSelectionChanged: (selection) {
                onLocaleChanged(Locale(selection.first));
              },
            ),
          ),
          const Spacer(),
          Icon(
            Icons.dark_mode_rounded,
            color: Theme.of(context).colorScheme.primary,
            size: 72,
          ),
          const SizedBox(height: 24),
          Text(
            context.tr('brand'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('how_playing'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 36),
          _ModeCard(
            icon: Icons.phone_android_rounded,
            title: context.tr('pass_play'),
            description: context.tr('pass_play_description'),
            onTap: controller.choosePassAndPlay,
          ),
          const SizedBox(height: 12),
          _ModeCard(
            icon: Icons.groups_rounded,
            title: context.tr('room_mode'),
            description: context.tr('room_mode_description'),
            onTap: controller.chooseRoom,
          ),
          const Spacer(),
          Text(
            context.tr('server_storage'),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: .45)),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(20),
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF151B1D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 36, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .6),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    ),
  );
}

class RoomEntryScreen extends StatefulWidget {
  const RoomEntryScreen({super.key, required this.controller});
  final GameController controller;

  @override
  State<RoomEntryScreen> createState() => _RoomEntryScreenState();
}

class _RoomEntryScreenState extends State<RoomEntryScreen> {
  final nameController = TextEditingController();
  final codeController = TextEditingController();

  @override
  void dispose() {
    nameController.dispose();
    codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScreenPadding(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: widget.controller.goHome,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            context.tr('play_phones'),
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 10),
          Text(
            context.tr('room_instructions'),
            style: TextStyle(
              color: Colors.white.withValues(alpha: .6),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),
          TextField(
            controller: nameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: context.tr('your_name'),
              prefixIcon: const Icon(Icons.person_rounded),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () async {
              await widget.controller.createRoom(nameController.text);
            },
            icon: const Icon(Icons.add_circle_outline_rounded),
            label: Text(context.tr('create_room')),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(context.tr('or')),
                ),
                const Expanded(child: Divider()),
              ],
            ),
          ),
          TextField(
            controller: codeController,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            decoration: InputDecoration(
              labelText: context.tr('room_code'),
              counterText: '',
              prefixIcon: const Icon(Icons.key_rounded),
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () async {
              await widget.controller.joinRoom(
                codeController.text,
                nameController.text,
              );
            },
            icon: const Icon(Icons.login_rounded),
            label: Text(context.tr('join_room')),
          ),
        ],
      ),
    );
  }
}

class RoomLobbyScreen extends StatelessWidget {
  const RoomLobbyScreen({super.key, required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final room = controller.room!;
    final started = room.status != 'waiting';
    return ScreenPadding(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 18),
          Text(
            started ? context.tr('room_started') : context.tr('room_code'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            room.roomCode,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.displaySmall?.copyWith(letterSpacing: 8),
          ),
          const SizedBox(height: 12),
          Text(
            started
                ? context.tr('started_room_description')
                : context.tr('share_room'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .6),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            context.tr('players_count', {'count': room.players.length}),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView(
              children: [
                for (final player in room.players)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF151B1D),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        SeatBadge(number: player.seat),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            player.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (player.id == room.hostPlayerId)
                          Chip(label: Text(context.tr('host'))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (!started && controller.isRoomHost)
            FilledButton(
              onPressed: room.players.length >= 3
                  ? () async {
                      await controller.startRemoteRoom();
                    }
                  : null,
              child: Text(context.tr('start_room')),
            ),
          if (!started && !controller.isRoomHost)
            Text(context.tr('waiting_host'), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: controller.goHome,
            child: Text(context.tr('leave_room')),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key, required this.controller});
  final GameController controller;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  String? error;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return ScreenPadding(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          Text(
            context.tr('brand'),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 3,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.tr('who_table'),
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('arrange_players'),
            style: TextStyle(
              color: Colors.white.withValues(alpha: .65),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.separated(
              itemCount: controller.players.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final player = controller.players[index];
                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF151B1D),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .08),
                    ),
                  ),
                  child: Row(
                    children: [
                      SeatBadge(number: index + 1),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          key: ValueKey(player.id),
                          initialValue: player.name,
                          maxLength: 30,
                          decoration: InputDecoration(
                            hintText: context.tr('player_name'),
                            counterText: '',
                          ),
                          onChanged: (name) =>
                              controller.renamePlayer(index, name),
                        ),
                      ),
                      IconButton(
                        tooltip: context.tr('move_up'),
                        onPressed: index == 0
                            ? null
                            : () => controller.movePlayer(index, index - 1),
                        icon: const Icon(Icons.arrow_upward_rounded),
                      ),
                      IconButton(
                        tooltip: context.tr('move_down'),
                        onPressed: index == controller.players.length - 1
                            ? null
                            : () => controller.movePlayer(index, index + 1),
                        icon: const Icon(Icons.arrow_downward_rounded),
                      ),
                      if (controller.players.length > 3)
                        IconButton(
                          tooltip: context.tr('remove_player'),
                          onPressed: () => controller.removePlayer(index),
                          icon: const Icon(Icons.close_rounded),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (error != null) ...[
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: controller.players.length >= 8
                      ? null
                      : controller.addPlayer,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: Text(context.tr('add_player')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () async {
                    if (!await controller.startGame() && mounted) {
                      setState(() => error = context.tr('every_seat_name'));
                    }
                  },
                  child: Text(context.tr('deal_roles')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            context.tr('players_cards', {
              'players': controller.players.length,
              'cards': controller.players.length + 3,
            }),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: .45)),
          ),
        ],
      ),
    );
  }
}

class PrivateHandoff extends StatelessWidget {
  const PrivateHandoff({
    super.key,
    required this.eyebrow,
    required this.player,
    required this.message,
    required this.buttonLabel,
    required this.onContinue,
  });

  final String eyebrow;
  final Player player;
  final String message;
  final String buttonLabel;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return ScreenPadding(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.visibility_off_rounded, size: 52),
              const SizedBox(height: 28),
              Text(
                eyebrow,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                context.tr('pass_to', {'name': player.name}),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: .65)),
              ),
              const SizedBox(height: 36),
              FilledButton.icon(
                onPressed: onContinue,
                icon: const Icon(Icons.lock_open_rounded),
                label: Text(buttonLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RoleRevealScreen extends StatelessWidget {
  const RoleRevealScreen({super.key, required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final role = controller.activeGamePlayer.originalRole;
    return ScreenPadding(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Text(
            controller.activePlayer.name,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: .55)),
          ),
          const SizedBox(height: 14),
          RoleCard(role: role),
          const Spacer(),
          FilledButton.icon(
            onPressed: () async {
              await controller.hideRoleAndContinue();
            },
            icon: const Icon(Icons.visibility_off_rounded),
            label: Text(context.tr('hide_role_pass')),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class NightActionScreen extends StatefulWidget {
  const NightActionScreen({super.key, required this.controller});
  final GameController controller;

  @override
  State<NightActionScreen> createState() => _NightActionScreenState();
}

class _NightActionScreenState extends State<NightActionScreen> {
  final Set<int> centerSelection = {};
  final Set<String> playerSelection = {};

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final actor = controller.activeGamePlayer;
    return ScreenPadding(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 18),
          Text(
            '${context.tr(actor.originalRole.name).toUpperCase()} · ${actor.player.name}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _nightTitle(context, actor.originalRole),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('${actor.originalRole.name}_description'),
            style: TextStyle(
              color: Colors.white.withValues(alpha: .6),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              child: controller.actionCommitted
                  ? _ActionResult(controller: controller)
                  : _actionPicker(controller, actor),
            ),
          ),
          FilledButton(
            onPressed: controller.actionCommitted
                ? controller.finishNightTurn
                : null,
            child: Text(context.tr('hide_continue')),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _actionPicker(GameController controller, GamePlayer actor) {
    final others = controller.otherPlayers(actor.player.id);
    switch (actor.originalRole) {
      case Role.werewolf:
        final partners = controller.werewolfPartners(actor.player.id);
        if (partners.isNotEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InfoPanel(
                icon: Icons.pets_rounded,
                text: partners.map((partner) => partner.player.name).join(', '),
                caption: context.tr('fellow_werewolf'),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: controller.completeWerewolfMeeting,
                child: Text(context.tr('know_pack')),
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.tr('lone_wolf')),
            const SizedBox(height: 14),
            CenterCards(
              selected: centerSelection,
              maxSelection: 1,
              onChanged: (selection) {
                setState(() {
                  centerSelection
                    ..clear()
                    ..addAll(selection);
                });
              },
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: centerSelection.length == 1
                  ? () => controller.loneWolfViewCenter(centerSelection.first)
                  : null,
              child: Text(context.tr('view_card')),
            ),
          ],
        );
      case Role.minion:
        final werewolves = controller.werewolfPartners(actor.player.id);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InfoPanel(
              icon: Icons.visibility_rounded,
              text: werewolves.isEmpty
                  ? context.tr('no_werewolves_seen')
                  : werewolves.map((player) => player.player.name).join(', '),
              caption: context.tr('minion_saw'),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: controller.completeMinionWatch,
              child: Text(context.tr('remember_werewolves')),
            ),
          ],
        );
      case Role.seer:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.tr('view_player')),
            const SizedBox(height: 10),
            ...others.map(
              (player) => SelectionTile(
                label: player.player.name,
                onTap: () => controller.seerViewPlayer(player.player.id),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(context.tr('view_two_center')),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
            ),
            CenterCards(
              selected: centerSelection,
              maxSelection: 2,
              onChanged: (selection) {
                setState(() {
                  centerSelection
                    ..clear()
                    ..addAll(selection);
                });
              },
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: centerSelection.length == 2
                  ? () => controller.seerViewCenter(centerSelection.toList())
                  : null,
              child: Text(context.tr('view_center_cards')),
            ),
          ],
        );
      case Role.robber:
        return Column(
          children: [
            for (final player in others)
              SelectionTile(
                label: context.tr('swap_with', {'name': player.player.name}),
                onTap: () => controller.robberSwap(player.player.id),
              ),
          ],
        );
      case Role.troublemaker:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final player in others)
              SelectionTile(
                label: player.player.name,
                selected: playerSelection.contains(player.player.id),
                onTap: () {
                  setState(() {
                    if (playerSelection.contains(player.player.id)) {
                      playerSelection.remove(player.player.id);
                    } else if (playerSelection.length < 2) {
                      playerSelection.add(player.player.id);
                    }
                  });
                },
              ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: playerSelection.length == 2
                  ? () => controller.troublemakerSwap(
                      playerSelection.first,
                      playerSelection.last,
                    )
                  : null,
              child: Text(context.tr('swap_selected')),
            ),
          ],
        );
      case Role.insomniac:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.tr('insomniac_prompt')),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: controller.insomniacCheck,
              child: Text(context.tr('check_my_card')),
            ),
          ],
        );
      case Role.villager:
        return const SizedBox.shrink();
    }
  }

  static String _nightTitle(BuildContext context, Role role) => switch (role) {
    Role.werewolf => context.tr('open_eyes'),
    Role.minion => context.tr('find_werewolves'),
    Role.seer => context.tr('what_see'),
    Role.robber => context.tr('choose_rob'),
    Role.troublemaker => context.tr('choose_two'),
    Role.insomniac => context.tr('did_role_change'),
    Role.villager => context.tr('sleep_night'),
  };
}

class _ActionResult extends StatelessWidget {
  const _ActionResult({required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InfoPanel(
          icon: Icons.check_circle_rounded,
          text: controller.actionSummary,
          caption: context.tr('action_complete'),
        ),
        if (controller.seenRoles.isNotEmpty) ...[
          const SizedBox(height: 16),
          for (final role in controller.seenRoles)
            RoleCard(role: role, compact: true),
        ],
      ],
    );
  }
}

class DiscussionScreen extends StatelessWidget {
  const DiscussionScreen({super.key, required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final minutes = controller.secondsRemaining ~/ 60;
    final seconds = controller.secondsRemaining % 60;
    return ScreenPadding(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr('wake_up'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '$minutes:${seconds.toString().padLeft(2, '0')}',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.displaySmall?.copyWith(fontSize: 76),
          ),
          const SizedBox(height: 14),
          Text(
            context.tr('discussion_instructions'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .65),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),
          FilledButton(
            onPressed: () async {
              await controller.endDiscussion();
            },
            child: Text(
              controller.secondsRemaining == 0
                  ? context.tr('start_voting')
                  : context.tr('end_discussion'),
            ),
          ),
        ],
      ),
    );
  }
}

class VotingScreen extends StatelessWidget {
  const VotingScreen({super.key, required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final others = controller.otherPlayers(controller.activePlayer.id);
    return ScreenPadding(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 28),
          Text(
            context.tr('who_werewolf'),
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('vote_instructions', {
              'name': controller.activePlayer.name,
            }),
            style: TextStyle(
              color: Colors.white.withValues(alpha: .6),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),
          Expanded(
            child: ListView(
              children: [
                for (final player in others)
                  SelectionTile(
                    label: player.player.name,
                    onTap: () => controller.castVote(player.player.id),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key, required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final result = controller.result!;
    final game = controller.game!;
    return ScreenPadding(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 22),
          Text(
            switch (result.winningTeam) {
              'village' => context.tr('village_wins'),
              'minion' => context.tr('minion_wins'),
              _ => context.tr('werewolves_win'),
            },
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            result.eliminatedIds.isEmpty
                ? context.tr('nobody_eliminated')
                : context.tr('eliminated', {
                    'names': result.eliminatedIds
                        .map((id) => _nameFor(game, id))
                        .join(' & '),
                  }),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 22),
          Expanded(
            child: ListView(
              children: [
                for (final player in game.players)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: result.eliminatedIds.contains(player.player.id)
                          ? const Color(0xFF3A2020)
                          : const Color(0xFF151B1D),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        SeatBadge(number: game.players.indexOf(player) + 1),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                player.player.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                player.originalRole == player.currentRole
                                    ? context.tr(player.currentRole.name)
                                    : '${context.tr(player.originalRole.name)} → ${context.tr(player.currentRole.name)}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: .6),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          context.tr('votes', {
                            'count': result.tallies[player.player.id] ?? 0,
                          }),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  context.tr('center_cards'),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (var index = 0; index < game.center.length; index++)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: index == 2 ? 0 : 8),
                          child: MiniRoleCard(
                            label:
                                game.originalCenter[index] == game.center[index]
                                ? context.tr(game.center[index].name)
                                : '${context.tr(game.originalCenter[index].name)}\n→ ${context.tr(game.center[index].name)}',
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: controller.playAgain,
            child: Text(context.tr('play_again')),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: controller.returnToSetup,
            child: Text(context.tr('adjust_seats')),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  static String _nameFor(GameSession game, String id) =>
      game.players.firstWhere((player) => player.player.id == id).player.name;
}

class ScreenPadding extends StatelessWidget {
  const ScreenPadding({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: child,
  );
}

class SeatBadge extends StatelessWidget {
  const SeatBadge({super.key, required this.number});
  final int number;

  @override
  Widget build(BuildContext context) => Container(
    width: 42,
    height: 42,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Theme.of(context).colorScheme.primary.withValues(alpha: .14),
      border: Border.all(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: .4),
      ),
    ),
    child: Text('$number', style: const TextStyle(fontWeight: FontWeight.w800)),
  );
}

class RoleCard extends StatelessWidget {
  const RoleCard({super.key, required this.role, this.compact = false});
  final Role role;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(compact ? 20 : 28),
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF2E3A3D), Color(0xFF151B1D)],
      ),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: .35),
      ),
      boxShadow: const [
        BoxShadow(color: Colors.black38, blurRadius: 24, offset: Offset(0, 12)),
      ],
    ),
    child: Column(
      children: [
        Icon(
          _roleIcon(role),
          size: compact ? 38 : 62,
          color: Theme.of(context).colorScheme.primary,
        ),
        SizedBox(height: compact ? 12 : 22),
        Text(
          context.tr(role.name),
          style: compact
              ? Theme.of(context).textTheme.headlineMedium
              : Theme.of(context).textTheme.displaySmall,
        ),
        const SizedBox(height: 10),
        Text(
          context.tr('${role.name}_description'),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: .65),
            height: 1.45,
          ),
        ),
      ],
    ),
  );

  static IconData _roleIcon(Role role) => switch (role) {
    Role.werewolf => Icons.pets_rounded,
    Role.minion => Icons.visibility_off_rounded,
    Role.seer => Icons.visibility_rounded,
    Role.robber => Icons.swap_horiz_rounded,
    Role.troublemaker => Icons.shuffle_rounded,
    Role.insomniac => Icons.bedtime_off_rounded,
    Role.villager => Icons.home_rounded,
  };
}

class MiniRoleCard extends StatelessWidget {
  const MiniRoleCard({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    height: 88,
    alignment: Alignment.center,
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: const Color(0xFF20282B),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(
      label,
      textAlign: TextAlign.center,
      style: const TextStyle(fontWeight: FontWeight.w700),
    ),
  );
}

class CenterCards extends StatelessWidget {
  const CenterCards({
    super.key,
    required this.selected,
    required this.maxSelection,
    required this.onChanged,
  });

  final Set<int> selected;
  final int maxSelection;
  final ValueChanged<Set<int>> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var index = 0; index < 3; index++)
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == 2 ? 0 : 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                final next = Set<int>.of(selected);
                if (!next.remove(index) && next.length < maxSelection) {
                  next.add(index);
                }
                onChanged(next);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                height: 110,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected.contains(index)
                      ? Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: .2)
                      : const Color(0xFF20282B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected.contains(index)
                        ? Theme.of(context).colorScheme.primary
                        : Colors.white.withValues(alpha: .1),
                  ),
                ),
                child: Text(
                  context.tr('center_number', {'number': index + 1}),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

class SelectionTile extends StatelessWidget {
  const SelectionTile({
    super.key,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Colors.white.withValues(alpha: .08),
        ),
      ),
      tileColor: selected
          ? Theme.of(context).colorScheme.primary.withValues(alpha: .15)
          : const Color(0xFF151B1D),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      trailing: Icon(
        selected ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
      ),
    ),
  );
}

class InfoPanel extends StatelessWidget {
  const InfoPanel({
    super.key,
    required this.icon,
    required this.text,
    required this.caption,
  });

  final IconData icon;
  final String text;
  final String caption;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFF20282B),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary, size: 34),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                caption,
                style: TextStyle(color: Colors.white.withValues(alpha: .5)),
              ),
              const SizedBox(height: 3),
              Text(
                text,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
