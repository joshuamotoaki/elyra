import type { Match, CreateMatchRequest, JoinMatchRequest } from '../types/match';

/**
 * Match Service Interface
 *
 * Handles all match-related REST API operations.
 *
 * @remarks
 * This service manages match creation, listing, and joining.
 * Real-time game state is handled separately via WebSocket (SocketService).
 *
 * @example
 * ```typescript
 * // List available matches
 * const matches = await client.matches.listMatches();
 *
 * // Create a new match
 * const match = await client.matches.createMatch();
 *
 * // Join a match by code
 * const match = await client.matches.joinByCode({ code: 'ABC123' });
 * ```
 */
export interface IMatchService {
	/**
	 * List all available matches (status = "waiting").
	 *
	 * @requires Authentication
	 *
	 * @returns Array of available matches
	 *
	 * @throws {ElyraAuthenticationError} If not authenticated
	 * @throws {ElyraNetworkError} If the request fails
	 *
	 * @example
	 * ```typescript
	 * const matches = await client.matches.listMatches();
	 * for (const match of matches) {
	 *   console.log(`${match.host.username}'s game - ${match.player_count} players`);
	 * }
	 * ```
	 */
	listMatches(): Promise<Match[]>;

	/**
	 * Create a new match.
	 *
	 * @requires Authentication
	 *
	 * @param request - Optional configuration for the match
	 * @returns The created match
	 *
	 * @throws {ElyraAuthenticationError} If not authenticated
	 * @throws {ElyraNetworkError} If the request fails
	 *
	 * @example
	 * ```typescript
	 * // Create with defaults (4x4 grid, 30 seconds, public)
	 * const match = await client.matches.createMatch();
	 *
	 * // Create a private match
	 * const match = await client.matches.createMatch({ is_public: false });
	 *
	 * // Create with custom settings
	 * const match = await client.matches.createMatch({
	 *   grid_size: 5,
	 *   duration_seconds: 60,
	 *   is_public: true
	 * });
	 * ```
	 */
	createMatch(request?: CreateMatchRequest): Promise<Match>;

	/**
	 * Get a match by ID.
	 *
	 * @requires Authentication
	 *
	 * @param id - The match ID
	 * @returns The match details
	 *
	 * @throws {ElyraAuthenticationError} If not authenticated
	 * @throws {ElyraNotFoundError} If the match doesn't exist
	 * @throws {ElyraNetworkError} If the request fails
	 *
	 * @example
	 * ```typescript
	 * const match = await client.matches.getMatch(123);
	 * console.log(`Match status: ${match.status}`);
	 * ```
	 */
	getMatch(id: number): Promise<Match>;

	/**
	 * Join a match by its code.
	 *
	 * @requires Authentication
	 *
	 * @param request - The join request containing the match code
	 * @returns The match that was joined
	 *
	 * @throws {ElyraAuthenticationError} If not authenticated
	 * @throws {ElyraNotFoundError} If the code is invalid
	 * @throws {ElyraNetworkError} If the request fails
	 *
	 * @example
	 * ```typescript
	 * const match = await client.matches.joinByCode({ code: 'ABC123' });
	 * console.log(`Joined match ${match.id}`);
	 * ```
	 */
	joinByCode(request: JoinMatchRequest): Promise<Match>;
}
