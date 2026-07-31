const { apiBaseUrl } = require('../config');

class ApiError extends Error {}

function request(method, path, data) {
  return new Promise((resolve, reject) => {
    wx.request({
      url: `${apiBaseUrl}${path}`,
      method,
      data,
      timeout: 15000,
      header: { 'content-type': 'application/json' },
      success(response) {
        if (response.statusCode >= 200 && response.statusCode < 300) {
          resolve(response.data);
          return;
        }
        const body = response.data || {};
        let message = body.detail || body.message || `Server error (${response.statusCode})`;
        if (Array.isArray(message)) {
          message = message.map((item) => item.msg || String(item)).join('\n');
        }
        reject(new ApiError(message));
      },
      fail(error) {
        reject(new ApiError(error.errMsg || `Could not reach ${apiBaseUrl}`));
      },
    });
  });
}

const games = {
  start(players, roles) {
    return request('POST', '/games', {
      players: players.map((player, index) => ({
        id: player.id,
        name: player.name.trim(),
        seat: index + 1,
      })),
      roles,
    });
  },
  get(gameId) {
    return request('GET', `/games/${gameId}`);
  },
  acknowledgeRole(game, playerId) {
    return request('POST', `/games/${game.id}/role-acknowledgements`, {
      player_id: playerId,
      expected_revision: game.revision,
    });
  },
  nightAction(game, actorId, playerTargets = [], centerTargets = []) {
    return request('POST', `/games/${game.id}/night-actions`, {
      actor_id: actorId,
      player_targets: playerTargets,
      center_targets: centerTargets,
      expected_revision: game.revision,
    });
  },
  endDiscussion(game) {
    return request('POST', `/games/${game.id}/end-discussion`, {
      expected_revision: game.revision,
    });
  },
  vote(game, voterId, targetId) {
    return request('POST', `/games/${game.id}/votes`, {
      voter_id: voterId,
      target_id: targetId,
      expected_revision: game.revision,
    });
  },
  createRoom(playerName) {
    return request('POST', '/games/rooms', { player_name: playerName.trim() });
  },
  joinRoom(roomCode, playerName) {
    return request('POST', `/games/rooms/${roomCode.trim().toUpperCase()}/join`, {
      player_name: playerName.trim(),
    });
  },
  getRoom(roomCode) {
    return request('GET', `/games/rooms/${roomCode.toUpperCase()}`);
  },
  configureRoom(session, room, roles) {
    return request('PUT', `/games/rooms/${room.room_code}/roles`, {
      player_id: session.player_id,
      player_token: session.player_token,
      roles,
      expected_revision: room.revision,
    });
  },
  startRoom(session, room) {
    return request('POST', `/games/rooms/${room.room_code}/start`, {
      player_id: session.player_id,
      player_token: session.player_token,
      expected_revision: room.revision,
    });
  },
};

module.exports = { ApiError, games, request };
