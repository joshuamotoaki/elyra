import type { OAuthProvider } from '../types/auth';

/**
 * Authentication Service Interface
 *
 * Handles all authentication-related operations including OAuth flows.
 *
 * @remarks
 * This service manages OAuth authentication with external providers.
 * The actual OAuth flow is handled server-side; this service provides
 * the URLs and handles the callback processing.
 *
 * @example
 * ```typescript
 * // Initiate Google OAuth login
 * const loginUrl = client.auth.getOAuthUrl('google');
 * window.location.href = loginUrl;
 *
 * // In callback page, the token comes via URL params from the backend
 * // The backend handles the OAuth callback and redirects with token
 * ```
 */
export interface IAuthService {
	/**
	 * Get the OAuth initiation URL for a provider.
	 *
	 * Redirect the user to this URL to begin the OAuth flow.
	 * After authentication, the backend will redirect to `/auth/callback`
	 * with a token parameter.
	 *
	 * @param provider - The OAuth provider to use
	 * @param redirectPath - Optional path to redirect to after authentication (default: '/dashboard')
	 * @returns The full URL to redirect the user to
	 *
	 * @example
	 * ```typescript
	 * const url = client.auth.getOAuthUrl('google');
	 * // Returns: "http://localhost:4000/api/auth/google"
	 *
	 * // With custom redirect
	 * const url = client.auth.getOAuthUrl('google', '/onboarding');
	 * // Returns: "http://localhost:4000/api/auth/google?redirect=/onboarding"
	 * ```
	 */
	getOAuthUrl(provider: OAuthProvider, redirectPath?: string): string;

	/**
	 * Get the list of supported OAuth providers.
	 *
	 * @returns Array of supported provider names
	 *
	 * @example
	 * ```typescript
	 * const providers = client.auth.getSupportedProviders();
	 * // Returns: ['google']
	 * ```
	 */
	getSupportedProviders(): OAuthProvider[];
}
