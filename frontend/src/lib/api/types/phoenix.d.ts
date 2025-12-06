declare module 'phoenix' {
	export class Socket {
		constructor(endPoint: string, opts?: SocketOptions);
		connect(): void;
		disconnect(): void;
		isConnected(): boolean;
		channel(topic: string, params?: object): Channel;
	}

	export interface SocketOptions {
		params?: object | (() => object);
		transport?: unknown;
		timeout?: number;
		heartbeatIntervalMs?: number;
		reconnectAfterMs?: (tries: number) => number;
		logger?: (kind: string, msg: string, data: unknown) => void;
		longpollerTimeout?: number;
		vsn?: string;
	}

	export class Channel {
		join(timeout?: number): Push;
		leave(timeout?: number): Push;
		push(event: string, payload: object, timeout?: number): Push;
		on(event: string, callback: (payload: unknown) => void): number;
		off(event: string, ref?: number): void;
	}

	export class Push {
		receive(status: string, callback: (response: unknown) => void): Push;
	}
}
