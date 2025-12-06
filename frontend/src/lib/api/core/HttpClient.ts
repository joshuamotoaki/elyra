import type { ElyraClientConfig, ApiError } from '../types';
import {
	ElyraError,
	ElyraAuthenticationError,
	ElyraValidationError,
	ElyraNetworkError,
	ElyraNotFoundError,
	ElyraRateLimitError,
	ElyraServerError
} from './errors';

export interface HttpClientOptions {
	auth?: boolean;
}

/**
 * Internal HTTP client that handles all low-level communication.
 * Not exposed to consumers - services use this internally.
 */
export class HttpClient {
	private baseUrl: string;
	private token: string | null = null;
	private getTokenFn?: () => string | null;
	private onTokenInvalid?: () => void;
	private timeout: number;

	constructor(config: ElyraClientConfig) {
		this.baseUrl = config.baseUrl.replace(/\/$/, ''); // Remove trailing slash
		this.getTokenFn = config.getToken;
		this.onTokenInvalid = config.onTokenInvalid;
		this.timeout = config.timeout ?? 30000;
	}

	setToken(token: string | null): void {
		this.token = token;
	}

	getToken(): string | null {
		// Prefer externally provided token function, fallback to internal
		return this.getTokenFn?.() ?? this.token;
	}

	private getHeaders(includeAuth: boolean = true): HeadersInit {
		const headers: HeadersInit = {
			'Content-Type': 'application/json'
		};

		if (includeAuth) {
			const token = this.getToken();
			if (token) {
				headers['Authorization'] = `Bearer ${token}`;
			}
		}

		return headers;
	}

	private async handleResponse<T>(response: Response): Promise<T> {
		// Handle different status codes
		if (response.ok) {
			return response.json();
		}

		let errorData: ApiError;
		try {
			errorData = await response.json();
		} catch {
			errorData = { error: `HTTP ${response.status}` };
		}

		switch (response.status) {
			case 401:
				this.onTokenInvalid?.();
				throw new ElyraAuthenticationError(errorData.error);
			case 404:
				throw new ElyraNotFoundError(errorData.error);
			case 422:
				throw new ElyraValidationError(errorData.error, errorData.errors);
			case 429: {
				const retryAfter = response.headers.get('Retry-After');
				throw new ElyraRateLimitError(
					errorData.error,
					retryAfter ? parseInt(retryAfter, 10) : undefined
				);
			}
			default:
				if (response.status >= 500) {
					throw new ElyraServerError(errorData.error, response.status);
				}
				throw new ElyraError(errorData.error, response.status);
		}
	}

	async get<T>(endpoint: string, options: HttpClientOptions = {}): Promise<T> {
		const { auth = true } = options;

		try {
			const controller = new AbortController();
			const timeoutId = setTimeout(() => controller.abort(), this.timeout);

			const response = await fetch(`${this.baseUrl}${endpoint}`, {
				method: 'GET',
				headers: this.getHeaders(auth),
				signal: controller.signal
			});

			clearTimeout(timeoutId);
			return this.handleResponse<T>(response);
		} catch (error) {
			if (error instanceof ElyraError) throw error;
			if (error instanceof Error && error.name === 'AbortError') {
				throw new ElyraNetworkError('Request timed out');
			}
			throw new ElyraNetworkError('Network request failed');
		}
	}

	async post<T>(endpoint: string, body: unknown, options: HttpClientOptions = {}): Promise<T> {
		const { auth = true } = options;

		try {
			const controller = new AbortController();
			const timeoutId = setTimeout(() => controller.abort(), this.timeout);

			const response = await fetch(`${this.baseUrl}${endpoint}`, {
				method: 'POST',
				headers: this.getHeaders(auth),
				body: JSON.stringify(body),
				signal: controller.signal
			});

			clearTimeout(timeoutId);
			return this.handleResponse<T>(response);
		} catch (error) {
			if (error instanceof ElyraError) throw error;
			if (error instanceof Error && error.name === 'AbortError') {
				throw new ElyraNetworkError('Request timed out');
			}
			throw new ElyraNetworkError('Network request failed');
		}
	}

	async put<T>(endpoint: string, body: unknown, options: HttpClientOptions = {}): Promise<T> {
		const { auth = true } = options;

		try {
			const controller = new AbortController();
			const timeoutId = setTimeout(() => controller.abort(), this.timeout);

			const response = await fetch(`${this.baseUrl}${endpoint}`, {
				method: 'PUT',
				headers: this.getHeaders(auth),
				body: JSON.stringify(body),
				signal: controller.signal
			});

			clearTimeout(timeoutId);
			return this.handleResponse<T>(response);
		} catch (error) {
			if (error instanceof ElyraError) throw error;
			if (error instanceof Error && error.name === 'AbortError') {
				throw new ElyraNetworkError('Request timed out');
			}
			throw new ElyraNetworkError('Network request failed');
		}
	}

	getBaseUrl(): string {
		return this.baseUrl;
	}
}
