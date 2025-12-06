/**
 * Represents a match in the Elyra system.
 */
export interface Match {
	id: number;
	code: string;
	status: 'waiting' | 'playing' | 'finished';
	grid_size: number;
	duration_seconds: number;
	is_public: boolean;
	host_id: number;
	host: {
		id: number;
		username: string | null;
		name: string | null;
		picture: string | null;
	};
	player_count: number;
	players: MatchPlayer[];
	winner_id: number | null;
	inserted_at: string;
	updated_at: string;
}

/**
 * Represents a player in a match.
 */
export interface MatchPlayer {
	user_id: number;
	username: string | null;
	picture: string | null;
	color: string;
	score: number;
}

/**
 * Live match state from the game server.
 */
export interface MatchState {
	match_id: number;
	code: string;
	status: 'waiting' | 'playing' | 'finished';
	grid_size: number;
	time_remaining: number;
	host_id: number;
	players: Record<number, MatchPlayer>;
	grid: Record<string, number | null>;
}

/**
 * Event when a player joins the match.
 */
export interface PlayerJoinedEvent {
	user_id: number;
	username: string;
	picture: string | null;
	color: string;
	score: number;
}

/**
 * Event when a player leaves the match.
 */
export interface PlayerLeftEvent {
	user_id: number;
}

/**
 * Event when the game starts.
 */
export interface GameStartedEvent {
	time_remaining: number;
}

/**
 * Event when a cell is claimed.
 */
export interface CellClaimedEvent {
	row: number;
	col: number;
	user_id: number;
	color: string;
}

/**
 * Event when the timer ticks.
 */
export interface TickEvent {
	time_remaining: number;
}

/**
 * Event when the game ends.
 */
export interface GameEndedEvent {
	winner_id: number;
	scores: Record<number, number>;
	final_grid: Record<string, number | null>;
	players: Record<number, MatchPlayer>;
}

/**
 * Callbacks for match channel events.
 */
export interface MatchCallbacks {
	onPlayerJoined: (event: PlayerJoinedEvent) => void;
	onPlayerLeft: (event: PlayerLeftEvent) => void;
	onGameStarted: (event: GameStartedEvent) => void;
	onCellClaimed: (event: CellClaimedEvent) => void;
	onTick: (event: TickEvent) => void;
	onGameEnded: (event: GameEndedEvent) => void;
}

/**
 * Request to create a new match.
 */
export interface CreateMatchRequest {
	grid_size?: number;
	duration_seconds?: number;
	is_public?: boolean;
}

/**
 * Request to join a match by code.
 */
export interface JoinMatchRequest {
	code: string;
}
