const API_BASE = 'http://localhost:4000/api';

function getToken(): string | null {
	if (typeof window === 'undefined') return null;
	return localStorage.getItem('auth_token');
}

function getHeaders(): HeadersInit {
	const headers: HeadersInit = {
		'Content-Type': 'application/json'
	};

	const token = getToken();
	if (token) {
		headers['Authorization'] = `Bearer ${token}`;
	}

	return headers;
}

async function handleResponse<T>(response: Response): Promise<T> {
	if (!response.ok) {
		const data = await response.json().catch(() => ({}));
		throw new Error(data.error || `HTTP ${response.status}`);
	}
	return response.json();
}

export async function apiGet<T>(endpoint: string): Promise<T> {
	const response = await fetch(`${API_BASE}${endpoint}`, {
		method: 'GET',
		headers: getHeaders()
	});
	return handleResponse<T>(response);
}

export async function apiPut<T>(endpoint: string, body: unknown): Promise<T> {
	const response = await fetch(`${API_BASE}${endpoint}`, {
		method: 'PUT',
		headers: getHeaders(),
		body: JSON.stringify(body)
	});
	return handleResponse<T>(response);
}

export async function apiPost<T>(endpoint: string, body: unknown): Promise<T> {
	const response = await fetch(`${API_BASE}${endpoint}`, {
		method: 'POST',
		headers: getHeaders(),
		body: JSON.stringify(body)
	});
	return handleResponse<T>(response);
}
