import type { IElyraClient } from './interfaces/IElyraClient';
import type { IAuthService } from './interfaces/IAuthService';
import type { IUserService } from './interfaces/IUserService';
import type { ElyraClientConfig } from './types/common';
import { HttpClient } from './core/HttpClient';
import { AuthService } from './services/AuthService';
import { UserService } from './services/UserService';

export class ElyraClient implements IElyraClient {
	private readonly httpClient: HttpClient;
	private readonly _auth: AuthService;
	private readonly _users: UserService;

	constructor(config: ElyraClientConfig) {
		this.httpClient = new HttpClient(config);
		this._auth = new AuthService(this.httpClient);
		this._users = new UserService(this.httpClient);
	}

	get auth(): IAuthService {
		return this._auth;
	}

	get users(): IUserService {
		return this._users;
	}

	setToken(token: string | null): void {
		this.httpClient.setToken(token);
	}

	getToken(): string | null {
		return this.httpClient.getToken();
	}

	hasToken(): boolean {
		return this.httpClient.getToken() !== null;
	}
}
