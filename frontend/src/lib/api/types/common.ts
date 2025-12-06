/**
 * Standard API response wrapper from Phoenix backend.
 * All successful responses are wrapped in this structure.
 *
 * @template T - The type of data contained in the response
 *
 * @example
 * // Typical usage with User type
 * const response: ApiResponse<User> = { data: user };
 * console.log(response.data.email);
 */
export interface ApiResponse<T> {
	/** The actual response data */
	data: T;
}

/**
 * Standard error response from Phoenix backend.
 * Returned when API requests fail.
 *
 * @example
 * // Error response for validation failure
 * {
 *   error: "Validation failed",
 *   errors: {
 *     username: ["is already taken", "must be at least 3 characters"]
 *   }
 * }
 */
export interface ApiError {
	/** Human-readable error message */
	error: string;
	/** Optional field-specific validation errors */
	errors?: Record<string, string[]>;
}

/**
 * Configuration options for the Elyra client.
 */
export interface ElyraClientConfig {
	/** Base URL for the API (e.g., 'http://localhost:4000/api') */
	baseUrl: string;
	/** Optional function to retrieve the current auth token */
	getToken?: () => string | null;
	/** Optional function called when token needs to be cleared (e.g., on 401) */
	onTokenInvalid?: () => void;
	/** Request timeout in milliseconds (default: 30000) */
	timeout?: number;
}
