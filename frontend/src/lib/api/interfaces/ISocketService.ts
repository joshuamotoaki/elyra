import type { GameCallbacks, GameState, InputState, PowerUpType } from '../types/game';

/**
 * Socket Service Interface
 *
 * Handles real-time WebSocket communication with the game server via Phoenix Channels.
 *
 * @remarks
 * This service manages the WebSocket connection and provides methods for:
 * - Connecting/disconnecting from the server
 * - Joining match channels for real-time game state
 * - Sending player inputs (movement, shooting, power-ups)
 *
 * The service uses Phoenix Channels for efficient bidirectional communication.
 * Game state updates are received via callbacks registered when joining a match.
 *
 * @example
 * ```typescript
 * // Connect to the server
 * socketService.connect(authToken);
 *
 * // Join a game with callbacks
 * const state = await socketService.joinGame(matchId, {
 *   onPlayerJoined: (player) => console.log('Player joined:', player),
 *   onStateDelta: (delta) => gameStore.applyDelta(delta),
 *   // ... other callbacks
 * });
 *
 * // Send movement input
 * socketService.sendInput({ w: true, a: false, s: false, d: false });
 *
 * // Fire a beam
 * socketService.shoot(0.707, 0.707);
 * ```
 */
export interface ISocketService {
	/**
	 * Connect to the WebSocket server.
	 *
	 * @param token - JWT authentication token
	 *
	 * @remarks
	 * If already connected, this method does nothing.
	 * The token is used for authentication on the server side.
	 *
	 * @example
	 * ```typescript
	 * socketService.connect(auth.token);
	 * ```
	 */
	connect(token: string): void;

	/**
	 * Disconnect from the WebSocket server.
	 *
	 * @remarks
	 * This will also leave any active match channel.
	 *
	 * @example
	 * ```typescript
	 * socketService.disconnect();
	 * ```
	 */
	disconnect(): void;

	/**
	 * Check if the socket is currently connected.
	 *
	 * @returns True if connected to the WebSocket server
	 *
	 * @example
	 * ```typescript
	 * if (socketService.isConnected()) {
	 *   console.log('Socket is connected');
	 * }
	 * ```
	 */
	isConnected(): boolean;

	/**
	 * Join a match channel for the 3D territory control game.
	 *
	 * @param matchId - The match ID to join
	 * @param callbacks - Event handlers for game events
	 * @returns The full initial game state including map, players, and game settings
	 *
	 * @throws {Error} If socket is not connected
	 * @throws {Error} If joining the channel fails
	 *
	 * @remarks
	 * This subscribes to all game events including:
	 * - Player events (join, leave)
	 * - Game lifecycle events (started, ended)
	 * - State updates (state_delta)
	 * - Combat events (beam_fired, beam_ended)
	 * - Economy events (coin_telegraph, coin_spawned, coin_collected)
	 * - Power-up events (powerup_purchased)
	 *
	 * @example
	 * ```typescript
	 * const state = await socketService.joinGame(matchId, {
	 *   onPlayerJoined: (player) => gameStore.handlePlayerJoined(player),
	 *   onStateDelta: (delta) => gameStore.applyDelta(delta),
	 *   onBeamFired: (beam) => gameStore.handleBeamFired(beam),
	 *   onGameEnded: (event) => gameStore.handleGameEnded(event),
	 *   // ... other callbacks
	 * });
	 * ```
	 */
	joinGame(matchId: number, callbacks: GameCallbacks): Promise<GameState>;

	/**
	 * Start the game. Only the host can do this.
	 *
	 * @returns Promise that resolves when the game starts
	 *
	 * @throws {Error} If not in a match
	 * @throws {Error} If not the host
	 * @throws {Error} If not enough players
	 *
	 * @example
	 * ```typescript
	 * if (isHost) {
	 *   await socketService.startGame();
	 * }
	 * ```
	 */
	startGame(): Promise<void>;

	/**
	 * Send player input (WASD movement state).
	 *
	 * @param input - The current key states for WASD
	 *
	 * @remarks
	 * This should be called when input state changes, not every frame.
	 * The server will use this input to update the player's position.
	 * This uses fire-and-forget semantics for lower latency.
	 *
	 * @example
	 * ```typescript
	 * // Player starts moving forward
	 * socketService.sendInput({ w: true, a: false, s: false, d: false });
	 *
	 * // Player stops
	 * socketService.sendInput({ w: false, a: false, s: false, d: false });
	 *
	 * // Diagonal movement
	 * socketService.sendInput({ w: true, a: true, s: false, d: false });
	 * ```
	 */
	sendInput(input: InputState): void;

	/**
	 * Fire a beam in a direction.
	 *
	 * @param directionX - X component of the normalized direction vector
	 * @param directionY - Y component of the normalized direction vector (maps to Z in 3D)
	 *
	 * @remarks
	 * The direction should be normalized. The beam will capture tiles along its path.
	 * Beam physics (reflections, range, piercing) are handled server-side.
	 * This uses fire-and-forget semantics for lower latency.
	 *
	 * @example
	 * ```typescript
	 * // Shoot to the right
	 * socketService.shoot(1, 0);
	 *
	 * // Shoot diagonally (normalized)
	 * socketService.shoot(0.707, 0.707);
	 *
	 * // Shoot towards mouse cursor (calculated via raycasting)
	 * const dir = calculateDirectionToMouse();
	 * socketService.shoot(dir.x, dir.y);
	 * ```
	 */
	shoot(directionX: number, directionY: number): void;

	/**
	 * Purchase a power-up.
	 *
	 * @param type - The type of power-up to purchase
	 * @returns Promise that resolves when purchase is confirmed
	 *
	 * @throws {Error} If not in a match
	 * @throws {Error} If insufficient coins
	 * @throws {Error} If already have the power-up (for one-time purchases)
	 *
	 * @remarks
	 * Power-up costs:
	 * - speed: 15 coins (stackable, +15% speed)
	 * - radius: 20 coins (stackable, +20% glow radius)
	 * - energy: 20 coins (stackable, +20 max energy)
	 * - multishot: 40 coins (one-time, fires 3 beams)
	 * - piercing: 35 coins (one-time, beams pass through walls once)
	 * - beam_speed: 30 coins (one-time, 2x beam speed)
	 *
	 * @example
	 * ```typescript
	 * // Buy a speed upgrade
	 * await socketService.buyPowerUp('speed');
	 *
	 * // Buy multishot
	 * await socketService.buyPowerUp('multishot');
	 * ```
	 */
	buyPowerUp(type: PowerUpType): Promise<void>;

	/**
	 * Leave the current match channel.
	 *
	 * @remarks
	 * This removes all event listeners and leaves the Phoenix channel.
	 * Call this when navigating away from the match page.
	 *
	 * @example
	 * ```typescript
	 * onDestroy(() => {
	 *   socketService.leaveMatch();
	 * });
	 * ```
	 */
	leaveMatch(): void;
}
