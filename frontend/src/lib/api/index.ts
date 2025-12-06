// Re-export types
export * from './types';
export * from './interfaces';
export * from './core/errors';

// Export the client class and config utilities
export { ElyraClient } from './ElyraClient';
export { createConfig, getDefaultConfig } from './core/config';

// Import for singleton creation
import { ElyraClient } from './ElyraClient';
import { createConfig } from './core/config';

// Token storage key
const TOKEN_KEY = 'auth_token';

/**
 * Get token from localStorage (browser-only)
 */
function getStoredToken(): string | null {
	if (typeof window === 'undefined') return null;
	return localStorage.getItem(TOKEN_KEY);
}

/**
 * Pre-configured singleton instance of the Elyra client.
 *
 * This instance is configured with:
 * - Environment-aware API URL (VITE_API_URL or localhost:4000)
 * - localStorage-based token management
 *
 * @example
 * ```typescript
 * import { elyraClient } from '$lib/api';
 *
 * // Use the singleton
 * const user = await elyraClient.users.getCurrentUser();
 * ```
 */
export const elyraClient = new ElyraClient(
	createConfig({
		getToken: getStoredToken
	})
);
