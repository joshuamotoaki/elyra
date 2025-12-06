/**
 * Base error class for all Elyra API errors.
 * Provides structured error information with original context.
 */
export class ElyraError extends Error {
	/** HTTP status code if applicable */
	public readonly statusCode?: number;
	/** Original error message from the API */
	public readonly originalMessage: string;
	/** Timestamp when the error occurred */
	public readonly timestamp: Date;

	constructor(message: string, statusCode?: number) {
		super(message);
		this.name = 'ElyraError';
		this.statusCode = statusCode;
		this.originalMessage = message;
		this.timestamp = new Date();
	}
}

/**
 * Thrown when authentication fails or token is invalid/expired.
 *
 * @example
 * ```typescript
 * try {
 *   await client.users.getCurrentUser();
 * } catch (e) {
 *   if (e instanceof ElyraAuthenticationError) {
 *     // Redirect to login
 *     goto('/');
 *   }
 * }
 * ```
 */
export class ElyraAuthenticationError extends ElyraError {
	constructor(message: string = 'Authentication required') {
		super(message, 401);
		this.name = 'ElyraAuthenticationError';
	}
}

/**
 * Thrown when validation fails on the server.
 * Contains field-specific error messages.
 *
 * @example
 * ```typescript
 * if (error instanceof ElyraValidationError) {
 *   const usernameErrors = error.validationErrors?.username;
 *   if (usernameErrors) {
 *     console.log('Username errors:', usernameErrors.join(', '));
 *   }
 * }
 * ```
 */
export class ElyraValidationError extends ElyraError {
	/** Field-specific validation errors */
	public readonly validationErrors?: Record<string, string[]>;

	constructor(message: string, validationErrors?: Record<string, string[]>) {
		super(message, 422);
		this.name = 'ElyraValidationError';
		this.validationErrors = validationErrors;
	}
}

/**
 * Thrown when a network error occurs (timeout, DNS failure, etc.).
 */
export class ElyraNetworkError extends ElyraError {
	constructor(message: string = 'Network error occurred') {
		super(message);
		this.name = 'ElyraNetworkError';
	}
}

/**
 * Thrown when the requested resource is not found.
 */
export class ElyraNotFoundError extends ElyraError {
	constructor(message: string = 'Resource not found') {
		super(message, 404);
		this.name = 'ElyraNotFoundError';
	}
}

/**
 * Thrown when rate limiting is triggered.
 */
export class ElyraRateLimitError extends ElyraError {
	/** When the rate limit will reset (if provided by server) */
	public readonly retryAfter?: Date;

	constructor(message: string = 'Rate limit exceeded', retryAfterSeconds?: number) {
		super(message, 429);
		this.name = 'ElyraRateLimitError';
		if (retryAfterSeconds) {
			this.retryAfter = new Date(Date.now() + retryAfterSeconds * 1000);
		}
	}
}

/**
 * Thrown for unexpected server errors (5xx).
 */
export class ElyraServerError extends ElyraError {
	constructor(message: string = 'Server error occurred', statusCode: number = 500) {
		super(message, statusCode);
		this.name = 'ElyraServerError';
	}
}
