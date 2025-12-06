/**
 * Represents a user in the Elyra system.
 *
 * @example
 * const user: User = {
 *   id: 1,
 *   email: "user@example.com",
 *   name: "John Doe",
 *   username: "johndoe",
 *   picture: "https://example.com/avatar.jpg",
 *   is_admin: false
 * };
 */
export interface User {
	/** Unique identifier for the user */
	id: number;
	/** User's email address (from OAuth provider) */
	email: string;
	/** User's display name (from OAuth provider, may be null) */
	name: string | null;
	/** User's chosen username (null until onboarding is complete) */
	username: string | null;
	/** URL to user's profile picture (from OAuth provider) */
	picture: string | null;
	/** Whether the user has admin privileges */
	is_admin: boolean;
}

/**
 * Request payload for updating a user's username.
 */
export interface UpdateUsernameRequest {
	/** The new username (must be unique, 3-30 chars, alphanumeric + underscore) */
	username: string;
}

/**
 * Response from username availability check.
 */
export interface UsernameAvailabilityResponse {
	/** Whether the username is available for registration */
	available: boolean;
	/** The username that was checked */
	username: string;
}
