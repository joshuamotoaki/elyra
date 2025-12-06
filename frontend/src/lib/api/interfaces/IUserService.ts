import type { User, UpdateUsernameRequest, UsernameAvailabilityResponse } from '../types/user';

/**
 * User Service Interface
 *
 * Handles all user-related operations including profile management
 * and username operations.
 *
 * @remarks
 * All methods that require authentication will automatically include
 * the bearer token. If the token is invalid or expired, an
 * `ElyraAuthenticationError` will be thrown and the `onTokenInvalid`
 * callback will be invoked.
 *
 * @example
 * ```typescript
 * // Get current user's profile
 * try {
 *   const user = await client.users.getCurrentUser();
 *   console.log(`Welcome, ${user.name}!`);
 * } catch (e) {
 *   if (e instanceof ElyraAuthenticationError) {
 *     // Redirect to login
 *   }
 * }
 *
 * // Check if username is available and set it
 * const { available } = await client.users.checkUsernameAvailability('johndoe');
 * if (available) {
 *   await client.users.updateUsername({ username: 'johndoe' });
 * }
 * ```
 */
export interface IUserService {
	/**
	 * Get the currently authenticated user's profile.
	 *
	 * @requires Authentication - Bearer token must be set
	 *
	 * @returns The current user's profile
	 *
	 * @throws {ElyraAuthenticationError} If not authenticated or token is invalid
	 * @throws {ElyraNetworkError} If the request fails due to network issues
	 *
	 * @example
	 * ```typescript
	 * try {
	 *   const user = await client.users.getCurrentUser();
	 *   console.log(`Email: ${user.email}`);
	 *   console.log(`Username: ${user.username ?? 'Not set'}`);
	 *   console.log(`Admin: ${user.is_admin}`);
	 * } catch (e) {
	 *   if (e instanceof ElyraAuthenticationError) {
	 *     // Token expired or invalid, redirect to login
	 *     goto('/');
	 *   }
	 * }
	 * ```
	 */
	getCurrentUser(): Promise<User>;

	/**
	 * Update the current user's username.
	 *
	 * @requires Authentication - Bearer token must be set
	 *
	 * @param request - The update request containing the new username
	 * @returns The updated user profile
	 *
	 * @throws {ElyraAuthenticationError} If not authenticated or token is invalid
	 * @throws {ElyraValidationError} If the username is invalid or already taken
	 * @throws {ElyraNetworkError} If the request fails due to network issues
	 *
	 * @remarks
	 * Username requirements:
	 * - Must be 3-30 characters long
	 * - Can only contain letters, numbers, and underscores
	 * - Must be unique across all users
	 *
	 * @example
	 * ```typescript
	 * try {
	 *   const user = await client.users.updateUsername({ username: 'johndoe' });
	 *   console.log(`Username updated to: ${user.username}`);
	 * } catch (e) {
	 *   if (e instanceof ElyraValidationError) {
	 *     // Handle validation errors
	 *     const usernameErrors = e.validationErrors?.username;
	 *     if (usernameErrors) {
	 *       console.error('Username errors:', usernameErrors.join(', '));
	 *     }
	 *   }
	 * }
	 * ```
	 */
	updateUsername(request: UpdateUsernameRequest): Promise<User>;

	/**
	 * Check if a username is available for registration.
	 *
	 * @remarks
	 * This endpoint is public and does not require authentication.
	 * Use this before attempting to set a username to provide
	 * real-time feedback to users.
	 *
	 * @param username - The username to check
	 * @returns Object containing availability status and the checked username
	 *
	 * @throws {ElyraNetworkError} If the request fails due to network issues
	 * @throws {ElyraRateLimitError} If too many requests have been made
	 *
	 * @example
	 * ```typescript
	 * // Check availability before showing submit button
	 * const { available, username } = await client.users.checkUsernameAvailability('johndoe');
	 * if (available) {
	 *   console.log(`"${username}" is available!`);
	 *   showSubmitButton();
	 * } else {
	 *   console.log(`"${username}" is already taken.`);
	 *   showError('This username is not available');
	 * }
	 * ```
	 */
	checkUsernameAvailability(username: string): Promise<UsernameAvailabilityResponse>;
}
