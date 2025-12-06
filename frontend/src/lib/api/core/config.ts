import type { ElyraClientConfig } from '../types/common';

/**
 * Get the default configuration for the Elyra client.
 * Reads from environment variables with sensible defaults.
 */
export function getDefaultConfig(): Partial<ElyraClientConfig> {
	// In SvelteKit, use import.meta.env for environment variables
	const baseUrl =
		(typeof import.meta !== 'undefined' && import.meta.env?.VITE_API_URL) ||
		'http://localhost:4000/api';

	return {
		baseUrl,
		timeout: 30000
	};
}

/**
 * Create a full configuration by merging provided options with defaults.
 */
export function createConfig(options: Partial<ElyraClientConfig> = {}): ElyraClientConfig {
	const defaults = getDefaultConfig();

	return {
		baseUrl: options.baseUrl ?? defaults.baseUrl ?? 'http://localhost:4000/api',
		getToken: options.getToken,
		onTokenInvalid: options.onTokenInvalid,
		timeout: options.timeout ?? defaults.timeout
	};
}
