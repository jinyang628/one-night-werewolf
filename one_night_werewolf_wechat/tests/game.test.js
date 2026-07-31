const assert = require('node:assert/strict');
const test = require('node:test');

const {
  defaultRoles,
  nightActors,
  resizeRoles,
  roleCounts,
} = require('../utils/game');

test('default role count is always player count plus three', () => {
  for (let players = 3; players <= 8; players += 1) {
    assert.equal(defaultRoles(players).length, players + 3);
  }
});

test('a second werewolf is added for four or more players', () => {
  assert.equal(defaultRoles(3).filter((role) => role === 'werewolf').length, 1);
  assert.equal(defaultRoles(4).filter((role) => role === 'werewolf').length, 2);
});

test('role resizing preserves cards and prefers removing villagers', () => {
  assert.deepEqual(
    resizeRoles(['werewolf', 'seer', 'villager'], 2),
    ['werewolf', 'seer'],
  );
  assert.deepEqual(
    resizeRoles(['werewolf'], 3),
    ['werewolf', 'villager', 'villager'],
  );
});

test('night actors exclude villagers and follow action order', () => {
  const game = {
    players: [
      { id: 'r', original_role: 'robber' },
      { id: 'v', original_role: 'villager' },
      { id: 'w', original_role: 'werewolf' },
      { id: 's', original_role: 'seer' },
    ],
  };
  assert.deepEqual(nightActors(game).map((player) => player.id), ['w', 's', 'r']);
});

test('role counts include roles with zero cards', () => {
  const counts = roleCounts(['werewolf', 'werewolf', 'seer']);
  assert.equal(counts.find((item) => item.role === 'werewolf').count, 2);
  assert.equal(counts.find((item) => item.role === 'villager').count, 0);
});
