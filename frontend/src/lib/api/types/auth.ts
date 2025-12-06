import type { User } from './user';

/**
 * Supported OAuth providers.
 */
export type OAuthProvider = 'google';

/**
 * Authentication state for the application.
 * Used by auth stores/contexts to track user session.
 */
export interface AuthState {
	/** Currently authenticated user, or null if not authenticated */
	user: User | null;
	/** JWT token for API authentication */
	token: string | null;
	/** Computed property: true if user and token are present */
	isAuthenticated: boolean;
	/** True while auth state is being determined */
	isLoading: boolean;
}
