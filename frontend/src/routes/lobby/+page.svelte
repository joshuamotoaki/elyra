<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { goto } from '$app/navigation';
	import { auth } from '$lib/stores/auth.svelte';
	import { elyraClient } from '$lib/api';
	import type { Match } from '$lib/api/types/match';
	import { PageBackground, Header } from '$lib/components/layout';
	import { Card, Button, Input, Toggle, Avatar } from '$lib/components/ui';
	import { SpinnerGap, GameController, ArrowsClockwise } from 'phosphor-svelte';

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

<PageBackground variant="static">
	<div class="min-h-screen">
		<!-- Header -->
		<Header user={auth.user} onLogout={handleLogout} />

		<!-- Main Content -->
		<div class="max-w-4xl mx-auto px-6 pb-12">
			<!-- Page Title -->
			<div class="mb-8">
				<h2 class="text-2xl font-semibold text-slate-800">Game Lobby</h2>
				<p class="text-slate-600">Create or join a match to play</p>
			</div>

			<!-- Error Display -->
			{#if error}
				<Card variant="flat" padding="md" class="mb-6 border border-error bg-error/10">
					<p class="text-error font-medium">{error}</p>
				</Card>
			{/if}

			<!-- Create / Join Section -->
			<div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
				<!-- Create Match -->
				<Card variant="elevated" padding="lg">
					<h3 class="text-lg font-semibold text-slate-800 mb-2">Create Match</h3>
					<p class="text-slate-500 text-sm mb-6">
						Start a new game and invite friends with your match code.
					</p>

					<!-- Public/Private Toggle -->
					<div class="mb-6">
						<Toggle
							bind:checked={isPublic}
							label={isPublic ? 'Public Match' : 'Private Match'}
							description={isPublic ? 'Anyone can see and join' : 'Join by code only'}
						/>
					</div>

					<Button
						onclick={createMatch}
						disabled={isCreating}
						loading={isCreating}
						variant="primary"
						size="lg"
						class="w-full"
					>
						Create Match
					</Button>
				</Card>

				<!-- Join by Code -->
				<Card variant="elevated" padding="lg">
					<h3 class="text-lg font-semibold text-slate-800 mb-2">Join by Code</h3>
					<p class="text-slate-500 text-sm mb-6">
						Enter a 6-character code to join a friend's game.
					</p>
					<div class="flex gap-3">
						<div class="flex-1">
							<Input
								bind:value={joinCode}
								placeholder="ABC123"
								maxlength={6}
								class="uppercase tracking-widest text-center font-mono text-lg"
							/>
						</div>
						<Button
							onclick={joinByCode}
							disabled={isJoining || !joinCode.trim()}
							loading={isJoining}
							variant="secondary"
							size="lg"
						>
							Join
						</Button>
					</div>
				</Card>
			</div>

			<!-- Available Matches -->
			<Card variant="elevated" padding="lg">
				<div class="flex items-center justify-between mb-6">
					<div>
						<h3 class="text-lg font-semibold text-slate-800">Available Matches</h3>
						<p class="text-slate-500 text-sm">Public games you can join</p>
					</div>
					<Button onclick={loadMatches} disabled={isLoading} variant="ghost" size="sm">
						{#if isLoading}
							<SpinnerGap class="animate-spin mr-2" size={16} />
							Loading
						{:else}
							<ArrowsClockwise class="mr-2" size={16} />
							Refresh
						{/if}
					</Button>
				</div>

				{#if isLoading}
					<div class="text-center py-12">
						<div class="inline-flex items-center gap-2 text-slate-500">
							<SpinnerGap class="animate-spin" size={20} />
							<span>Loading matches...</span>
						</div>
					</div>
				{:else if matches.length === 0}
					<div class="text-center py-12">
						<div
							class="w-16 h-16 mx-auto mb-4 rounded-full bg-slate-100 flex items-center justify-center"
						>
							<GameController class="text-slate-400" size={32} />
						</div>
						<p class="text-slate-600 font-medium">No matches available</p>
						<p class="text-slate-500 text-sm mt-1">Create one to get started!</p>
					</div>
				{:else}
					<div class="space-y-3">
						{#each matches as match}
							<div
								class="flex items-center justify-between bg-slate-50 rounded-xl px-4 py-3 border border-slate-100 hover:border-slate-200 transition-colors"
							>
								<div class="flex items-center gap-4">
									<Avatar
										src={match.host.picture}
										fallback={match.host.username || match.host.name || '?'}
										size="md"
									/>
									<div>
										<div class="font-medium text-slate-700">
											{match.host.username || match.host.name || 'Unknown'}'s game
										</div>
										<div class="text-sm text-slate-500">
											{match.player_count}/4 players
											<span class="mx-2 text-slate-300">&bull;</span>
											<span class="font-mono text-xs bg-slate-200 px-2 py-0.5 rounded"
												>{match.code}</span
											>
										</div>
									</div>
								</div>
								<Button onclick={() => joinMatch(match.id)} variant="primary" size="sm">
									Join
								</Button>
							</div>
						{/each}
					</div>
				{/if}
			</Card>
		</div>
	</div>
</PageBackground>
