<script lang="ts">
	import { goto } from '$app/navigation';
	import { elyraClient } from '$lib/api';
	import type { Match } from '$lib/api/types/match';
	import { Header, PageBackground } from '$lib/components/layout';
	import { Avatar, Button, Card, Input, Modal, Toggle } from '$lib/components/ui';
	import { auth } from '$lib/stores/auth.svelte';
	import {
		ArrowsClockwise,
		GameController,
		Question,
		SpinnerGap,
		Warning,
		X
	} from 'phosphor-svelte';
	import { onDestroy, onMount } from 'svelte';

	const AUTO_REFRESH_INTERVAL = 10000; // 10 seconds

	let matches = $state<Match[]>([]);
	let joinCode = $state('');
	let isCreating = $state(false);
	let isCreatingSolo = $state(false);
	let isJoining = $state(false);
	let isLoading = $state(true);
	let isPublic = $state(true);
	let error = $state<string | null>(null);
	let refreshInterval: ReturnType<typeof setInterval> | null = null;
	let showWarning = $state(true);
	let showHowToPlay = $state(true);

	const WARNING_DISMISSED_KEY = 'elyra-warning-dismissed';

	function dismissWarning() {
		showWarning = false;
		localStorage.setItem(WARNING_DISMISSED_KEY, 'true');
	}

	function handleLogout() {
		auth.logout();
		goto('/');
	}

	onMount(async () => {
		// Check if warning was previously dismissed
		if (localStorage.getItem(WARNING_DISMISSED_KEY) === 'true') {
			showWarning = false;
		}

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

	async function createSoloMatch() {
		isCreatingSolo = true;
		error = null;
		try {
			const match = await elyraClient.matches.createMatch({ is_public: false, is_solo: true });
			goto(`/match/${match.id}`);
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to create solo match';
			isCreatingSolo = false;
		}
	}
</script>

<PageBackground variant="static">
	<div class="min-h-screen">
		<!-- Header -->
		<Header user={auth.user} onLogout={handleLogout} />

		<!-- Main Content -->
		<div class="max-w-4xl mx-auto px-6 pb-12">
			<!-- Page Title -->
			<div class="mb-8 flex items-start justify-between">
				<div>
					<h2 class="text-2xl font-semibold text-slate-800">Game Lobby</h2>
					<p class="text-slate-600">Create or join a match to play</p>
				</div>
				<Button onclick={() => (showHowToPlay = true)} variant="ghost" size="sm">
					<Question size={18} />
					How to Play
				</Button>
			</div>

			<!-- Visual Effects Warning -->
			{#if showWarning}
				<div
					class="mb-6 flex items-start gap-3 rounded-xl border border-warning/30 bg-warning/10 px-4 py-3"
				>
					<Warning class="text-warning mt-0.5 shrink-0" size={20} weight="fill" />
					<p class="flex-1 text-sm text-slate-700">
						<span class="font-medium">Visual Effects Notice:</span> This game contains bright colors and
						moving laser effects. Player discretion is advised for those with visual sensitivities. While
						gameplay is abstract and non-violent, it includes shooting mechanics and competitive territory
						capture that may not be suitable for all ages.
					</p>
					<button
						onclick={dismissWarning}
						class="shrink-0 p-1 rounded-lg text-slate-500 hover:text-slate-700 hover:bg-warning/20 transition-colors cursor-pointer"
						aria-label="Dismiss warning"
					>
						<X size={18} />
					</button>
				</div>
			{/if}

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
			<Card variant="elevated" padding="lg" class="mb-8">
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

			<!-- Solo Practice -->
			<Card variant="elevated" padding="lg">
				<h3 class="text-lg font-semibold text-slate-800 mb-2">Solo Practice</h3>
				<p class="text-slate-500 text-sm mb-6">
					Practice movement, shooting, and tile capture without opponents or time limits.
				</p>
				<Button
					onclick={createSoloMatch}
					disabled={isCreatingSolo}
					loading={isCreatingSolo}
					variant="secondary"
					size="lg"
					class="w-full"
				>
					Start Solo Practice
				</Button>
			</Card>
		</div>
	</div>
</PageBackground>

<!-- How to Play Modal -->
<Modal bind:open={showHowToPlay} onClose={() => (showHowToPlay = false)} title="How to Play">
	<div class="space-y-4">
		<h2 class="font-semibold text-lg">Objective</h2>
		<p>Capture the highest percentage of territory before time runs out (2 minutes).</p>
		<h2 class="font-semibold text-lg">Game Modes</h2>
		<p>Multiplayer (2-4 players) - Compete for territory in 2-minute matches</p>
		<p>Solo Practice - No time limit, practice mechanics freely</p>
		<h2 class="font-semibold text-lg">Controls</h2>
		<p>WASD or arrow keys - Move your character</p>
		<p>Mouse - Aim direction</p>
		<p>Click and drag - Rotate game board</p>
		<p>Space Bar - Fire a beam</p>
		<h2 class="font-semibold text-lg">Territory Capture</h2>
		<p>Glow Radius - Your character passively captures tiles within a glowing radius</p>
		<p>Beams - Fire energy beams that capture all tiles along their path</p>
		<p>Generators - Control generator tiles for bonus income</p>
		<h2 class="font-semibold text-lg">Map Features</h2>
		<p>Tiles - Walkable and colored same color as player who captured it</p>
		<p>Walls - Block movement and beams</p>
		<p>Mirrors - Reflect beams at 90 degrees</p>
		<p>Generators - Provide bonus income when owned</p>
		<h2 class="font-semibold text-lg">Economy & Power-ups</h2>
		<p>Earn coins from passive income (1 coin/sec) and owning generators (3 coins/sec)</p>
		<p>Spend coins on power-ups:</p>
		<table class="md-table">
			<thead>
				<tr>
					<th>Power-up</th>
					<th>Stackability</th>
					<th>Cost</th>
					<th>Effect</th>
				</tr>
			</thead>

			<tbody
				><tr>
					<td>Speed</td><td>Stackable</td><td>15 + 20 * stack</td><td>+15% movement speed</td></tr
				><tr>
					<td>Radius</td><td>Stackable</td><td>20 + 20 * stack</td><td>+0.25 glow radius</td></tr
				><tr>
					<td>Energy</td><td>Stackable</td><td>20 + 20 * stack</td><td
						>+25 max energy, faster regen</td
					></tr
				><tr>
					<td>Multishot</td><td>One-time purchase</td><td>75</td><td
						>Fire 3 beams in spread pattern</td
					></tr
				><tr>
					<td>Pierce</td><td>One-time purchase</td><td>50</td><td
						>Beams pass through 1 wall
					</td></tr
				><tr>
					<td>Fast Beam</td><td>One-time purchase</td><td>40</td><td>Double beam velocity </td></tr
				></tbody
			>
		</table>
	</div>
</Modal>

<style>
	.md-table {
		border-collapse: collapse;
		margin: 1rem 0;
	}

	.md-table th,
	.md-table td {
		border: 1px solid #ddd;
		padding: 6px 10px;
		white-space: nowrap;
	}

	.md-table thead th {
		font-weight: bold;
		background: #f7f7f7;
	}
</style>
