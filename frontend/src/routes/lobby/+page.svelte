<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { goto } from '$app/navigation';
	import { auth } from '$lib/stores/auth.svelte';
	import { elyraClient } from '$lib/api';
	import type { Match } from '$lib/api/types/match';

	const AUTO_REFRESH_INTERVAL = 10000; // 10 seconds

	let matches = $state<Match[]>([]);
	let joinCode = $state('');
	let isCreating = $state(false);
	let isJoining = $state(false);
	let isLoading = $state(true);
	let isPublic = $state(true);
	let error = $state<string | null>(null);
	let refreshInterval: ReturnType<typeof setInterval> | null = null;

	function handleLogout() {
		auth.logout();
		goto('/');
	}

	onMount(async () => {
		// Check auth
		if (!auth.token) {
			goto('/');
			return;
		}

		await auth.loadUser();
		if (!auth.isAuthenticated) {
			goto('/');
			return;
		}
		if (auth.needsOnboarding) {
			goto('/onboarding');
			return;
		}

		await loadMatches();

		refreshInterval = setInterval(async () => {
			try {
				matches = await elyraClient.matches.listMatches();
			} catch {
				// Silently fail on background refresh
			}
		}, AUTO_REFRESH_INTERVAL);
	});

	onDestroy(() => {
		if (refreshInterval) {
			clearInterval(refreshInterval);
		}
	});

	async function loadMatches() {
		isLoading = true;
		error = null;
		try {
			matches = await elyraClient.matches.listMatches();
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to load matches';
		} finally {
			isLoading = false;
		}
	}

	async function createMatch() {
		isCreating = true;
		error = null;
		try {
			const match = await elyraClient.matches.createMatch({ is_public: isPublic });
			goto(`/match/${match.id}`);
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to create match';
			isCreating = false;
		}
	}

	async function joinByCode() {
		if (!joinCode.trim()) return;

		isJoining = true;
		error = null;
		try {
			const match = await elyraClient.matches.joinByCode({ code: joinCode.trim().toUpperCase() });
			goto(`/match/${match.id}`);
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to join match';
			isJoining = false;
		}
	}

	function joinMatch(matchId: number) {
		goto(`/match/${matchId}`);
	}
</script>

<div class="min-h-screen bg-gray-900 text-white p-8">
	<div class="max-w-4xl mx-auto">
		<!-- Header -->
		<div class="flex items-center justify-between mb-8">
			<h1 class="text-3xl font-bold">Game Lobby</h1>
			{#if auth.user}
				<div class="flex items-center gap-4">
					<div class="flex items-center gap-2">
						{#if auth.user.picture}
							<img src={auth.user.picture} alt="Profile" class="h-8 w-8 rounded-full" />
						{/if}
						<span class="text-gray-300">@{auth.user.username}</span>
					</div>
					<button
						onclick={handleLogout}
						class="rounded bg-gray-700 px-4 py-2 text-sm hover:bg-gray-600 transition-colors"
					>
						Logout
					</button>
				</div>
			{/if}
		</div>

		<!-- Error Display -->
		{#if error}
			<div class="bg-red-900/50 border border-red-500 text-red-200 px-4 py-3 rounded mb-6">
				{error}
			</div>
		{/if}

		<!-- Create / Join Section -->
		<div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
			<!-- Create Match -->
			<div class="bg-gray-800 rounded-lg p-6">
				<h2 class="text-xl font-semibold mb-4">Create Match</h2>
				<p class="text-gray-400 mb-4">Start a new game and invite friends with your match code.</p>

				<!-- Public/Private Toggle -->
				<div class="flex items-center justify-between mb-4 p-3 bg-gray-700 rounded-lg">
					<div>
						<div class="font-medium">{isPublic ? 'Public Match' : 'Private Match'}</div>
						<div class="text-sm text-gray-400">
							{isPublic ? 'Anyone can see and join' : 'Join by code only'}
						</div>
					</div>
					<button
						onclick={() => (isPublic = !isPublic)}
						class="relative w-12 h-6 rounded-full transition-colors {isPublic
							? 'bg-blue-600'
							: 'bg-gray-600'}"
						type="button"
						role="switch"
						aria-checked={isPublic}
						aria-label="Toggle match visibility"
					>
						<span
							class="absolute top-1 left-1 w-4 h-4 bg-white rounded-full transition-transform {isPublic
								? 'translate-x-6'
								: 'translate-x-0'}"
						></span>
					</button>
				</div>

				<button
					onclick={createMatch}
					disabled={isCreating}
					class="w-full bg-blue-600 hover:bg-blue-700 disabled:bg-blue-800 disabled:cursor-not-allowed text-white font-semibold py-3 px-6 rounded-lg transition-colors"
				>
					{isCreating ? 'Creating...' : 'Create Match'}
				</button>
			</div>

			<!-- Join by Code -->
			<div class="bg-gray-800 rounded-lg p-6">
				<h2 class="text-xl font-semibold mb-4">Join by Code</h2>
				<p class="text-gray-400 mb-4">Enter a 6-character code to join a friend's game.</p>
				<div class="flex gap-2">
					<input
						type="text"
						bind:value={joinCode}
						placeholder="ABC123"
						maxlength="6"
						class="flex-1 bg-gray-700 border border-gray-600 rounded-lg px-4 py-3 text-white uppercase tracking-widest text-center font-mono text-lg focus:outline-none focus:border-blue-500"
					/>
					<button
						onclick={joinByCode}
						disabled={isJoining || !joinCode.trim()}
						class="bg-green-600 hover:bg-green-700 disabled:bg-gray-600 disabled:cursor-not-allowed text-white font-semibold py-3 px-6 rounded-lg transition-colors"
					>
						{isJoining ? '...' : 'Join'}
					</button>
				</div>
			</div>
		</div>

		<!-- Available Matches -->
		<div class="bg-gray-800 rounded-lg p-6">
			<div class="flex items-center justify-between mb-4">
				<h2 class="text-xl font-semibold">Available Matches</h2>
				<button onclick={loadMatches} disabled={isLoading} class="text-gray-400 hover:text-white">
					{isLoading ? 'Loading...' : 'Refresh'}
				</button>
			</div>

			{#if isLoading}
				<div class="text-center py-8 text-gray-400">Loading matches...</div>
			{:else if matches.length === 0}
				<div class="text-center py-8 text-gray-400">
					No matches available. Create one to get started!
				</div>
			{:else}
				<div class="space-y-3">
					{#each matches as match}
						<div
							class="flex items-center justify-between bg-gray-700 rounded-lg px-4 py-3 hover:bg-gray-650"
						>
							<div class="flex items-center gap-4">
								{#if match.host.picture}
									<img src={match.host.picture} alt="" class="w-10 h-10 rounded-full" />
								{:else}
									<div class="w-10 h-10 rounded-full bg-gray-600 flex items-center justify-center">
										{(match.host.username || match.host.name || '?')[0].toUpperCase()}
									</div>
								{/if}
								<div>
									<div class="font-medium">
										{match.host.username || match.host.name || 'Unknown'}'s game
									</div>
									<div class="text-sm text-gray-400">
										{match.player_count}/4 players &bull; Code: {match.code}
									</div>
								</div>
							</div>
							<button
								onclick={() => joinMatch(match.id)}
								class="bg-blue-600 hover:bg-blue-700 text-white font-medium py-2 px-4 rounded-lg transition-colors"
							>
								Join
							</button>
						</div>
					{/each}
				</div>
			{/if}
		</div>
	</div>
</div>
