const strings = {
  en: {
    appTitle: 'One Night Werewolf', brand: 'ONE NIGHT WEREWOLF',
    passPlay: 'Pass & play', passPlayDesc: 'Use one phone for roles, night actions, and private voting.',
    roomMode: 'Create or join a room', roomModeDesc: 'Each player joins with a room code.',
    language: '中文', back: 'Back', whoTable: 'Who is at the table?',
    arrange: 'Arrange players clockwise, then choose exactly three more cards than players.',
    player: 'Player', addPlayer: 'Add player', deal: 'Deal roles', configure: 'Configure roles',
    cardsSelected: '{selected} / {required} cards selected', save: 'Save', cancel: 'Cancel',
    passTo: 'Pass to {name}', privacy: 'Make sure only this player can see the screen.',
    ready: 'I’m ready', yourRole: 'Your role', hidePass: 'Hide role & pass',
    nightAction: 'Night action', closeEyes: 'Everyone else: close your eyes.',
    beginAction: 'Start my action', hideContinue: 'Hide & continue',
    discussion: 'EVERYONE, WAKE UP', discuss: 'Discuss, bluff, question, and find the Werewolves.',
    endDiscussion: 'Start voting', secretVote: 'Secret vote', votePrompt: '{name}, choose a player.',
    castVote: 'Cast my vote', villageWins: 'THE VILLAGE WINS',
    werewolvesWin: 'THE WEREWOLVES WIN', minionWins: 'THE MINION WINS',
    eliminated: 'Eliminated: {names}', nobody: 'Nobody was eliminated',
    playAgain: 'Play again', adjust: 'Adjust players & seats', centerCards: 'CENTER CARDS',
    roomTitle: 'Play from your own phones', yourName: 'Your name', roomCode: 'Room code',
    createRoom: 'Create room', joinRoom: 'Join room', host: 'Host', players: 'PLAYERS · {count}/8',
    shareCode: 'Share this code. The lobby refreshes automatically.',
    startRoom: 'Start room', waitingHost: 'Waiting for the host to start…', leaveRoom: 'Leave room',
    roomStarted: 'Room started. The server has dealt and saved this game.',
    choose: 'Choose', viewCard: 'View card', viewPlayer: 'View one player',
    viewCenters: 'View two center cards', swap: 'Swap', actionComplete: 'Action complete',
    loneWolf: 'You are the lone Werewolf. View one center card.',
    fellowWolf: 'Your fellow Werewolf', noWolves: 'No Werewolves are among the players.',
    knowPack: 'I know my pack', rememberWolves: 'I know the Werewolves',
    checkCard: 'Check my card', sleep: 'Sleep through the night',
    serverError: 'Something went wrong', requiredNames: 'Every seat needs a name.',
    werewolf: 'Werewolf', minion: 'Minion', seer: 'Seer', robber: 'Robber',
    troublemaker: 'Troublemaker', insomniac: 'Insomniac', villager: 'Villager',
  },
  zh: {
    appTitle: '一夜狼人杀', brand: '一夜狼人杀',
    passPlay: '传递手机', passPlayDesc: '共用一部手机，依次查看身份、执行夜间行动并秘密投票。',
    roomMode: '创建或加入房间', roomModeDesc: '每位玩家用房间码加入游戏。',
    language: 'English', back: '返回', whoTable: '谁在桌边？',
    arrange: '按顺时针排列玩家，并选择比玩家人数多三张的身份牌。',
    player: '玩家', addPlayer: '添加玩家', deal: '发放身份', configure: '配置身份牌',
    cardsSelected: '已选择 {selected} / {required} 张', save: '保存', cancel: '取消',
    passTo: '请传给 {name}', privacy: '请确保只有这位玩家能看到屏幕。',
    ready: '我准备好了', yourRole: '你的身份', hidePass: '隐藏身份并传递',
    nightAction: '夜间行动', closeEyes: '其他玩家请闭上眼睛。',
    beginAction: '开始我的行动', hideContinue: '隐藏并继续',
    discussion: '所有人，请睁眼', discuss: '讨论、质疑、伪装，并找出狼人。',
    endDiscussion: '开始投票', secretVote: '秘密投票', votePrompt: '{name}，请选择一名玩家。',
    castVote: '确认投票', villageWins: '村民阵营获胜',
    werewolvesWin: '狼人阵营获胜', minionWins: '爪牙获胜',
    eliminated: '出局：{names}', nobody: '无人出局',
    playAgain: '原座位再玩一局', adjust: '调整玩家和座位', centerCards: '中央牌',
    roomTitle: '使用各自的手机游戏', yourName: '你的名字', roomCode: '房间码',
    createRoom: '创建房间', joinRoom: '加入房间', host: '房主', players: '玩家 · {count}/8',
    shareCode: '分享此房间码，大厅会自动刷新。',
    startRoom: '开始游戏', waitingHost: '等待房主开始…', leaveRoom: '离开房间',
    roomStarted: '房间已开始，服务器已发牌并保存游戏。',
    choose: '请选择', viewCard: '查看牌', viewPlayer: '查看一名玩家',
    viewCenters: '查看两张中央牌', swap: '交换', actionComplete: '行动完成',
    loneWolf: '你是唯一的狼人，请查看一张中央牌。',
    fellowWolf: '你的狼人同伴', noWolves: '玩家中没有狼人。',
    knowPack: '我知道同伴了', rememberWolves: '我知道狼人了',
    checkCard: '查看我的牌', sleep: '安睡到天亮',
    serverError: '操作失败', requiredNames: '每个座位都需要填写名字。',
    werewolf: '狼人', minion: '爪牙', seer: '预言家', robber: '强盗',
    troublemaker: '捣蛋鬼', insomniac: '失眠者', villager: '村民',
  },
};

const descriptions = {
  en: {
    werewolf: 'Find the other Werewolf. If alone, view one center card.',
    minion: 'See the Werewolves and help their team survive.',
    seer: 'View another player’s card or two center cards.',
    robber: 'Swap with another player, then view your new card.',
    troublemaker: 'Swap two other players’ cards without viewing them.',
    insomniac: 'Wake last and check whether your role changed.',
    villager: 'No night action. Listen carefully and find the Werewolves.',
  },
  zh: {
    werewolf: '寻找其他狼人；如果是唯一狼人，可查看一张中央牌。',
    minion: '查看狼人是谁，并帮助狼人阵营存活。',
    seer: '查看一名玩家的身份，或查看两张中央牌。',
    robber: '与另一名玩家交换身份牌，然后查看自己的新身份。',
    troublemaker: '交换另外两名玩家的身份牌，但不能查看。',
    insomniac: '最后醒来，查看自己的身份是否改变。',
    villager: '没有夜间行动。仔细听并找出狼人。',
  },
};

function interpolate(value, params = {}) {
  return Object.keys(params).reduce(
    (text, key) => text.split(`{${key}}`).join(String(params[key])),
    value,
  );
}

function t(locale, key, params) {
  return interpolate((strings[locale] || strings.en)[key] || strings.en[key] || key, params);
}

function description(locale, role) {
  return (descriptions[locale] || descriptions.en)[role];
}

module.exports = { description, t };
