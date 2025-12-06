import type { User } from '$lib/api';
import { elyraClient, ElyraAuthenticationError } from '$lib/api';

const TOKEN_KEY = 'auth_token';

class AuthStore {
	user = $state<User | null>(null);
	token = $state<string | null>(null);
	isLoading = $state(true);

	constructor() {
		// Initialize from localStorage on client
		if (typeof window !== 'undefined') {
			const storedToken = localStorage.getItem(TOKEN_KEY);
			if (storedToken) {
				this.token = storedToken;
				elyraClient.setToken(storedToken);
			}
		}
	}

	get isAuthenticated(): boolean {
		return !!this.token && !!this.user;
	}

	get needsOnboarding(): boolean {
		return !!this.user && !this.user.username;
	}

	setToken(newToken: string): void {
		this.token = newToken;
		elyraClient.setToken(newToken);
		if (typeof window !== 'undefined') {
			localStorage.setItem(TOKEN_KEY, newToken);
		}
	}

	async loadUser(): Promise<void> {
		if (!this.token) {
			this.isLoading = false;
			return;
		}

		try {
			const user = await elyraClient.users.getCurrentUser();
			this.user = user;
		} catch (e) {
			if (e instanceof ElyraAuthenticationError) {
				// Token invalid, clear it
				this.logout();
			}
		} finally {
			this.isLoading = false;
		}
	}

	async setUsername(username: string): Promise<void> {
		const user = await elyraClient.users.updateUsername({ username });
		this.user = user;
	}

	logout(): void {
		this.user = null;
		this.token = null;
		elyraClient.setToken(null);
		if (typeof window !== 'undefined') {
			localStorage.removeItem(TOKEN_KEY);
		}
	}
}

export const auth = new AuthStore();
