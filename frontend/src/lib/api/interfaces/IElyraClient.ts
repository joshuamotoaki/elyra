import type { IAuthService } from './IAuthService';
import type { IUserService } from './IUserService';
import type { IMatchService } from './IMatchService';

/**
 * Main Elyra Client Interface
 *
 * The primary entry point for all API interactions with the Elyra backend.
 * Provides access to domain-specific services through a clean, organized API.
 *
 * @remarks
 * The client is designed to be used as a singleton throughout your application.
 * It manages authentication state and provides consistent error handling
 * across all services.
 *
 * **Key Features:**
 * - Type-safe API calls with full TypeScript support
 * - Automatic token management
 * - Consistent error handling with typed exceptions
 * - Domain-organized services (auth, users, etc.)
 *
 * **Error Handling:**
 * All service methods throw typed exceptions:
 * - `ElyraAuthenticationError` - 401 Unauthorized
 * - `ElyraValidationError` - 422 Unprocessable Entity (with field errors)
 * - `ElyraNotFoundError` - 404 Not Found
 * - `ElyraRateLimitError` - 429 Too Many Requests
 * - `ElyraServerError` - 5xx Server Errors
 * - `ElyraNetworkError` - Network/timeout failures
 *
 * @example
 * ```typescript
 * import { elyraClient } from '$lib/api';
 *
 * // Access authentication service
 * const loginUrl = elyraClient.auth.getOAuthUrl('google');
 *
 * // Access user service
 * try {
 *   const user = await elyraClient.users.getCurrentUser();
 *   console.log(user.email);
 * } catch (e) {
 *   if (e instanceof ElyraAuthenticationError) {
 *     goto('/login');
 *   }
 * }
 * ```
 */
export interface IElyraClient {
	/**
	 * Authentication service for OAuth and session management.
	 *
	 * Use this service to initiate OAuth flows and manage authentication.
	 *
	 * @see IAuthService for available methods
	 *
	 * @example
	 * ```typescript
	 * // Get OAuth URL and redirect user
	 * const url = client.auth.getOAuthUrl('google');
	 * window.location.href = url;
	 *
	 * // Get list of supported providers
	 * const providers = client.auth.getSupportedProviders();
	 * // Returns: ['google']
	 * ```
	 */
	readonly auth: IAuthService;

	/**
	 * User service for profile and account management.
	 *
	 * Use this service to get user profiles, update usernames,
	 * and check username availability.
	 *
	 * @see IUserService for available methods
	 *
	 * @example
	 * ```typescript
	 * // Get current user profile
	 * const user = await client.users.getCurrentUser();
	 *
	 * // Update username
	 * await client.users.updateUsername({ username: 'newname' });
	 *
	 * // Check if a username is available
	 * const { available } = await client.users.checkUsernameAvailability('testuser');
	 * ```
	 */
	readonly users: IUserService;

	/**
	 * Match service for game creation and management.
	 *
	 * Use this service to list, create, and join matches.
	 * Real-time game state is handled via WebSocket (see SocketService).
	 *
	 * @see IMatchService for available methods
	 *
	 * @example
	 * ```typescript
	 * // List available matches
	 * const matches = await client.matches.listMatches();
	 *
	 * // Create a new match
	 * const match = await client.matches.createMatch();
	 *
	 * // Join by code
	 * const match = await client.matches.joinByCode({ code: 'ABC123' });
	 * ```
	 */
	readonly matches: IMatchService;

	/**
	 * Set the authentication token for subsequent requests.
	 *
	 * @param token - The JWT token to use, or null to clear authentication
	 *
	 * @remarks
	 * This method is typically called:
	 * - After OAuth callback when you receive a token
	 * - When restoring a session from storage
	 * - With `null` when logging out
	 *
	 * @example
	 * ```typescript
	 * // After OAuth callback
	 * const token = urlParams.get('token');
	 * if (token) {
	 *   client.setToken(token);
	 *   localStorage.setItem('auth_token', token);
	 * }
	 *
	 * // To log out
	 * client.setToken(null);
	 * localStorage.removeItem('auth_token');
	 * ```
	 */
	setToken(token: string | null): void;

	/**
	 * Get the current authentication token.
	 *
	 * @returns The current JWT token, or null if not authenticated
	 *
	 * @example
	 * ```typescript
	 * const token = client.getToken();
	 * if (token) {
	 *   console.log('User has a token set');
	 * }
	 * ```
	 */
	getToken(): string | null;

	/**
	 * Check if the client currently has an authentication token.
	 *
	 * @returns True if a token is currently set
	 *
	 * @remarks
	 * Note: This only checks if a token exists, not if it's valid or expired.
	 * To verify the token is still valid, call `users.getCurrentUser()` which
	 * will throw `ElyraAuthenticationError` if the token is invalid.
	 *
	 * @example
	 * ```typescript
	 * if (client.hasToken()) {
	 *   // Attempt to load user - token might still be invalid
	 *   try {
	 *     const user = await client.users.getCurrentUser();
	 *   } catch (e) {
	 *     if (e instanceof ElyraAuthenticationError) {
	 *       // Token was invalid, redirect to login
	 *       client.setToken(null);
	 *       goto('/');
	 *     }
	 *   }
	 * } else {
	 *   // No token, redirect to login
	 *   goto('/');
	 * }
	 * ```
	 */
	hasToken(): boolean;
}
