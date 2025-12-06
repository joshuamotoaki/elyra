import { Socket, Channel } from 'phoenix';
import type {
	MatchState,
	MatchCallbacks,
	PlayerJoinedEvent,
	PlayerLeftEvent,
	GameStartedEvent,
	CellClaimedEvent,
	TickEvent,
	GameEndedEvent
} from '../types/match';
import type {
	GameState,
	GameCallbacks,
	InputState,
	PowerUpType,
	StateDelta,
	PlayerJoinedEvent as GamePlayerJoinedEvent,
	PlayerLeftEvent as GamePlayerLeftEvent,
	GameStartedEvent as GameGameStartedEvent,
	GameEndedEvent as GameGameEndedEvent,
	BeamFiredEvent,
	BeamEndedEvent,
	CoinTelegraphEvent,
	CoinSpawnedEvent,
	CoinCollectedEvent,
	PowerUpPurchasedEvent
} from '../types/game';
import type { ISocketService } from '../interfaces/ISocketService';

interface ErrorResponse {
	reason?: string;
}

/**
 * Service for WebSocket communication with the game server.
 */
export class SocketService implements ISocketService {
	private socket: Socket | null = null;
	private matchChannel: Channel | null = null;

	/**
	 * Connect to the WebSocket server.
	 */
	connect(token: string): void {
		if (this.socket?.isConnected()) {
			return;
		}

		this.socket = new Socket('ws://localhost:4000/socket', {
			params: { token }
		});
		this.socket.connect();
	}

	/**
	 * Disconnect from the WebSocket server.
	 */
	disconnect(): void {
		this.leaveMatch();
		this.socket?.disconnect();
		this.socket = null;
	}

	/**
	 * Check if the socket is connected.
	 */
	isConnected(): boolean {
		return this.socket?.isConnected() ?? false;
	}

	/**
	 * Join a match channel (legacy - for old cell-clicking game).
	 */
	joinMatch(matchId: number, callbacks: MatchCallbacks): Promise<MatchState> {
		return new Promise((resolve, reject) => {
			if (!this.socket) {
				reject(new Error('Socket not connected'));
				return;
			}

			this.leaveMatch();
			this.matchChannel = this.socket.channel(`match:${matchId}`);

			this.matchChannel.on('player_joined', (payload: unknown) =>
				callbacks.onPlayerJoined(payload as PlayerJoinedEvent)
			);
			this.matchChannel.on('player_left', (payload: unknown) =>
				callbacks.onPlayerLeft(payload as PlayerLeftEvent)
			);
			this.matchChannel.on('game_started', (payload: unknown) =>
				callbacks.onGameStarted(payload as GameStartedEvent)
			);
			this.matchChannel.on('cell_claimed', (payload: unknown) =>
				callbacks.onCellClaimed(payload as CellClaimedEvent)
			);
			this.matchChannel.on('tick', (payload: unknown) => callbacks.onTick(payload as TickEvent));
			this.matchChannel.on('game_ended', (payload: unknown) =>
				callbacks.onGameEnded(payload as GameEndedEvent)
			);

			this.matchChannel
				.join()
				.receive('ok', (state: unknown) => resolve(state as MatchState))
				.receive('error', (reason: unknown) => {
					const err = reason as ErrorResponse;
					reject(new Error(err.reason || 'Failed to join match'));
				});
		});
	}

	/**
	 * Join a match channel for the new 3D game.
	 */
	joinGame(matchId: number, callbacks: GameCallbacks): Promise<GameState> {
		return new Promise((resolve, reject) => {
			if (!this.socket) {
				reject(new Error('Socket not connected'));
				return;
			}

			this.leaveMatch();
			this.matchChannel = this.socket.channel(`match:${matchId}`);

			// Player events
			this.matchChannel.on('player_joined', (payload: unknown) =>
				callbacks.onPlayerJoined(payload as GamePlayerJoinedEvent)
			);
			this.matchChannel.on('player_left', (payload: unknown) =>
				callbacks.onPlayerLeft(payload as GamePlayerLeftEvent)
			);
			this.matchChannel.on('game_started', (payload: unknown) => {
				const event = payload as { time_remaining_ms: number };
				callbacks.onGameStarted({ time_remaining_ms: event.time_remaining_ms });
			});
			this.matchChannel.on('game_ended', (payload: unknown) =>
				callbacks.onGameEnded(payload as GameGameEndedEvent)
			);

			// State updates
			this.matchChannel.on('state_delta', (payload: unknown) =>
				callbacks.onStateDelta(payload as StateDelta)
			);

			// Beam events
			this.matchChannel.on('beam_fired', (payload: unknown) =>
				callbacks.onBeamFired(payload as BeamFiredEvent)
			);
			this.matchChannel.on('beam_ended', (payload: unknown) =>
				callbacks.onBeamEnded(payload as BeamEndedEvent)
			);

			// Coin events
			this.matchChannel.on('coin_telegraph', (payload: unknown) =>
				callbacks.onCoinTelegraph(payload as CoinTelegraphEvent)
			);
			this.matchChannel.on('coin_spawned', (payload: unknown) =>
				callbacks.onCoinSpawned(payload as CoinSpawnedEvent)
			);
			this.matchChannel.on('coin_collected', (payload: unknown) =>
				callbacks.onCoinCollected(payload as CoinCollectedEvent)
			);

			// Power-up events
			this.matchChannel.on('powerup_purchased', (payload: unknown) =>
				callbacks.onPowerUpPurchased(payload as PowerUpPurchasedEvent)
			);

			this.matchChannel
				.join()
				.receive('ok', (state: unknown) => resolve(state as GameState))
				.receive('error', (reason: unknown) => {
					const err = reason as ErrorResponse;
					reject(new Error(err.reason || 'Failed to join match'));
				});
		});
	}

	/**
	 * Start the game. Only the host can do this.
	 */
	startGame(): Promise<void> {
		return this.push('start_game', {});
	}

	/**
	 * Send player input (WASD state).
	 * This is called when input state changes, not every frame.
	 */
	sendInput(input: InputState): void {
		if (!this.matchChannel) return;
		// Use push without waiting for response for lower latency
		this.matchChannel.push('input', input);
	}

	/**
	 * Fire a beam in a direction.
	 */
	shoot(directionX: number, directionY: number): void {
		if (!this.matchChannel) return;
		this.matchChannel.push('shoot', {
			direction_x: directionX,
			direction_y: directionY
		});
	}

	/**
	 * Purchase a power-up.
	 */
	buyPowerUp(type: PowerUpType): Promise<void> {
		return this.push('buy_powerup', { type });
	}

	/**
	 * Click a cell to claim it (legacy).
	 */
	clickCell(row: number, col: number): Promise<void> {
		return this.push('click_cell', { row, col });
	}

	/**
	 * Leave the current match channel.
	 */
	leaveMatch(): void {
		this.matchChannel?.leave();
		this.matchChannel = null;
	}

	private push(event: string, payload: object): Promise<void> {
		return new Promise((resolve, reject) => {
			if (!this.matchChannel) {
				reject(new Error('Not in a match'));
				return;
			}

			this.matchChannel
				.push(event, payload)
				.receive('ok', () => resolve())
				.receive('error', (reason: unknown) => {
					const err = reason as ErrorResponse;
					reject(new Error(err.reason || `Failed: ${event}`));
				});
		});
	}
}

// Singleton instance
export const socketService = new SocketService();
