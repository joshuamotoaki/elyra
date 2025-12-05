import type { User, ApiResponse } from '$lib/api/types';
import { apiGet, apiPut } from '$lib/api/client';

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
      }
    }
  }

  get isAuthenticated(): boolean {
    return !!this.token && !!this.user;
  }

  get needsOnboarding(): boolean {
    return !!this.user && !this.user.onboarding_complete;
  }

  setToken(newToken: string): void {
    this.token = newToken;
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
      const response = await apiGet<ApiResponse<User>>('/users/me');
      this.user = response.data;
    } catch {
      // Token invalid, clear it
      this.logout();
    } finally {
      this.isLoading = false;
    }
  }

  async setUsername(username: string): Promise<void> {
    const response = await apiPut<ApiResponse<User>>('/users/username', { username });
    this.user = response.data;
  }

  logout(): void {
    this.user = null;
    this.token = null;
    if (typeof window !== 'undefined') {
      localStorage.removeItem(TOKEN_KEY);
    }
  }
}

export const auth = new AuthStore();
