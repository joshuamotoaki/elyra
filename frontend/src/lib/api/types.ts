export interface User {
	id: number;
	email: string;
	name: string | null;
	username: string | null;
	picture: string | null;
	onboarding_complete: boolean;
}

export interface AuthState {
	user: User | null;
	token: string | null;
	isAuthenticated: boolean;
	isLoading: boolean;
}

export interface ApiResponse<T> {
	data: T;
}

export interface ApiError {
	error: string;
	errors?: Record<string, string[]>;
}
