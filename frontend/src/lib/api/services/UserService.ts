import type { IUserService } from '../interfaces/IUserService';
import type { User, UpdateUsernameRequest, UsernameAvailabilityResponse } from '../types/user';
import type { ApiResponse } from '../types/common';
import type { HttpClient } from '../core/HttpClient';

export class UserService implements IUserService {
	private readonly httpClient: HttpClient;

	constructor(httpClient: HttpClient) {
		this.httpClient = httpClient;
	}

	async getCurrentUser(): Promise<User> {
		const response = await this.httpClient.get<ApiResponse<User>>('/users/me');
		return response.data;
	}

	async updateUsername(request: UpdateUsernameRequest): Promise<User> {
		const response = await this.httpClient.put<ApiResponse<User>>('/users/username', request);
		return response.data;
	}

	async checkUsernameAvailability(username: string): Promise<UsernameAvailabilityResponse> {
		return this.httpClient.get<UsernameAvailabilityResponse>(
			`/users/check-username?username=${encodeURIComponent(username)}`
		);
	}
}
