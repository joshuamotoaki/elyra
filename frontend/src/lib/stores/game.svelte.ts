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

// Collision constants - must match backend
const PLAYER_RADIUS = 0.4;

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
	 * Check if a circle at (cx, cy) with given radius intersects a tile at (tileX, tileY)
	 * Tiles are CENTERED at their integer coordinates (Three.js BoxGeometry is centered)
	 */
	private circleIntersectsTile(
		cx: number,
		cy: number,
		radius: number,
		tileX: number,
		tileY: number
	): boolean {
		// Tile spans from tileX - 0.5 to tileX + 0.5 (centered on integer coordinate)
		const tileMinX = tileX - 0.5;
		const tileMaxX = tileX + 0.5;
		const tileMinY = tileY - 0.5;
		const tileMaxY = tileY + 0.5;

		// Find closest point on tile to circle center
		const closestX = Math.max(tileMinX, Math.min(cx, tileMaxX));
		const closestY = Math.max(tileMinY, Math.min(cy, tileMaxY));

		// Check distance from circle center to closest point
		const distX = cx - closestX;
		const distY = cy - closestY;
		const distanceSq = distX * distX + distY * distY;

		return distanceSq <= radius * radius;
	}

	/**
	 * Check if a position is blocked by walls/obstacles
	 */
	private isPositionBlocked(x: number, y: number): boolean {
		// Get bounding box of tiles the player could touch
		// Expand by 1 to account for centered tile coordinates (tiles span n-0.5 to n+0.5)
		const minTileX = Math.floor(x - PLAYER_RADIUS) - 1;
		const maxTileX = Math.floor(x + PLAYER_RADIUS) + 1;
		const minTileY = Math.floor(y - PLAYER_RADIUS) - 1;
		const maxTileY = Math.floor(y + PLAYER_RADIUS) + 1;

		for (let tx = minTileX; tx <= maxTileX; tx++) {
			for (let ty = minTileY; ty <= maxTileY; ty++) {
				const tileType = this.mapTiles.get(`${tx},${ty}`);

				const isBlocking =
					!tileType ||
					tileType === 'wall' ||
					tileType === 'mirror_ne' ||
					tileType === 'mirror_nw' ||
					tileType === 'hole';

				if (isBlocking && this.circleIntersectsTile(x, y, PLAYER_RADIUS, tx, ty)) {
					return true;
				}
			}
		}
		return false;
	}

	/**
	 * Update local visual position based on input (immediate feedback)
	 * Uses predictive collision to prevent walking through walls
	 */
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

		// Calculate speed with upgrades
		const speedMultiplier = 1 + (player.speed_stacks ?? 0) * 0.15;
		const speed = 5 * speedMultiplier;

		const moveX = dx * speed * dt;
		const moveY = dy * speed * dt;

		// Predictive collision - try X movement
		const proposedX = this.localVisualX + moveX;
		if (!this.isPositionBlocked(proposedX, this.localVisualY)) {
			this.localVisualX = proposedX;
		}

		// Predictive collision - try Y movement (using new X position)
		const proposedY = this.localVisualY + moveY;
		if (!this.isPositionBlocked(this.localVisualX, proposedY)) {
			this.localVisualY = proposedY;
		}

		// Clamp to grid bounds (accounting for player radius)
		this.localVisualX = Math.max(
			PLAYER_RADIUS,
			Math.min(this.localVisualX, this.gridSize - 1 - PLAYER_RADIUS)
		);
		this.localVisualY = Math.max(
			PLAYER_RADIUS,
			Math.min(this.localVisualY, this.gridSize - 1 - PLAYER_RADIUS)
		);
	}

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
