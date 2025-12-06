<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { goto } from '$app/navigation';
	import { page } from '$app/stores';
	import { auth } from '$lib/stores/auth.svelte';
	import { matchStore } from '$lib/stores/match.svelte';

	const matchId = $derived(Number($page.params.id));
	const isHost = $derived(auth.user?.id === matchStore.hostId);
	const currentUserId = $derived(auth.user?.id);

	// Get winner info (use finalPlayers for results screen)
	const winner = $derived(
		matchStore.winnerId ? matchStore.finalPlayers[matchStore.winnerId] : null
	);

	// Sort players by score for leaderboard (use finalPlayerList for results screen)
	const sortedPlayers = $derived(matchStore.finalPlayerList.toSorted((a, b) => b.score - a.score));

	onMount(async () => {
		if (!auth.token) {
			goto('/');
			return;
		}

		// Connect and join match
		matchStore.connect(auth.token);

		try {
			await matchStore.joinMatch(matchId);
		} catch (e) {
			console.error('Failed to join match:', e);
			goto('/lobby');
		}
	});

	onDestroy(() => {
		matchStore.leaveMatch();
	});

	function handleCellClick(row: number, col: number) {
		matchStore.clickCell(row, col);
	}

	function getCellColor(row: number, col: number): string | null {
		const key = `${row},${col}`;
		const ownerId = matchStore.grid[key];
		if (ownerId && matchStore.players[ownerId]) {
			return matchStore.players[ownerId].color;
		}
		return null;
	}

	function getFinalCellColor(row: number, col: number): string | null {
		const key = `${row},${col}`;
		const ownerId = matchStore.finalGrid[key];
		if (ownerId && matchStore.finalPlayers[ownerId]) {
			return matchStore.finalPlayers[ownerId].color;
		}
		return null;
	}

	function returnToLobby() {
		matchStore.leaveMatch();
		goto('/lobby');
	}

	async function startGame() {
		try {
			await matchStore.startGame();
		} catch (e) {
			console.error('Failed to start game:', e);
		}
	}
</script>

<div class="min-h-screen bg-gray-900 text-white p-4 md:p-8">
	<div class="max-w-4xl mx-auto">
		{#if matchStore.isConnecting}
			<!-- Loading State -->
			<div class="text-center py-20">
				<div class="text-2xl mb-4">Connecting to match...</div>
			</div>
		{:else if matchStore.error}
			<!-- Error State -->
			<div class="text-center py-20">
				<div class="text-2xl mb-4 text-red-400">Error: {matchStore.error}</div>
				<button
					onclick={returnToLobby}
					class="bg-blue-600 hover:bg-blue-700 text-white font-semibold py-3 px-6 rounded-lg"
				>
					Return to Lobby
				</button>
			</div>
		{:else if matchStore.status === 'waiting'}
			<!-- Waiting Room -->
			<div class="text-center">
				<h1 class="text-3xl font-bold mb-2">Waiting for Players</h1>
				<div class="text-4xl font-mono text-blue-400 mb-6">{matchStore.code}</div>
				<p class="text-gray-400 mb-8">Share this code with friends to join!</p>

				<!-- Players -->
				<div class="bg-gray-800 rounded-lg p-6 mb-6 max-w-md mx-auto">
					<h2 class="text-xl font-semibold mb-4">
						Players ({matchStore.playerCount}/4)
					</h2>
					<div class="space-y-3">
						{#each matchStore.playerList as player}
							<div class="flex items-center gap-3">
								<div class="w-4 h-4 rounded-full" style="background-color: {player.color}"></div>
								{#if player.picture}
									<img src={player.picture} alt="" class="w-8 h-8 rounded-full" />
								{:else}
									<div
										class="w-8 h-8 rounded-full bg-gray-600 flex items-center justify-center text-sm"
									>
										{(player.username || '?')[0].toUpperCase()}
									</div>
								{/if}
								<span class="flex-1 text-left">
									{player.username || 'Player'}
									{#if player.user_id === matchStore.hostId}
										<span class="text-yellow-400 text-sm">(Host)</span>
									{/if}
									{#if player.user_id === currentUserId}
										<span class="text-blue-400 text-sm">(You)</span>
									{/if}
								</span>
							</div>
						{/each}
					</div>
				</div>

				<!-- Start Button (Host Only) -->
				{#if isHost}
					<button
						onclick={startGame}
						disabled={matchStore.playerCount < 2}
						class="bg-green-600 hover:bg-green-700 disabled:bg-gray-600 disabled:cursor-not-allowed text-white font-bold py-4 px-8 rounded-lg text-xl transition-colors"
					>
						{matchStore.playerCount < 2 ? 'Need at least 2 players' : 'Start Game'}
					</button>
				{:else}
					<p class="text-gray-400">Waiting for host to start the game...</p>
				{/if}

				<button onclick={returnToLobby} class="block mx-auto mt-6 text-gray-400 hover:text-white">
					Leave Match
				</button>
			</div>
		{:else if matchStore.status === 'playing'}
			<!-- Game View -->
			<div>
				<!-- Header -->
				<div class="flex items-center justify-between mb-6">
					<div class="text-lg">
						Code: <span class="font-mono text-blue-400">{matchStore.code}</span>
					</div>
					<div class="text-4xl font-bold font-mono tabular-nums">
						{matchStore.timeRemaining}s
					</div>
				</div>

				<!-- Players Sidebar -->
				<div class="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
					{#each matchStore.playerList as player}
						<div
							class="flex items-center gap-2 bg-gray-800 rounded-lg px-3 py-2"
							style="border-left: 4px solid {player.color}"
						>
							<span class="flex-1 truncate text-sm">
								{player.username || 'Player'}
								{#if player.user_id === currentUserId}
									<span class="text-blue-400">(You)</span>
								{/if}
							</span>
						</div>
					{/each}
				</div>

				<!-- Game Grid -->
				<div
					class="grid gap-2 mx-auto"
					style="grid-template-columns: repeat({matchStore.gridSize}, 1fr); max-width: {matchStore.gridSize *
						80}px"
				>
					{#each Array(matchStore.gridSize) as _, row}
						{#each Array(matchStore.gridSize) as _, col}
							{@const cellColor = getCellColor(row, col)}
							<button
								onclick={() => handleCellClick(row, col)}
								class="aspect-square rounded-lg border-2 border-gray-600 hover:border-gray-400 transition-all duration-150 cursor-pointer"
								style={cellColor ? `background-color: ${cellColor}` : 'background-color: #374151'}
							></button>
						{/each}
					{/each}
				</div>

				<p class="text-center text-gray-400 mt-4">Click cells to claim them!</p>
			</div>
		{:else}
			<!-- Game Over -->
			<div class="text-center">
				<h1 class="text-4xl font-bold mb-2">Game Over!</h1>

				{#if winner}
					<div class="mb-8">
						<div class="text-xl text-gray-400 mb-2">Winner</div>
						<div class="flex items-center justify-center gap-3">
							<div class="w-6 h-6 rounded-full" style="background-color: {winner.color}"></div>
							<span class="text-3xl font-bold">{winner.username || 'Player'}</span>
							{#if winner.user_id === currentUserId}
								<span class="text-2xl">That's you!</span>
							{/if}
						</div>
					</div>
				{/if}

				<!-- Final Scores -->
				<div class="bg-gray-800 rounded-lg p-6 mb-8 max-w-md mx-auto">
					<h2 class="text-xl font-semibold mb-4">Final Scores</h2>
					<div class="space-y-3">
						{#each sortedPlayers as player, index}
							<div class="flex items-center gap-3">
								<span class="text-gray-400 w-6">{index + 1}.</span>
								<div class="w-4 h-4 rounded-full" style="background-color: {player.color}"></div>
								<span class="flex-1 text-left">
									{player.username || 'Player'}
									{#if player.user_id === currentUserId}
										<span class="text-blue-400 text-sm">(You)</span>
									{/if}
								</span>
								<span class="font-bold">{player.score}</span>
							</div>
						{/each}
					</div>
				</div>

				<!-- Final Grid Display -->
				<div
					class="grid gap-1 mx-auto mb-8"
					style="grid-template-columns: repeat({matchStore.gridSize}, 1fr); max-width: {matchStore.gridSize *
						40}px"
				>
					{#each Array(matchStore.gridSize) as _, row}
						{#each Array(matchStore.gridSize) as _, col}
							{@const cellColor = getFinalCellColor(row, col)}
							<div
								class="aspect-square rounded"
								style={cellColor ? `background-color: ${cellColor}` : 'background-color: #374151'}
							></div>
						{/each}
					{/each}
				</div>

				<button
					onclick={returnToLobby}
					class="bg-blue-600 hover:bg-blue-700 text-white font-bold py-4 px-8 rounded-lg text-xl transition-colors"
				>
					Return to Lobby
				</button>
			</div>
		{/if}
	</div>
</div>
