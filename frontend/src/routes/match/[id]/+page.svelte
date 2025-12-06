<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { goto } from '$app/navigation';
	import { page } from '$app/stores';
	import { auth } from '$lib/stores/auth.svelte';
	import { gameStore } from '$lib/stores/game.svelte';
	import { socketService } from '$lib/api/services/SocketService';
	import GameCanvas from '$lib/components/game/GameCanvas.svelte';
	import GameHUD from '$lib/components/game/GameHUD.svelte';

	const matchId = $derived(Number($page.params.id));
	const isHost = $derived(auth.user?.id === gameStore.hostId);
	const currentUserId = $derived(auth.user?.id);

	// Get winner info
	const winner = $derived(
		gameStore.winnerId ? gameStore.finalPlayers.get(gameStore.winnerId) : null
	);

	// Sort players by score for leaderboard
	const sortedPlayers = $derived(
		Array.from(gameStore.finalPlayers.values()).sort(
			(a, b) => (gameStore.finalScores[b.user_id] || 0) - (gameStore.finalScores[a.user_id] || 0)
		)
	);

	onMount(async () => {
		if (!auth.token || !auth.user) {
			goto('/');
			return;
		}

		gameStore.isConnecting = true;

		try {
			// Connect socket
			socketService.connect(auth.token);

			// Join game with new callbacks
			const state = await socketService.joinGame(matchId, {
				onPlayerJoined: (event) => gameStore.handlePlayerJoined(event),
				onPlayerLeft: (event) => gameStore.handlePlayerLeft(event.user_id),
				onGameStarted: (event) => gameStore.handleGameStarted(event.time_remaining_ms),
				onStateDelta: (event) => gameStore.applyDelta(event),
				onBeamFired: (event) => gameStore.handleBeamFired(event),
				onBeamEnded: (event) => gameStore.handleBeamEnded(event.id),
				onCoinTelegraph: (event) => gameStore.handleCoinTelegraph(event),
				onCoinSpawned: (event) => gameStore.handleCoinSpawned(event),
				onCoinCollected: (event) => gameStore.handleCoinCollected(event.id),
				onPowerUpPurchased: (event) => gameStore.handlePowerUpPurchased(event.user_id, event.type),
				onGameEnded: (event) =>
					gameStore.handleGameEnded(event.winner_id, event.scores, event.players)
			});

			// Initialize store from state
			gameStore.initializeFromState(state, auth.user.id);
		} catch (e) {
			console.error('Failed to join match:', e);
			gameStore.error = e instanceof Error ? e.message : 'Failed to join';
			gameStore.isConnecting = false;
		}
	});

	onDestroy(() => {
		socketService.leaveMatch();
		gameStore.reset();
	});

	function returnToLobby() {
		socketService.leaveMatch();
		gameStore.reset();
		goto('/lobby');
	}

	async function startGame() {
		try {
			await socketService.startGame();
		} catch (e) {
			console.error('Failed to start game:', e);
		}
	}
</script>

<div class="match-container">
	{#if gameStore.isConnecting}
		<!-- Loading State -->
		<div class="loading">
			<div class="loading-text">Connecting to match...</div>
			<div class="loading-spinner"></div>
		</div>
	{:else if gameStore.error}
		<!-- Error State -->
		<div class="error-state">
			<div class="error-text">Error: {gameStore.error}</div>
			<button class="btn btn-primary" onclick={returnToLobby}> Return to Lobby </button>
		</div>
	{:else if gameStore.status === 'waiting'}
		<!-- Waiting Room -->
		<div class="waiting-room">
			{#if gameStore.isSolo}
				<h1 class="title">Solo Practice</h1>
				<p class="subtitle">Press start when ready!</p>
			{:else}
				<h1 class="title">Waiting for Players</h1>
				<div class="match-code">{gameStore.code}</div>
				<p class="subtitle">Share this code with friends to join!</p>
			{/if}

			<!-- Players -->
			<div class="players-box">
				<h2 class="players-title">
					{#if gameStore.isSolo}
						Your Character
					{:else}
						Players ({gameStore.playerList.length}/4)
					{/if}
				</h2>
				<div class="players-list">
					{#each gameStore.playerList as player}
						<div class="player-item">
							<div class="player-color" style="background-color: {player.color}"></div>
							{#if player.picture}
								<img src={player.picture} alt="" class="player-avatar" />
							{:else}
								<div class="player-avatar-placeholder">
									{(player.username || '?')[0].toUpperCase()}
								</div>
							{/if}
							<span class="player-name">
								{player.username || 'Player'}
								{#if player.user_id === gameStore.hostId && !gameStore.isSolo}
									<span class="badge host">(Host)</span>
								{/if}
								{#if player.user_id === currentUserId}
									<span class="badge you">(You)</span>
								{/if}
							</span>
						</div>
					{/each}
				</div>
			</div>

			<!-- Start Button (Host Only) -->
			{#if isHost}
				<button
					class="btn btn-start"
					onclick={startGame}
					disabled={!gameStore.isSolo && gameStore.playerList.length < 2}
				>
					{#if gameStore.isSolo}
						Start Practice
					{:else if gameStore.playerList.length < 2}
						Need at least 2 players
					{:else}
						Start Game
					{/if}
				</button>
			{:else}
				<p class="waiting-text">Waiting for host to start the game...</p>
			{/if}

			<button class="btn-text" onclick={returnToLobby}> Leave Match </button>
		</div>
	{:else if gameStore.status === 'playing'}
		<!-- 3D Game View -->
		<GameCanvas />
		<GameHUD />
	{:else}
		<!-- Game Over -->
		<div class="game-over">
			{#if gameStore.isSolo}
				<h1 class="title">Practice Complete</h1>

				<!-- Solo Stats -->
				<div class="scores-box">
					<h2 class="scores-title">Your Stats</h2>
					<div class="scores-list">
						{#each sortedPlayers as player}
							<div class="score-item">
								<div class="player-color" style="background-color: {player.color}"></div>
								<span class="score-name">{player.username || 'Player'}</span>
								<span class="score-value"
									>{(gameStore.finalScores[player.user_id] || 0).toFixed(1)}% territory</span
								>
							</div>
						{/each}
					</div>
				</div>
			{:else}
				<h1 class="title">Game Over!</h1>

				{#if winner}
					<div class="winner-section">
						<div class="winner-label">Winner</div>
						<div class="winner-display">
							<div class="player-color large" style="background-color: {winner.color}"></div>
							<span class="winner-name">{winner.username || 'Player'}</span>
							{#if winner.user_id === currentUserId}
								<span class="winner-you">That's you!</span>
							{/if}
						</div>
					</div>
				{/if}

				<!-- Final Scores -->
				<div class="scores-box">
					<h2 class="scores-title">Final Scores</h2>
					<div class="scores-list">
						{#each sortedPlayers as player, index}
							<div class="score-item">
								<span class="score-rank">{index + 1}.</span>
								<div class="player-color" style="background-color: {player.color}"></div>
								<span class="score-name">
									{player.username || 'Player'}
									{#if player.user_id === currentUserId}
										<span class="badge you">(You)</span>
									{/if}
								</span>
								<span class="score-value"
									>{(gameStore.finalScores[player.user_id] || 0).toFixed(1)}%</span
								>
							</div>
						{/each}
					</div>
				</div>
			{/if}

			<button class="btn btn-primary" onclick={returnToLobby}> Return to Lobby </button>
		</div>
	{/if}
</div>

<style>
	.match-container {
		min-height: 100vh;
		height: 100vh;
		background: #0f172a;
		color: white;
		overflow: hidden;
		position: relative;
	}

	.loading,
	.error-state,
	.waiting-room,
	.game-over {
		min-height: 100vh;
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 2rem;
	}

	.loading-text,
	.error-text {
		font-size: 1.5rem;
		margin-bottom: 1rem;
	}

	.error-text {
		color: #f87171;
	}

	.loading-spinner {
		width: 40px;
		height: 40px;
		border: 3px solid #374151;
		border-top-color: #3b82f6;
		border-radius: 50%;
		animation: spin 1s linear infinite;
	}

	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}

	.title {
		font-size: 2rem;
		font-weight: bold;
		margin-bottom: 0.5rem;
	}

	.match-code {
		font-size: 3rem;
		font-family: monospace;
		color: #60a5fa;
		margin-bottom: 0.5rem;
		letter-spacing: 0.2em;
	}

	.subtitle,
	.waiting-text {
		color: #9ca3af;
		margin-bottom: 2rem;
	}

	.players-box,
	.scores-box {
		background: #1e293b;
		border-radius: 0.75rem;
		padding: 1.5rem;
		margin-bottom: 1.5rem;
		width: 100%;
		max-width: 24rem;
	}

	.players-title,
	.scores-title {
		font-size: 1.25rem;
		font-weight: 600;
		margin-bottom: 1rem;
	}

	.players-list,
	.scores-list {
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
	}

	.player-item,
	.score-item {
		display: flex;
		align-items: center;
		gap: 0.75rem;
	}

	.player-color {
		width: 1rem;
		height: 1rem;
		border-radius: 50%;
		flex-shrink: 0;
	}

	.player-color.large {
		width: 1.5rem;
		height: 1.5rem;
	}

	.player-avatar {
		width: 2rem;
		height: 2rem;
		border-radius: 50%;
	}

	.player-avatar-placeholder {
		width: 2rem;
		height: 2rem;
		border-radius: 50%;
		background: #374151;
		display: flex;
		align-items: center;
		justify-content: center;
		font-size: 0.875rem;
	}

	.player-name,
	.score-name {
		flex: 1;
		text-align: left;
	}

	.badge {
		font-size: 0.75rem;
		margin-left: 0.25rem;
	}

	.badge.host {
		color: #fbbf24;
	}

	.badge.you {
		color: #60a5fa;
	}

	.score-rank {
		color: #9ca3af;
		width: 1.5rem;
	}

	.score-value {
		font-weight: bold;
	}

	.btn {
		padding: 0.75rem 1.5rem;
		border-radius: 0.5rem;
		font-weight: 600;
		border: none;
		cursor: pointer;
		transition: all 0.15s ease;
	}

	.btn-primary {
		background: #3b82f6;
		color: white;
	}

	.btn-primary:hover {
		background: #2563eb;
	}

	.btn-start {
		background: #22c55e;
		color: white;
		padding: 1rem 2rem;
		font-size: 1.25rem;
	}

	.btn-start:hover:not(:disabled) {
		background: #16a34a;
	}

	.btn-start:disabled {
		background: #4b5563;
		cursor: not-allowed;
	}

	.btn-text {
		background: none;
		border: none;
		color: #9ca3af;
		cursor: pointer;
		margin-top: 1rem;
	}

	.btn-text:hover {
		color: white;
	}

	.winner-section {
		margin-bottom: 2rem;
		text-align: center;
	}

	.winner-label {
		font-size: 1.25rem;
		color: #9ca3af;
		margin-bottom: 0.5rem;
	}

	.winner-display {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.75rem;
	}

	.winner-name {
		font-size: 2rem;
		font-weight: bold;
	}

	.winner-you {
		font-size: 1.5rem;
	}
</style>
