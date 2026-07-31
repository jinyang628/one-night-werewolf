const { games } = require('../../utils/api');
const {
  ROLES,
  defaultRoles,
  nightActors,
  playerName,
  resizeRoles,
  roleCounts,
} = require('../../utils/game');
const { description, t } = require('../../utils/i18n');

const ICONS = {
  werewolf: '🐺',
  minion: '🌑',
  seer: '👁',
  robber: '↔',
  troublemaker: '⤨',
  insomniac: '☾',
  villager: '⌂',
};

Page({
  data: {
    phase: 'home',
    locale: 'zh',
    copy: {},
    roles: [],
    players: [],
    selectedRoles: [],
    selectedRoleChips: [],
    roomName: '',
    roomCodeInput: '',
    room: null,
    roomPlayers: [],
    roomSession: null,
    isRoomHost: false,
    game: null,
    activeIndex: 0,
    activePlayer: null,
    activeGamePlayer: null,
    activeRoleName: '',
    activeRoleDescription: '',
    nightActors: [],
    otherPlayers: [],
    werewolfPartners: [],
    selectedPlayers: [],
    selectedCenters: [],
    centerCards: [
      { index: 0, selected: false },
      { index: 1, selected: false },
      { index: 2, selected: false },
    ],
    actionCommitted: false,
    actionSummary: '',
    seenRoleCards: [],
    secondsRemaining: 180,
    timerText: '03:00',
    voteTarget: '',
    resultTitle: '',
    resultSubtitle: '',
    resultRows: [],
    centerRows: [],
    busy: false,
    error: '',
    roleEditorOpen: false,
    roleEditorFor: 'game',
    roleEditorCounts: [],
    roleEditorTotal: 0,
    roleEditorRequired: 6,
  },

  onLoad() {
    const locale = getApp().globalData.locale || 'zh';
    const players = [1, 2, 3].map((number) => ({
      id: `player-${number}`,
      name: locale === 'zh' ? `玩家 ${number}` : `Player ${number}`,
    }));
    this.setData({
      locale,
      players,
      selectedRoles: defaultRoles(3),
    });
    this.refreshView();
  },

  onShow() {
    if (this.data.phase === 'roomLobby' && this.data.room && this.data.room.status === 'waiting') {
      this.startRoomPolling();
    }
    if (this.data.phase === 'discussion' && this.data.secondsRemaining > 0) {
      this.startDiscussionTimer();
    }
  },

  onHide() {
    this.stopTimers();
  },

  onUnload() {
    this.stopTimers();
  },

  refreshView() {
    const locale = this.data.locale;
    const copyKeys = [
      'appTitle', 'brand', 'passPlay', 'passPlayDesc', 'roomMode', 'roomModeDesc',
      'language', 'back', 'whoTable', 'arrange', 'player', 'addPlayer', 'deal',
      'configure', 'save', 'cancel', 'privacy', 'ready', 'yourRole', 'hidePass',
      'nightAction', 'closeEyes', 'beginAction', 'hideContinue', 'discussion',
      'discuss', 'endDiscussion', 'secretVote', 'castVote', 'playAgain', 'adjust',
      'centerCards', 'roomTitle', 'yourName', 'roomCode', 'createRoom', 'joinRoom',
      'host', 'shareCode', 'startRoom', 'waitingHost', 'leaveRoom', 'roomStarted',
      'choose', 'viewCard', 'viewPlayer', 'viewCenters', 'swap', 'actionComplete',
      'loneWolf', 'fellowWolf', 'noWolves', 'knowPack', 'rememberWolves',
      'checkCard', 'sleep',
    ];
    const copy = copyKeys.reduce((values, key) => {
      values[key] = t(locale, key);
      return values;
    }, {});
    const roles = ROLES.map((role) => ({
      id: role,
      name: t(locale, role),
      description: description(locale, role),
      icon: ICONS[role],
    }));
    const selectedRoleChips = roleCounts(this.data.selectedRoles)
      .filter((item) => item.count)
      .map((item) => ({
        ...item,
        name: t(locale, item.role),
        icon: ICONS[item.role],
      }));

    const update = { copy, roles, selectedRoleChips };
    const game = this.data.game;
    const phase = this.data.phase;
    if (game && !['home', 'setup', 'roomEntry', 'roomLobby'].includes(phase)) {
      const actors = this.data.nightActors;
      const source = ['nightHandoff', 'nightAction'].includes(phase) ? actors : game.players;
      const active = source[this.data.activeIndex] || game.players[0];
      update.activePlayer = active;
      update.activeGamePlayer = active;
      update.activeRoleName = active ? t(locale, active.original_role) : '';
      update.activeRoleDescription = active ? description(locale, active.original_role) : '';
      update.otherPlayers = active
        ? game.players.filter((player) => player.id !== active.id)
        : [];
      update.werewolfPartners = active
        ? game.players.filter(
          (player) => player.id !== active.id && player.original_role === 'werewolf',
        )
        : [];
      update.passToText = active ? t(locale, 'passTo', { name: active.name }) : '';
      update.votePrompt = active ? t(locale, 'votePrompt', { name: active.name }) : '';
    }
    if (this.data.room) {
      update.roomPlayers = this.data.room.players.map((player) => ({
        ...player,
        isHost: player.id === this.data.room.host_player_id,
      }));
      update.isRoomHost =
        this.data.roomSession &&
        this.data.roomSession.player_id === this.data.room.host_player_id;
      update.roomPlayersText = t(locale, 'players', { count: this.data.room.players.length });
    }
    this.setData(update);
  },

  setPhase(phase, extra = {}) {
    this.setData({ phase, error: '', ...extra });
    this.refreshView();
  },

  toggleLocale() {
    const locale = this.data.locale === 'zh' ? 'en' : 'zh';
    getApp().globalData.locale = locale;
    wx.setStorageSync('locale', locale);
    const players = this.data.players.map((player, index) => {
      if (/^(Player|玩家) \d+$/.test(player.name)) {
        return { ...player, name: locale === 'zh' ? `玩家 ${index + 1}` : `Player ${index + 1}` };
      }
      return player;
    });
    this.setData({ locale, players });
    this.refreshView();
    wx.setNavigationBarTitle({ title: t(locale, 'appTitle') });
  },

  choosePassPlay() {
    this.setPhase('setup');
  },

  chooseRoom() {
    this.setPhase('roomEntry');
  },

  goHome() {
    this.stopTimers();
    this.setData({
      game: null,
      room: null,
      roomSession: null,
      nightActors: [],
      activeIndex: 0,
    });
    this.setPhase('home');
  },

  updatePlayerName(event) {
    const index = Number(event.currentTarget.dataset.index);
    this.setData({ [`players[${index}].name`]: event.detail.value });
  },

  addPlayer() {
    if (this.data.players.length >= 8) return;
    const number = this.data.players.length + 1;
    const players = this.data.players.concat({
      id: `player-${Date.now()}-${number}`,
      name: this.data.locale === 'zh' ? `玩家 ${number}` : `Player ${number}`,
    });
    const selectedRoles = resizeRoles(this.data.selectedRoles, players.length + 3);
    this.setData({ players, selectedRoles });
    this.refreshView();
  },

  removePlayer(event) {
    if (this.data.players.length <= 3) return;
    const index = Number(event.currentTarget.dataset.index);
    const players = this.data.players.filter((_, itemIndex) => itemIndex !== index);
    const selectedRoles = resizeRoles(this.data.selectedRoles, players.length + 3);
    this.setData({ players, selectedRoles });
    this.refreshView();
  },

  movePlayer(event) {
    const from = Number(event.currentTarget.dataset.index);
    const delta = Number(event.currentTarget.dataset.delta);
    const to = from + delta;
    if (to < 0 || to >= this.data.players.length) return;
    const players = this.data.players.slice();
    const [player] = players.splice(from, 1);
    players.splice(to, 0, player);
    this.setData({ players });
  },

  async startGame() {
    if (this.data.players.some((player) => !player.name.trim())) {
      this.showError(t(this.data.locale, 'requiredNames'));
      return;
    }
    await this.run(async () => {
      const game = await games.start(this.data.players, this.data.selectedRoles);
      this.setData({
        game,
        nightActors: [],
        activeIndex: 0,
        selectedPlayers: [],
        selectedCenters: [],
        centerCards: this.emptyCenterCards(),
        actionCommitted: false,
      });
      this.setPhase('roleHandoff');
    });
  },

  showRole() {
    this.setPhase('roleReveal');
  },

  async hideRole() {
    await this.run(async () => {
      const active = this.data.game.players[this.data.activeIndex];
      const game = await games.acknowledgeRole(this.data.game, active.id);
      if (this.data.activeIndex < game.players.length - 1) {
        this.setData({ game, activeIndex: this.data.activeIndex + 1 });
        this.setPhase('roleHandoff');
        return;
      }
      const actors = nightActors(game);
      this.setData({ game, nightActors: actors, activeIndex: 0 });
      if (actors.length) {
        this.setPhase('nightHandoff');
      } else {
        this.beginDiscussion();
      }
    });
  },

  beginNightAction() {
    this.setPhase('nightAction', {
      selectedPlayers: [],
      selectedCenters: [],
      centerCards: this.emptyCenterCards(),
      actionCommitted: false,
      actionSummary: '',
      seenRoleCards: [],
    });
  },

  togglePlayer(event) {
    if (this.data.actionCommitted) return;
    const id = event.currentTarget.dataset.id;
    const role = this.data.activeGamePlayer.original_role;
    const limit = role === 'troublemaker' ? 2 : 1;
    const selected = this.data.selectedPlayers.slice();
    const found = selected.indexOf(id);
    if (found >= 0) selected.splice(found, 1);
    else if (selected.length < limit) selected.push(id);
    this.setData({
      selectedPlayers: selected,
      voteTarget: selected.length === 1 ? selected[0] : '',
      otherPlayers: this.data.otherPlayers.map((player) => ({
        ...player,
        selected: selected.includes(player.id),
      })),
    });
  },

  toggleCenter(event) {
    if (this.data.actionCommitted) return;
    const index = Number(event.currentTarget.dataset.index);
    const role = this.data.activeGamePlayer.original_role;
    const limit = role === 'seer' ? 2 : 1;
    const selected = this.data.selectedCenters.slice();
    const found = selected.indexOf(index);
    if (found >= 0) selected.splice(found, 1);
    else if (selected.length < limit) selected.push(index);
    this.setData({
      selectedCenters: selected,
      centerCards: [0, 1, 2].map((cardIndex) => ({
        index: cardIndex,
        selected: selected.includes(cardIndex),
      })),
    });
  },

  async commitSimpleAction() {
    await this.commitAction([], [], t(this.data.locale, 'actionComplete'));
  },

  async commitPlayerAction(event) {
    const directId = event.currentTarget.dataset.id;
    const targets = directId ? [directId] : this.data.selectedPlayers;
    const role = this.data.activeGamePlayer.original_role;
    const valid = role === 'troublemaker' ? targets.length === 2 : targets.length === 1;
    if (!valid) return;
    const names = targets.map((id) => playerName(this.data.game, id)).join(' & ');
    await this.commitAction(targets, [], `${t(this.data.locale, 'actionComplete')}: ${names}`);
  },

  async commitCenterAction() {
    const role = this.data.activeGamePlayer.original_role;
    const required = role === 'seer' ? 2 : 1;
    if (this.data.selectedCenters.length !== required) return;
    await this.commitAction(
      [],
      this.data.selectedCenters,
      `${t(this.data.locale, 'actionComplete')}: ${this.data.selectedCenters.map((i) => i + 1).join(' & ')}`,
    );
  },

  async commitAction(playerTargets, centerTargets, summary) {
    await this.run(async () => {
      const response = await games.nightAction(
        this.data.game,
        this.data.activeGamePlayer.id,
        playerTargets,
        centerTargets,
      );
      const seenRoleCards = (response.seen_roles || []).map((role) => ({
        role,
        icon: ICONS[role],
        name: t(this.data.locale, role),
      }));
      this.setData({
        game: response.game,
        actionCommitted: true,
        actionSummary: summary,
        seenRoleCards,
      });
      this.refreshView();
    });
  },

  finishNightTurn() {
    if (!this.data.actionCommitted) return;
    if (this.data.activeIndex < this.data.nightActors.length - 1) {
      this.setData({ activeIndex: this.data.activeIndex + 1 });
      this.setPhase('nightHandoff');
    } else {
      this.beginDiscussion();
    }
  },

  beginDiscussion() {
    this.setPhase('discussion', { activeIndex: 0, secondsRemaining: 180, timerText: '03:00' });
    this.startDiscussionTimer();
  },

  startDiscussionTimer() {
    clearInterval(this.discussionTimer);
    this.discussionTimer = setInterval(() => {
      const seconds = Math.max(0, this.data.secondsRemaining - 1);
      this.setData({ secondsRemaining: seconds, timerText: this.formatTime(seconds) });
      if (!seconds) clearInterval(this.discussionTimer);
    }, 1000);
  },

  async endDiscussion() {
    await this.run(async () => {
      const game = await games.endDiscussion(this.data.game);
      clearInterval(this.discussionTimer);
      this.setData({ game, activeIndex: 0 });
      this.setPhase('voteHandoff');
    });
  },

  beginVote() {
    this.setPhase('voting', { voteTarget: '', selectedPlayers: [] });
  },

  selectVote(event) {
    const id = event.currentTarget.dataset.id;
    if (id === this.data.activePlayer.id) return;
    this.setData({ voteTarget: id, selectedPlayers: [id] });
  },

  async castVote() {
    if (!this.data.voteTarget) return;
    await this.run(async () => {
      const response = await games.vote(
        this.data.game,
        this.data.activePlayer.id,
        this.data.voteTarget,
      );
      const game = response.game;
      if (this.data.activeIndex < game.players.length - 1) {
        this.setData({ game, activeIndex: this.data.activeIndex + 1, voteTarget: '' });
        this.setPhase('voteHandoff');
      } else {
        this.setData({ game });
        this.showResult();
      }
    });
  },

  showResult() {
    const game = this.data.game;
    const result = game.result;
    const locale = this.data.locale;
    const key = result.winning_team === 'village'
      ? 'villageWins'
      : result.winning_team === 'minion' ? 'minionWins' : 'werewolvesWin';
    const names = result.eliminated_player_ids.map((id) => playerName(game, id));
    const resultRows = game.players.map((player) => ({
      ...player,
      originalName: t(locale, player.original_role),
      currentName: t(locale, player.current_role),
      roleChanged: player.original_role !== player.current_role,
      votes: (result.tallies.find((item) => item.player_id === player.id) || { votes: 0 }).votes,
      eliminated: result.eliminated_player_ids.includes(player.id),
    }));
    const centerRows = game.center.map((role, index) => ({
      index: index + 1,
      originalName: t(locale, game.original_center[index]),
      currentName: t(locale, role),
      roleChanged: role !== game.original_center[index],
    }));
    this.setData({
      resultTitle: t(locale, key),
      resultSubtitle: names.length ? t(locale, 'eliminated', { names: names.join(', ') }) : t(locale, 'nobody'),
      resultRows,
      centerRows,
    });
    this.setPhase('result');
  },

  async playAgain() {
    await this.startGame();
  },

  returnToSetup() {
    this.setData({ game: null, activeIndex: 0, nightActors: [] });
    this.setPhase('setup');
  },

  updateRoomName(event) {
    this.setData({ roomName: event.detail.value });
  },

  updateRoomCode(event) {
    this.setData({ roomCodeInput: event.detail.value.toUpperCase() });
  },

  async createRoom() {
    if (!this.data.roomName.trim()) return;
    await this.run(async () => {
      const session = await games.createRoom(this.data.roomName);
      this.enterRoom(session);
    });
  },

  async joinRoom() {
    if (!this.data.roomName.trim() || !this.data.roomCodeInput.trim()) return;
    await this.run(async () => {
      const session = await games.joinRoom(this.data.roomCodeInput, this.data.roomName);
      this.enterRoom(session);
    });
  },

  enterRoom(session) {
    this.setData({
      roomSession: session,
      room: session.room,
      selectedRoles: session.room.selected_roles,
    });
    this.setPhase('roomLobby');
    this.startRoomPolling();
  },

  startRoomPolling() {
    clearInterval(this.roomPoller);
    this.roomPoller = setInterval(async () => {
      if (this.data.busy || !this.data.room) return;
      try {
        const room = await games.getRoom(this.data.room.room_code);
        this.setData({ room, selectedRoles: room.selected_roles });
        this.refreshView();
        if (room.status !== 'waiting') clearInterval(this.roomPoller);
      } catch (error) {
        this.showError(error.message);
      }
    }, 2000);
  },

  async startRoom() {
    await this.run(async () => {
      await games.startRoom(this.data.roomSession, this.data.room);
      const room = await games.getRoom(this.data.room.room_code);
      clearInterval(this.roomPoller);
      this.setData({ room });
      this.refreshView();
    });
  },

  leaveRoom() {
    clearInterval(this.roomPoller);
    this.setData({ room: null, roomSession: null });
    this.setPhase('home');
  },

  openRoleEditor(event) {
    const editorFor = event.currentTarget.dataset.for || 'game';
    const roles = editorFor === 'room' ? this.data.room.selected_roles : this.data.selectedRoles;
    const required = editorFor === 'room'
      ? this.data.room.players.length + 3
      : this.data.players.length + 3;
    const counts = roleCounts(roles).map((item) => ({
      ...item,
      name: t(this.data.locale, item.role),
      description: description(this.data.locale, item.role),
      icon: ICONS[item.role],
    }));
    this.setData({
      roleEditorOpen: true,
      roleEditorFor: editorFor,
      roleEditorCounts: counts,
      roleEditorTotal: roles.length,
      roleEditorRequired: required,
      roleEditorHelp: t(this.data.locale, 'cardsSelected', {
        selected: roles.length,
        required,
      }),
    });
  },

  changeRoleCount(event) {
    const index = Number(event.currentTarget.dataset.index);
    const delta = Number(event.currentTarget.dataset.delta);
    const counts = this.data.roleEditorCounts.slice();
    const total = this.data.roleEditorTotal + delta;
    if (counts[index].count + delta < 0 || total > this.data.roleEditorRequired) return;
    counts[index] = { ...counts[index], count: counts[index].count + delta };
    this.setData({
      roleEditorCounts: counts,
      roleEditorTotal: total,
      roleEditorHelp: t(this.data.locale, 'cardsSelected', {
        selected: total,
        required: this.data.roleEditorRequired,
      }),
    });
  },

  closeRoleEditor() {
    this.setData({ roleEditorOpen: false });
  },

  async saveRoleEditor() {
    if (this.data.roleEditorTotal !== this.data.roleEditorRequired) return;
    const roles = this.data.roleEditorCounts.reduce(
      (values, item) => values.concat(Array(item.count).fill(item.role)),
      [],
    );
    if (this.data.roleEditorFor === 'room') {
      await this.run(async () => {
        const room = await games.configureRoom(
          this.data.roomSession,
          this.data.room,
          roles,
        );
        this.setData({ room, selectedRoles: roles, roleEditorOpen: false });
        this.refreshView();
      });
    } else {
      this.setData({ selectedRoles: roles, roleEditorOpen: false });
      this.refreshView();
    }
  },

  async run(operation) {
    if (this.data.busy) return;
    this.setData({ busy: true, error: '' });
    try {
      await operation();
    } catch (error) {
      this.showError(error.message);
    } finally {
      this.setData({ busy: false });
    }
  },

  showError(message) {
    this.setData({ error: message || t(this.data.locale, 'serverError') });
    clearTimeout(this.errorTimer);
    this.errorTimer = setTimeout(() => this.setData({ error: '' }), 5000);
  },

  formatTime(seconds) {
    const minutes = Math.floor(seconds / 60).toString().padStart(2, '0');
    const remainder = (seconds % 60).toString().padStart(2, '0');
    return `${minutes}:${remainder}`;
  },

  emptyCenterCards() {
    return [0, 1, 2].map((index) => ({ index, selected: false }));
  },

  stopTimers() {
    clearInterval(this.discussionTimer);
    clearInterval(this.roomPoller);
    clearTimeout(this.errorTimer);
  },
});
