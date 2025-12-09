/**
 * Game types for the Elyra territory control game.
 */

// Tile types that make up the map
export type TileType = 'walkable' | 'hole' | 'wall' | 'mirror' | 'generator';

// Player state from the server
export interface PlayerState {
	user_id: number;
	username: string;
	picture: string | null;
	color: string;
	x: number;
	y: number;
	energy: number;
	max_energy: number;
	coins: number;
	glow_radius: number;
	speed_stacks: number;
	radius_stacks: number;
	energy_stacks: number;
	has_multishot: boolean;
	has_piercing: boolean;
	has_beam_speed: boolean;
}

// Active beam
export interface Beam {
	id: string;
	user_id: number;
	color: string;
	x: number;
	y: number;
	dir_x: number;
	dir_y: number;
}

// Coin drop
export interface CoinDrop {
	id: string;
	type: 'bronze' | 'silver' | 'gold';
	value: number;
	x: number;
	y: number;
	spawned: boolean;
}

// Full game state (sent on join)
export interface GameState {
	match_id: number;
	code: string;
	status: 'waiting' | 'playing' | 'finished';
	host_id: number;
	is_solo: boolean;
	grid_size: number;
	time_remaining_ms: number | null; // null for unlimited (solo mode)
	tick: number;
	server_timestamp: number;
	map_tiles: Record<string, string>; // "x,y" -> tile type
	tile_owners: Record<string, number | null>; // "x,y" -> user_id
	generators: string[]; // ["x,y", ...]
	spawn_points: string[]; // ["x,y", ...]
	players: Record<number, PlayerState>;
	beams: Beam[];
	coin_drops: CoinDrop[];
}

// State delta (sent each tick)
export interface StateDelta {
	tick: number;
	server_timestamp: number;
	time_remaining_ms: number | null; // null for unlimited (solo mode)
	players: Record<number, Partial<PlayerState> & { x: number; y: number }>;
	beams?: Beam[];
	tiles?: Record<string, number | null>; // Changed tile owners: "x,y" -> user_id
}

// Input state (WASD)
export interface InputState {
	w: boolean;
	a: boolean;
	s: boolean;
	d: boolean;
}

// Power-up types
export type PowerUpType = 'speed' | 'radius' | 'energy' | 'multishot' | 'piercing' | 'beam_speed';

// Power-up costs
export const POWERUP_COSTS: Record<PowerUpType, number> = {
	speed: 15,
	radius: 20,
	energy: 20,
	multishot: 40,
	piercing: 35,
	beam_speed: 30
};

// Event payloads
export interface PlayerJoinedEvent extends PlayerState {}

export interface PlayerLeftEvent {
	user_id: number;
}

export interface GameStartedEvent {
	time_remaining_ms: number;
}

export interface BeamFiredEvent extends Beam {}

export interface BeamEndedEvent {
	id: string;
}

export interface CoinTelegraphEvent extends CoinDrop {}

export interface CoinSpawnedEvent extends CoinDrop {}

export interface CoinCollectedEvent {
	id: string;
	user_id: number;
}

export interface PowerUpPurchasedEvent {
	user_id: number;
	type: string;
}

export interface GameEndedEvent {
	winner_id: number | null;
	scores: Record<number, number>;
	players: Record<number, PlayerState>;
}

// Callbacks for socket events
export interface GameCallbacks {
	onPlayerJoined: (event: PlayerJoinedEvent) => void;
	onPlayerLeft: (event: PlayerLeftEvent) => void;
	onGameStarted: (event: GameStartedEvent) => void;
	onStateDelta: (event: StateDelta) => void;
	onBeamFired: (event: BeamFiredEvent) => void;
	onBeamEnded: (event: BeamEndedEvent) => void;
	onCoinTelegraph: (event: CoinTelegraphEvent) => void;
	onCoinSpawned: (event: CoinSpawnedEvent) => void;
	onCoinCollected: (event: CoinCollectedEvent) => void;
	onPowerUpPurchased: (event: PowerUpPurchasedEvent) => void;
	onGameEnded: (event: GameEndedEvent) => void;
}

// Helper to parse "x,y" string to coordinates
export function parseCoord(coord: string): { x: number; y: number } {
	const [x, y] = coord.split(',').map(Number);
	return { x, y };
}

// Helper to create "x,y" string from coordinates
export function toCoordKey(x: number, y: number): string {
	return `${x},${y}`;
}
