import type { HttpClient } from '../core/HttpClient';
import type { Match, CreateMatchRequest, JoinMatchRequest } from '../types/match';
import type { ApiResponse } from '../types/common';

/**
 * Service for match REST API operations.
 */
export class MatchService {
	constructor(private readonly httpClient: HttpClient) {}

	/**
	 * List all available (waiting) matches.
	 */
	async listMatches(): Promise<Match[]> {
		const response = await this.httpClient.get<{ data: Match[] }>('/matches');
		return response.data;
	}

	/**
	 * Create a new match.
	 */
	async createMatch(request?: CreateMatchRequest): Promise<Match> {
		const response = await this.httpClient.post<ApiResponse<Match>>('/matches', request || {});
		return response.data;
	}

	/**
	 * Get a match by ID.
	 */
	async getMatch(id: number): Promise<Match> {
		const response = await this.httpClient.get<ApiResponse<Match>>(`/matches/${id}`);
		return response.data;
	}

	/**
	 * Join a match by code.
	 */
	async joinByCode(request: JoinMatchRequest): Promise<Match> {
		const response = await this.httpClient.post<ApiResponse<Match>>('/matches/join', request);
		return response.data;
	}
}
