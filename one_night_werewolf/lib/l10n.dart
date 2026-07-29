import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [Locale('en'), Locale('zh')];

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  String text(String key, [Map<String, Object> values = const {}]) {
    var value =
        (_strings[locale.languageCode] ?? _strings['en']!)[key] ??
        _strings['en']![key] ??
        key;
    for (final entry in values.entries) {
      value = value.replaceAll('{${entry.key}}', '${entry.value}');
    }
    return value;
  }
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales.any(
    (supported) => supported.languageCode == locale.languageCode,
  );

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture(AppLocalizations(locale));

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}

extension LocalizedBuildContext on BuildContext {
  String tr(String key, [Map<String, Object> values = const {}]) =>
      AppLocalizations.of(this).text(key, values);
}

const _strings = <String, Map<String, String>>{
  'en': {
    'app_title': 'One Night Werewolf',
    'brand': 'ONE NIGHT WEREWOLF',
    'language': 'Language',
    'english': 'English',
    'chinese': '中文',
    'how_playing': 'How are you playing?',
    'pass_play': 'Pass & play',
    'pass_play_description':
        'Use one phone. Reveal roles, take actions, and vote privately.',
    'room_mode': 'Create or join a room',
    'room_mode_description':
        'Each player connects with a room code from their own device.',
    'server_storage': 'All games are stored securely through the game server.',
    'role_reveal': 'ROLE REVEAL',
    'role_privacy': 'Make sure only you can see the screen.',
    'ready': 'I’m ready',
    'night_action': 'NIGHT ACTION',
    'close_eyes': 'Everyone else: close your eyes.',
    'start_action': 'Start my action',
    'secret_vote': 'SECRET VOTE',
    'pass_vote': 'Pass the phone without revealing your choice.',
    'cast_vote': 'Cast my vote',
    'play_phones': 'Play from your own phones',
    'room_instructions':
        'Choose a display name, then create a room or enter an existing code.',
    'your_name': 'Your name',
    'create_room': 'Create room',
    'or': 'OR',
    'room_code': 'Room code',
    'join_room': 'Join room',
    'room_started': 'ROOM STARTED',
    'share_room': 'Share this code. The lobby refreshes automatically.',
    'started_room_description':
        'The server has dealt and persisted this game. Device-specific role screens can now build on this room session.',
    'players_count': 'PLAYERS · {count}/8',
    'host': 'Host',
    'start_room': 'Start room',
    'waiting_host': 'Waiting for the host to start…',
    'leave_room': 'Leave room',
    'who_table': 'Who is at the table?',
    'arrange_players':
        'Arrange players clockwise. Use the arrows to swap seats between games.',
    'player_name': 'Player name',
    'default_player': 'Player {number}',
    'move_up': 'Move seat up',
    'move_down': 'Move seat down',
    'remove_player': 'Remove player',
    'every_seat_name': 'Every seat needs a name.',
    'add_player': 'Add player',
    'deal_roles': 'Deal roles',
    'players_cards': '{players} players · {cards} cards',
    'pass_to': 'Pass to {name}',
    'hide_role_pass': 'Hide role & pass',
    'hide_continue': 'Hide & continue',
    'fellow_werewolf': 'Your fellow Werewolf',
    'know_pack': 'I know my pack',
    'lone_wolf': 'You are the lone Werewolf. View one center card.',
    'view_card': 'View card',
    'view_player': 'View one player',
    'view_two_center': 'OR VIEW TWO CENTER CARDS',
    'view_center_cards': 'View center cards',
    'swap_with': 'Swap with {name}',
    'swap_selected': 'Swap selected players',
    'action_complete': 'Action complete',
    'wake_up': 'EVERYONE, WAKE UP',
    'discussion_instructions':
        'Discuss what happened. Bluff, question, and decide who the Werewolves are.',
    'start_voting': 'Start voting',
    'end_discussion': 'End discussion early',
    'who_werewolf': 'Who is a Werewolf?',
    'vote_instructions':
        '{name}, choose one player. You cannot vote for yourself.',
    'village_wins': 'THE VILLAGE WINS',
    'werewolves_win': 'THE WEREWOLVES WIN',
    'minion_wins': 'THE MINION WINS',
    'nobody_eliminated': 'Nobody was eliminated',
    'eliminated': '{names} eliminated',
    'votes': '{count} votes',
    'center_cards': 'CENTER CARDS',
    'center_number': 'CENTER\n{number}',
    'play_again': 'Play again, same seats',
    'adjust_seats': 'Adjust players & seats',
    'werewolf': 'Werewolf',
    'minion': 'Minion',
    'seer': 'Seer',
    'robber': 'Robber',
    'troublemaker': 'Troublemaker',
    'insomniac': 'Insomniac',
    'villager': 'Villager',
    'werewolf_description':
        'Find the other Werewolf. If you are alone, view one center card.',
    'seer_description': 'View another player’s card or two center cards.',
    'minion_description':
        'See who the Werewolves are and help their team survive.',
    'robber_description': 'Swap with another player, then view your new card.',
    'troublemaker_description':
        'Swap two other players’ cards without viewing them.',
    'insomniac_description':
        'Wake last and check whether your own role changed.',
    'villager_description':
        'You have no night action. Listen carefully and find the Werewolves.',
    'open_eyes': 'Open your eyes',
    'find_werewolves': 'Find the Werewolves',
    'what_see': 'What do you want to see?',
    'choose_rob': 'Choose someone to rob',
    'choose_two': 'Choose two players',
    'did_role_change': 'Did your role change?',
    'sleep_night': 'Sleep through the night',
    'center_is': 'Center card {number} is',
    'found_pack': 'You found your pack.',
    'player_is': '{name} is',
    'centers_are': 'Center cards {numbers} are',
    'robbed_result': 'You swapped with {name}. Your new role is',
    'trouble_result': 'You swapped {first} and {second}.',
    'minion_saw': 'Werewolves you saw',
    'no_werewolves_seen': 'No Werewolves are among the players',
    'remember_werewolves': 'I know the Werewolves',
    'minion_result': 'You know who the Werewolves are.',
    'insomniac_prompt': 'View your card to learn your final role.',
    'check_my_card': 'Check my card',
    'insomniac_result': 'Your final role is',
  },
  'zh': {
    'app_title': '一夜狼人杀',
    'brand': '一夜狼人杀',
    'language': '语言',
    'english': 'English',
    'chinese': '中文',
    'how_playing': '选择游戏方式',
    'pass_play': '传递手机',
    'pass_play_description': '共用一部手机，依次查看身份、执行行动并秘密投票。',
    'room_mode': '创建或加入房间',
    'room_mode_description': '每位玩家使用自己的设备，通过房间码连接。',
    'server_storage': '所有游戏状态均通过服务器安全保存。',
    'role_reveal': '查看身份',
    'role_privacy': '请确保只有你能看到屏幕。',
    'ready': '我准备好了',
    'night_action': '夜间行动',
    'close_eyes': '其他玩家请闭上眼睛。',
    'start_action': '开始我的行动',
    'secret_vote': '秘密投票',
    'pass_vote': '选择后请传递手机，不要透露投票。',
    'cast_vote': '开始投票',
    'play_phones': '使用各自的手机游戏',
    'room_instructions': '输入显示名称，然后创建房间或输入现有房间码。',
    'your_name': '你的名字',
    'create_room': '创建房间',
    'or': '或',
    'room_code': '房间码',
    'join_room': '加入房间',
    'room_started': '房间已开始',
    'share_room': '分享此房间码。大厅会自动刷新。',
    'started_room_description': '服务器已发牌并保存游戏。之后可在此房间会话上扩展各设备的身份界面。',
    'players_count': '玩家 · {count}/8',
    'host': '房主',
    'start_room': '开始游戏',
    'waiting_host': '等待房主开始…',
    'leave_room': '离开房间',
    'who_table': '谁在桌边？',
    'arrange_players': '按顺时针排列玩家。两局之间可用箭头调整座位。',
    'player_name': '玩家名称',
    'default_player': '玩家 {number}',
    'move_up': '向前移动座位',
    'move_down': '向后移动座位',
    'remove_player': '移除玩家',
    'every_seat_name': '每个座位都需要填写名称。',
    'add_player': '添加玩家',
    'deal_roles': '发放身份',
    'players_cards': '{players} 位玩家 · {cards} 张牌',
    'pass_to': '请传给 {name}',
    'hide_role_pass': '隐藏身份并传递',
    'hide_continue': '隐藏并继续',
    'fellow_werewolf': '你的狼人同伴',
    'know_pack': '我知道同伴了',
    'lone_wolf': '你是唯一的狼人。查看一张中央牌。',
    'view_card': '查看牌',
    'view_player': '查看一名玩家',
    'view_two_center': '或查看两张中央牌',
    'view_center_cards': '查看中央牌',
    'swap_with': '与 {name} 交换',
    'swap_selected': '交换所选玩家',
    'action_complete': '行动完成',
    'wake_up': '所有人，睁开眼睛',
    'discussion_instructions': '讨论刚才发生了什么。虚张声势、互相质问，并找出狼人。',
    'start_voting': '开始投票',
    'end_discussion': '提前结束讨论',
    'who_werewolf': '谁是狼人？',
    'vote_instructions': '{name}，请选择一名玩家。不能投给自己。',
    'village_wins': '村民阵营获胜',
    'werewolves_win': '狼人阵营获胜',
    'minion_wins': '爪牙获胜',
    'nobody_eliminated': '没有人被淘汰',
    'eliminated': '{names} 被淘汰',
    'votes': '{count} 票',
    'center_cards': '中央牌',
    'center_number': '中央牌\n{number}',
    'play_again': '保持座位，再玩一局',
    'adjust_seats': '调整玩家和座位',
    'werewolf': '狼人',
    'minion': '爪牙',
    'seer': '预言家',
    'robber': '强盗',
    'troublemaker': '捣蛋鬼',
    'insomniac': '失眠者',
    'villager': '村民',
    'werewolf_description': '寻找另一名狼人。如果你是唯一的狼人，可查看一张中央牌。',
    'seer_description': '查看另一名玩家的牌，或查看两张中央牌。',
    'minion_description': '查看哪些玩家是狼人，并帮助狼人阵营存活。',
    'robber_description': '与另一名玩家交换身份牌，然后查看自己的新身份。',
    'troublemaker_description': '交换另外两名玩家的身份牌，但不能查看。',
    'insomniac_description': '最后醒来，查看自己的身份是否发生变化。',
    'villager_description': '你没有夜间行动。仔细倾听并找出狼人。',
    'open_eyes': '睁开眼睛',
    'find_werewolves': '寻找狼人',
    'what_see': '你想查看什么？',
    'choose_rob': '选择一名玩家交换',
    'choose_two': '选择两名玩家',
    'did_role_change': '你的身份变了吗？',
    'sleep_night': '安静地度过夜晚',
    'center_is': '中央牌 {number} 是',
    'found_pack': '你找到了狼人同伴。',
    'player_is': '{name} 是',
    'centers_are': '中央牌 {numbers} 分别是',
    'robbed_result': '你与 {name} 交换了身份。你的新身份是',
    'trouble_result': '你交换了 {first} 和 {second} 的身份牌。',
    'minion_saw': '你看到的狼人',
    'no_werewolves_seen': '玩家中没有狼人',
    'remember_werewolves': '我知道狼人是谁了',
    'minion_result': '你已经知道狼人是谁。',
    'insomniac_prompt': '查看自己的牌，确认最终身份。',
    'check_my_card': '查看我的牌',
    'insomniac_result': '你的最终身份是',
  },
};
