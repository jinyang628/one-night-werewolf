const ROLES = [
  'werewolf',
  'minion',
  'seer',
  'robber',
  'troublemaker',
  'insomniac',
  'villager',
];

const NIGHT_ORDER = ROLES.reduce((order, role, index) => {
  order[role] = index;
  return order;
}, {});

function defaultRoles(playerCount) {
  const roles = ['werewolf', 'minion', 'seer', 'robber', 'troublemaker', 'insomniac'];
  if (playerCount >= 4) roles.push('werewolf');
  while (roles.length < playerCount + 3) roles.push('villager');
  return roles;
}

function resizeRoles(roles, required) {
  const next = roles.slice();
  while (next.length < required) next.push('villager');
  while (next.length > required) {
    const villager = next.lastIndexOf('villager');
    next.splice(villager >= 0 ? villager : next.length - 1, 1);
  }
  return next;
}

function roleCounts(roles) {
  return ROLES.map((role) => ({
    role,
    count: roles.filter((value) => value === role).length,
  }));
}

function nightActors(game) {
  return game.players
    .filter((player) => player.original_role !== 'villager')
    .sort((a, b) => NIGHT_ORDER[a.original_role] - NIGHT_ORDER[b.original_role]);
}

function playerName(game, id) {
  const player = game.players.find((item) => item.id === id);
  return player ? player.name : id;
}

module.exports = {
  NIGHT_ORDER,
  ROLES,
  defaultRoles,
  nightActors,
  playerName,
  resizeRoles,
  roleCounts,
};
