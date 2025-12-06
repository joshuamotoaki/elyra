import { socketService } from '$lib/api/services/SocketService';
import type {
	MatchState,
	MatchPlayer,
	PlayerJoinedEvent,
	PlayerLeftEvent,
	GameStartedEvent,
	CellClaimedEvent,
	TickEvent,
	GameEndedEvent
} from '$lib/api/types/match';

class MatchStore {
	matchId = $state<number | null>(null);
	code = $state<string | null>(null);
	status = $state<'waiting' | 'playing' | 'finished'>('waiting');
	gridSize = $state(4);
	timeRemaining = $state(30);
	hostId = $state<number | null>(null);
	players = $state<Record<number, MatchPlayer>>({});
	grid = $state<Record<string, number | null>>({});
	winnerId = $state<number | null>(null);
	error = $state<string | null>(null);
	isConnecting = $state(false);

	// Final results - captured when game ends, doesn't change when players leave
	finalPlayers = $state<Record<number, MatchPlayer>>({});
	finalGrid = $state<Record<string, number | null>>({});

	get playerList(): MatchPlayer[] {
		return Object.values(this.players);
	}

	get playerCount(): number {
		return Object.keys(this.players).length;
	}

	// Use final results for the results screen
	get finalPlayerList(): MatchPlayer[] {
		return Object.values(this.finalPlayers);
	}

	/**
	 * Connect to the WebSocket server.
	 */
	connect(token: string): void {
		socketService.connect(token);
	}

	/**
	 * Join a match and set up event handlers.
	 */
	async joinMatch(matchId: number): Promise<void> {
		this.isConnecting = true;
		this.error = null;

		try {
			const state = await socketService.joinMatch(matchId, {
				onPlayerJoined: (event: PlayerJoinedEvent) => this.handlePlayerJoined(event),
				onPlayerLeft: (event: PlayerLeftEvent) => this.handlePlayerLeft(event),
				onGameStarted: (event: GameStartedEvent) => this.handleGameStarted(event),
				onCellClaimed: (event: CellClaimedEvent) => this.handleCellClaimed(event),
				onTick: (event: TickEvent) => this.handleTick(event),
				onGameEnded: (event: GameEndedEvent) => this.handleGameEnded(event)
			});

			// Initialize state from server
			this.matchId = state.match_id;
			this.code = state.code;
			this.status = state.status;
			this.gridSize = state.grid_size;
			this.timeRemaining = state.time_remaining;
			this.hostId = state.host_id;
			this.players = state.players;
			this.grid = state.grid;
		} catch (e) {
			this.error = e instanceof Error ? e.message : 'Failed to join match';
			throw e;
		} finally {
			this.isConnecting = false;
		}
	}

	/**
	 * Start the game. Only the host can do this.
	 */
	async startGame(): Promise<void> {
		try {
			await socketService.startGame();
		} catch (e) {
			this.error = e instanceof Error ? e.message : 'Failed to start game';
			throw e;
		}
	}

	/**
	 * Click a cell to claim it.
	 */
	async clickCell(row: number, col: number): Promise<void> {
		if (this.status !== 'playing') return;

		try {
			await socketService.clickCell(row, col);
		} catch (e) {
			// Silently ignore click errors (e.g., invalid cell)
			console.warn('Click failed:', e);
		}
	}

	/**
	 * Leave the current match.
	 */
	leaveMatch(): void {
		socketService.leaveMatch();
		this.reset();
	}

	/**
	 * Disconnect from the WebSocket server.
	 */
	disconnect(): void {
		socketService.disconnect();
		this.reset();
	}

	/**
	 * Reset the store state.
	 */
	reset(): void {
		this.matchId = null;
		this.code = null;
		this.status = 'waiting';
		this.gridSize = 4;
		this.timeRemaining = 30;
		this.hostId = null;
		this.players = {};
		this.grid = {};
		this.winnerId = null;
		this.error = null;
		this.isConnecting = false;
		this.finalPlayers = {};
		this.finalGrid = {};
	}

	// Event handlers
	private handlePlayerJoined(event: PlayerJoinedEvent): void {
		this.players = {
			...this.players,
			[event.user_id]: {
				user_id: event.user_id,
				username: event.username,
				picture: event.picture,
				color: event.color,
				score: event.score
			}
		};
	}

	private handlePlayerLeft(event: PlayerLeftEvent): void {
		const { [event.user_id]: _, ...rest } = this.players;
		this.players = rest;
	}

	private handleGameStarted(event: GameStartedEvent): void {
		this.status = 'playing';
		this.timeRemaining = event.time_remaining;
	}

	private handleCellClaimed(event: CellClaimedEvent): void {
		const key = `${event.row},${event.col}`;
		this.grid = { ...this.grid, [key]: event.user_id };
	}

	private handleTick(event: TickEvent): void {
		this.timeRemaining = event.time_remaining;
	}

	private handleGameEnded(event: GameEndedEvent): void {
		this.status = 'finished';
		this.winnerId = event.winner_id;
		this.grid = event.final_grid;

		// Update player scores
		let finalPlayerData: Record<number, MatchPlayer>;
		if (event.players) {
			finalPlayerData = event.players;
		} else {
			// Update scores from the scores map
			finalPlayerData = { ...this.players };
			for (const [userId, score] of Object.entries(event.scores)) {
				const id = Number(userId);
				if (finalPlayerData[id]) {
					finalPlayerData[id] = { ...finalPlayerData[id], score };
				}
			}
		}

		this.players = finalPlayerData;
		this.finalPlayers = finalPlayerData;
		this.finalGrid = event.final_grid;
	}
}

export const matchStore = new MatchStore();
