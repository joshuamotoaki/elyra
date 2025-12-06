/**
 * Represents a match in the Elyra system.
 */
export interface Match {
	id: number;
	code: string;
	status: 'waiting' | 'playing' | 'finished';
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
 * Request to create a new match.
 */
export interface CreateMatchRequest {
	is_public?: boolean;
}

/**
 * Request to join a match by code.
 */
export interface JoinMatchRequest {
	code: string;
}
