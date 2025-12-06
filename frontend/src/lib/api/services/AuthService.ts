import type { IAuthService } from '../interfaces/IAuthService';
import type { OAuthProvider } from '../types/auth';
import type { HttpClient } from '../core/HttpClient';

export class AuthService implements IAuthService {
	private readonly supportedProviders: OAuthProvider[] = ['google'];
	private readonly httpClient: HttpClient;

	constructor(httpClient: HttpClient) {
		this.httpClient = httpClient;
	}

	getOAuthUrl(provider: OAuthProvider, redirectPath?: string): string {
		const baseUrl = this.httpClient.getBaseUrl();
		let url = `${baseUrl}/auth/${provider}`;

		if (redirectPath) {
			url += `?redirect=${encodeURIComponent(redirectPath)}`;
		}

		return url;
	}

	getSupportedProviders(): OAuthProvider[] {
		return [...this.supportedProviders];
	}
}
