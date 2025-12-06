/**
 * Game store for the Elyra territory control game.
 * Manages all real-time game state including map, players, beams, and coins.
 */

import type {
	TileType,
	PlayerState,
	Beam,
	CoinDrop,
	GameState,
	StateDelta,
	InputState,
	PowerUpType
} from '$lib/api/types/game';
import { parseCoord } from '$lib/api/types/game';

// Snapshot for interpolation
interface PlayerSnapshot {
	x: number;
	y: number;
	timestamp: number;
}

class GameStore {
	// Connection state
	matchId = $state<number | null>(null);
	code = $state<string>('');
	status = $state<'waiting' | 'playing' | 'finished'>('waiting');
	hostId = $state<number | null>(null);
	isSolo = $state(false);
	isConnecting = $state(false);
	error = $state<string | null>(null);

	// Map data (static after game starts)
	gridSize = $state(100);
	mapTiles = $state<Map<string, TileType>>(new Map());
	generators = $state<Array<{ x: number; y: number }>>([]);
	spawnPoints = $state<Array<{ x: number; y: number }>>([]);

	// Dynamic game state
	tileOwners = $state<Map<string, number | null>>(new Map());
	players = $state<Map<number, PlayerState>>(new Map());
	beams = $state<Beam[]>([]);
	coinDrops = $state<CoinDrop[]>([]);

	// Timing
	tick = $state(0);
	serverTimestamp = $state(0);
	timeRemainingMs = $state<number | null>(120000);

	// Local player
	localPlayerId = $state<number | null>(null);

	// Interpolation buffers for remote players
	private playerSnapshots = new Map<number, PlayerSnapshot[]>();
	private readonly INTERPOLATION_DELAY = 100; // ms behind real-time
	private readonly MAX_SNAPSHOTS = 10;

	// Local player visual position (for responsive input)
	localVisualX = $state(0);
	localVisualY = $state(0);

	// Current input state
	currentInput = $state<InputState>({ w: false, a: false, s: false, d: false });

	// Final results
	winnerId = $state<number | null>(null);
	finalScores = $state<Record<number, number>>({});
	finalPlayers = $state<Map<number, PlayerState>>(new Map());

	// Derived state
	get localPlayer(): PlayerState | undefined {
		if (this.localPlayerId === null) return undefined;
		return this.players.get(this.localPlayerId);
	}

	get playerList(): PlayerState[] {
		return Array.from(this.players.values());
	}

	get timeRemainingSeconds(): number {
		if (this.timeRemainingMs === null) return Infinity;
		return Math.ceil(this.timeRemainingMs / 1000);
	}

	get formattedTime(): string {
		if (this.timeRemainingMs === null) {
			return '--:--'; // Unlimited time for solo mode
		}
		const seconds = this.timeRemainingSeconds;
		const mins = Math.floor(seconds / 60);
		const secs = seconds % 60;
		return `${mins}:${secs.toString().padStart(2, '0')}`;
	}

	/**
	 * Initialize store from full game state (on join)
	 */
	initializeFromState(state: GameState, localUserId: number) {
		this.matchId = state.match_id;
		this.code = state.code;
		this.status = state.status;
		this.hostId = state.host_id;
		this.isSolo = state.is_solo ?? false;
		this.gridSize = state.grid_size;
		this.timeRemainingMs = state.time_remaining_ms;
		this.tick = state.tick;
		this.serverTimestamp = state.server_timestamp;
		this.localPlayerId = localUserId;

		// Parse map tiles
		this.mapTiles = new Map();
		for (const [key, type] of Object.entries(state.map_tiles)) {
			this.mapTiles.set(key, type as TileType);
		}

		// Parse tile owners
		this.tileOwners = new Map();
		for (const [key, owner] of Object.entries(state.tile_owners)) {
			this.tileOwners.set(key, owner);
		}

		// Parse generators and spawn points
		this.generators = state.generators.map(parseCoord);
		this.spawnPoints = state.spawn_points.map(parseCoord);

		// Parse players
		this.players = new Map();
		for (const [id, player] of Object.entries(state.players)) {
			this.players.set(Number(id), player);
		}

		// Initialize local visual position
		const local = this.localPlayer;
		if (local) {
			this.localVisualX = local.x;
			this.localVisualY = local.y;
		}

		// Initialize beams and coins
		this.beams = state.beams;
		this.coinDrops = state.coin_drops;

		this.isConnecting = false;
		this.error = null;
	}

	/**
	 * Apply state delta from server tick
	 */
	applyDelta(delta: StateDelta) {
		this.tick = delta.tick;
		this.serverTimestamp = delta.server_timestamp;
		this.timeRemainingMs = delta.time_remaining_ms;

		// Update players and store snapshots for interpolation
		const newPlayers = new Map(this.players);
		let hasChanges = false;

		for (const [id, playerData] of Object.entries(delta.players)) {
			const userId = Number(id);
			const existing = newPlayers.get(userId);

			if (existing) {
				// Store snapshot for interpolation (remote players only)
				if (userId !== this.localPlayerId) {
					this.addPlayerSnapshot(userId, playerData.x, playerData.y, delta.server_timestamp);
				}

				// Update player state (merge with existing)
				newPlayers.set(userId, { ...existing, ...playerData });
				hasChanges = true;
			}
			// Note: If player doesn't exist, they should have joined via player_joined event
			// We don't create new players from delta since it only has partial data
		}

		if (hasChanges) {
			this.players = newPlayers;
		}

		// Reconcile local player position
		if (this.localPlayerId !== null) {
			const serverPlayer = delta.players[this.localPlayerId];
			if (serverPlayer) {
				// Smooth reconciliation: lerp towards server position
				const lerpFactor = 0.1;
				this.localVisualX += (serverPlayer.x - this.localVisualX) * lerpFactor;
				this.localVisualY += (serverPlayer.y - this.localVisualY) * lerpFactor;
			}
		}

		// Update beams
		this.beams = delta.beams || [];

		// Update changed tile owners
		if (delta.tiles && Object.keys(delta.tiles).length > 0) {
			const newTileOwners = new Map(this.tileOwners);
			for (const [key, owner] of Object.entries(delta.tiles)) {
				newTileOwners.set(key, owner);
			}
			this.tileOwners = newTileOwners;
		}
	}

	/**
	 * Add snapshot for player interpolation
	 */
	private addPlayerSnapshot(userId: number, x: number, y: number, timestamp: number) {
		let snapshots = this.playerSnapshots.get(userId);
		if (!snapshots) {
			snapshots = [];
			this.playerSnapshots.set(userId, snapshots);
		}

		snapshots.push({ x, y, timestamp });

		// Keep only recent snapshots
		if (snapshots.length > this.MAX_SNAPSHOTS) {
			snapshots.shift();
		}
	}

	/**
	 * Get interpolated position for a remote player
	 */
	getInterpolatedPosition(userId: number): { x: number; y: number } | null {
		const player = this.players.get(userId);
		if (!player) return null;

		// Local player uses visual position
		if (userId === this.localPlayerId) {
			return { x: this.localVisualX, y: this.localVisualY };
		}

		const snapshots = this.playerSnapshots.get(userId);
		if (!snapshots || snapshots.length < 2) {
			return { x: player.x, y: player.y };
		}

		// Render 100ms in the past
		const renderTime = Date.now() - this.INTERPOLATION_DELAY;

		// Find surrounding snapshots
		let before: PlayerSnapshot | null = null;
		let after: PlayerSnapshot | null = null;

		for (let i = 0; i < snapshots.length - 1; i++) {
			if (snapshots[i].timestamp <= renderTime && snapshots[i + 1].timestamp >= renderTime) {
				before = snapshots[i];
				after = snapshots[i + 1];
				break;
			}
		}

		if (!before || !after) {
			// Use latest position if no interpolation possible
			return { x: player.x, y: player.y };
		}

		// Interpolate between snapshots
		const t = (renderTime - before.timestamp) / (after.timestamp - before.timestamp);
		return {
			x: before.x + (after.x - before.x) * t,
			y: before.y + (after.y - before.y) * t
		};
	}

	/**
	 * Update local visual position based on input (immediate feedback)
	 */

	// Maya
	updateLocalVisualPosition(dt: number) {
		const player = this.localPlayer;
		if (!player) return;

		const input = this.currentInput;
		let dx = 0;
		let dy = 0;

		if (input.d && !input.a) dx = 1;
		else if (input.a && !input.d) dx = -1;

		if (input.s && !input.w) dy = 1;
		else if (input.w && !input.s) dy = -1;

		// Normalize diagonal
		if (dx !== 0 && dy !== 0) {
			const mag = Math.sqrt(2);
			dx /= mag;
			dy /= mag;
		}

		const speed = player.glow_radius > 1.5 ? 5 * 1.15 : 5;
		const stepX = dx * speed * dt;
		const stepY = dy * speed * dt;

		const proposedX = this.localVisualX + stepX;
		const proposedY = this.localVisualY + stepY;

		// Try X axis first
		if (this.canMoveTo(proposedX, this.localVisualY)) {
			this.localVisualX = proposedX;
		}

		// Then Y axis
		if (this.canMoveTo(this.localVisualX, proposedY)) {
			this.localVisualY = proposedY;
		}

		// Clamp to grid (same as before)
		this.localVisualX = Math.max(0, Math.min(this.localVisualX, this.gridSize - 1));
		this.localVisualY = Math.max(0, Math.min(this.localVisualY, this.gridSize - 1));
	}

	// updateLocalVisualPosition(dt: number) {
	// 	const player = this.localPlayer;
	// 	if (!player) return;

	// 	const input = this.currentInput;
	// 	let dx = 0;
	// 	let dy = 0;

	// 	if (input.d && !input.a) dx = 1;
	// 	else if (input.a && !input.d) dx = -1;

	// 	if (input.s && !input.w) dy = 1;
	// 	else if (input.w && !input.s) dy = -1;

	// 	// Normalize diagonal
	// 	if (dx !== 0 && dy !== 0) {
	// 		const mag = Math.sqrt(2);
	// 		dx /= mag;
	// 		dy /= mag;
	// 	}

	// 	const speed = player.glow_radius > 1.5 ? 5 * 1.15 : 5; // Approximate speed with upgrades
	// 	this.localVisualX += dx * speed * dt;
	// 	this.localVisualY += dy * speed * dt;

	// 	// Clamp to grid
	// 	this.localVisualX = Math.max(0, Math.min(this.localVisualX, this.gridSize - 1));
	// 	this.localVisualY = Math.max(0, Math.min(this.localVisualY, this.gridSize - 1));
	// }

	/**
	 * Set current input state
	 */
	setInput(input: InputState) {
		this.currentInput = input;
	}

	/**
	 * Handle player joined event
	 */
	handlePlayerJoined(player: PlayerState) {
		// Create new Map to ensure reactivity
		const newPlayers = new Map(this.players);
		newPlayers.set(player.user_id, player);
		this.players = newPlayers;
	}

	/**
	 * Handle player left event
	 */
	handlePlayerLeft(userId: number) {
		// Create new Map to ensure reactivity
		const newPlayers = new Map(this.players);
		newPlayers.delete(userId);
		this.players = newPlayers;
		this.playerSnapshots.delete(userId);
	}

	/**
	 * Handle game started event
	 */
	handleGameStarted(timeRemainingMs: number) {
		this.status = 'playing';
		this.timeRemainingMs = timeRemainingMs;
	}

	/**
	 * Handle beam fired event - just for visual effects
	 * Note: Actual beam state comes from state_delta
	 */
	handleBeamFired(_beam: Beam) {
		// Beams are managed via state_delta to avoid duplicates
		// This callback can be used for sound/visual effects
	}

	/**
	 * Handle beam ended event - just for visual effects
	 * Note: Actual beam state comes from state_delta
	 */
	handleBeamEnded(_beamId: string) {
		// Beams are managed via state_delta to avoid duplicates
		// This callback can be used for sound/visual effects
	}

	/**
	 * Handle coin telegraph event
	 */
	handleCoinTelegraph(coin: CoinDrop) {
		this.coinDrops = [...this.coinDrops, coin];
	}

	/**
	 * Handle coin spawned event
	 */
	handleCoinSpawned(coin: CoinDrop) {
		this.coinDrops = this.coinDrops.map((c) => (c.id === coin.id ? { ...c, spawned: true } : c));
	}

	/**
	 * Handle coin collected event
	 */
	handleCoinCollected(coinId: string) {
		this.coinDrops = this.coinDrops.filter((c) => c.id !== coinId);
	}

	/**
	 * Handle power-up purchased event
	 */
	handlePowerUpPurchased(userId: number, type: string) {
		// State will be updated via next delta
		console.log(`Player ${userId} purchased ${type}`);
	}

	/**
	 * Handle game ended event
	 */
	handleGameEnded(
		winnerId: number | null,
		scores: Record<number, number>,
		players: Record<number, PlayerState>
	) {
		this.status = 'finished';
		this.winnerId = winnerId;
		this.finalScores = scores;
		this.finalPlayers = new Map(Object.entries(players).map(([id, p]) => [Number(id), p]));
	}

	// Maya pr
	canMoveTo(x: number, y: number): boolean {
		// Match server: trunc(new_x) / trunc(new_y)
		const tileX = Math.trunc(x);
		const tileY = Math.trunc(y);

		// Bounds check
		if (tileX < 0 || tileX >= this.gridSize || tileY < 0 || tileY >= this.gridSize) {
			return false;
		}

		const tile = this.getTileType(tileX, tileY);

		// No tile? Treat as blocked
		if (!tile) return false;

		// Match backend rule exactly:
		// allowed: :walkable, :generator, :mirror_ne, :mirror_nw
		return (
			tile === 'walkable' || tile === 'generator' || tile === 'mirror_ne' || tile === 'mirror_nw'
		);
	}

	/**
	 * Get tile type at coordinates
	 */
	getTileType(x: number, y: number): TileType | undefined {
		return this.mapTiles.get(`${x},${y}`);
	}

	/**
	 * Get tile owner at coordinates
	 */
	getTileOwner(x: number, y: number): number | null | undefined {
		return this.tileOwners.get(`${x},${y}`);
	}

	/**
	 * Get player color by ID
	 */
	getPlayerColor(userId: number): string | undefined {
		return this.players.get(userId)?.color;
	}

	/**
	 * Calculate territory percentage for a player
	 */
	getTerritoryPercentage(userId: number): number {
		let owned = 0;
		let total = 0;

		for (const owner of this.tileOwners.values()) {
			total++;
			if (owner === userId) owned++;
		}

		return total > 0 ? (owned / total) * 100 : 0;
	}

	/**
	 * Reset store state
	 */
	reset() {
		this.matchId = null;
		this.code = '';
		this.status = 'waiting';
		this.hostId = null;
		this.isSolo = false;
		this.isConnecting = false;
		this.error = null;
		this.gridSize = 100;
		this.mapTiles = new Map();
		this.tileOwners = new Map();
		this.generators = [];
		this.spawnPoints = [];
		this.players = new Map();
		this.beams = [];
		this.coinDrops = [];
		this.tick = 0;
		this.serverTimestamp = 0;
		this.timeRemainingMs = 120000;
		this.localPlayerId = null;
		this.playerSnapshots.clear();
		this.localVisualX = 0;
		this.localVisualY = 0;
		this.currentInput = { w: false, a: false, s: false, d: false };
		this.winnerId = null;
		this.finalScores = {};
		this.finalPlayers = new Map();
	}
}

export const gameStore = new GameStore();
