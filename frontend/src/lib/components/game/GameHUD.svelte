<script lang="ts">
	import { gameStore } from '$lib/stores/game.svelte';
	import { socketService } from '$lib/api/services/SocketService';
	import type { PowerUpType } from '$lib/api/types/game';
	import { POWERUP_COSTS } from '$lib/api/types/game';

	let player = $derived(gameStore.localPlayer);

	async function handleBuyPowerUp(type: PowerUpType) {
		try {
			await socketService.buyPowerUp(type);
		} catch (e) {
			console.error('Failed to buy power-up:', e);
		}
	}

	// Power-up display info
	const powerUps: { type: PowerUpType; name: string; icon: string }[] = [
		{ type: 'speed', name: 'Speed', icon: '⚡' },
		{ type: 'radius', name: 'Radius', icon: '🔮' },
		{ type: 'energy', name: 'Energy', icon: '🔋' },
		{ type: 'multishot', name: 'Multi', icon: '🎯' },
		{ type: 'piercing', name: 'Pierce', icon: '💥' },
		{ type: 'beam_speed', name: 'Fast Beam', icon: '💨' }
	];

	function hasPowerUp(type: PowerUpType): boolean {
		if (!player) return false;
		switch (type) {
			case 'multishot':
				return player.has_multishot;
			case 'piercing':
				return player.has_piercing;
			case 'beam_speed':
				return player.has_beam_speed;
			default:
				return false;
		}
	}

	function getStacks(type: PowerUpType): number {
		if (!player) return 0;
		switch (type) {
			case 'speed':
				return player.speed_stacks;
			case 'radius':
				return player.radius_stacks;
			case 'energy':
				return player.energy_stacks;
			default:
				return 0;
		}
	}
</script>

<div class="hud">
	<!-- Timer -->
	<div class="timer">
		{gameStore.formattedTime}
	</div>

	<!-- Player stats -->
	{#if player}
		<div class="stats">
			<!-- Energy bar -->
			<div class="stat-row">
				<span class="stat-label">Energy</span>
				<div class="energy-bar">
					<div
						class="energy-fill"
						style="width: {(player.energy / player.max_energy) * 100}%"
					></div>
				</div>
				<span class="stat-value">{Math.round(player.energy)}/{player.max_energy}</span>
			</div>

			<!-- Coins -->
			<div class="stat-row">
				<span class="stat-label">💰</span>
				<span class="stat-value coins">{Math.round(player.coins)}</span>
			</div>

			<!-- Territory -->
			<div class="stat-row">
				<span class="stat-label">Territory</span>
				<span class="stat-value"
					>{gameStore.getTerritoryPercentage(player.user_id).toFixed(1)}%</span
				>
			</div>
		</div>

		<!-- Power-up shop -->
		<div class="shop">
			<div class="shop-title">Power-ups</div>
			<div class="shop-grid">
				{#each powerUps as pu}
					{@const cost = POWERUP_COSTS[pu.type]}
					{@const owned = hasPowerUp(pu.type)}
					{@const stacks = getStacks(pu.type)}
					{@const canAfford = player.coins >= cost}
					{@const isStackable = ['speed', 'radius', 'energy'].includes(pu.type)}

					<button
						class="powerup-btn"
						class:owned
						class:cant-afford={!canAfford && !owned}
						disabled={owned || !canAfford}
						onclick={() => handleBuyPowerUp(pu.type)}
					>
						<span class="powerup-icon">{pu.icon}</span>
						<span class="powerup-name">{pu.name}</span>
						{#if isStackable && stacks > 0}
							<span class="powerup-stacks">x{stacks}</span>
						{/if}
						{#if !owned}
							<span class="powerup-cost">{cost}💰</span>
						{/if}
					</button>
				{/each}
			</div>
		</div>
	{/if}

	<!-- Player list -->
	<div class="players">
		{#each gameStore.playerList as p}
			{@const territory = gameStore.getTerritoryPercentage(p.user_id)}
			<div class="player-row" class:local={p.user_id === gameStore.localPlayerId}>
				<div class="player-color" style="background-color: {p.color}"></div>
				<span class="player-name">{p.username}</span>
				<span class="player-territory">{territory.toFixed(1)}%</span>
			</div>
		{/each}
	</div>

	<!-- Controls hint -->
	<div class="controls">
		<span>WASD: Move</span>
		<span>Click/Space: Shoot</span>
	</div>
</div>

<style>
	.hud {
		position: fixed;
		inset: 0;
		pointer-events: none;
		padding: 1rem;
		font-family: system-ui, sans-serif;
		color: white;
	}

	.timer {
		position: absolute;
		top: 1rem;
		left: 50%;
		transform: translateX(-50%);
		font-size: 2.5rem;
		font-weight: bold;
		text-shadow: 0 2px 4px rgba(0, 0, 0, 0.5);
	}

	.stats {
		position: absolute;
		top: 1rem;
		left: 1rem;
		background: rgba(0, 0, 0, 0.7);
		padding: 1rem;
		border-radius: 0.5rem;
		pointer-events: auto;
	}

	.stat-row {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		margin-bottom: 0.5rem;
	}

	.stat-label {
		width: 4rem;
		font-size: 0.875rem;
		color: #9ca3af;
	}

	.stat-value {
		font-weight: bold;
	}

	.coins {
		color: #fbbf24;
		font-size: 1.25rem;
	}

	.energy-bar {
		width: 100px;
		height: 8px;
		background: #374151;
		border-radius: 4px;
		overflow: hidden;
	}

	.energy-fill {
		height: 100%;
		background: linear-gradient(90deg, #3b82f6, #60a5fa);
		transition: width 0.1s ease;
	}

	.shop {
		position: absolute;
		bottom: 1rem;
		left: 1rem;
		background: rgba(0, 0, 0, 0.7);
		padding: 1rem;
		border-radius: 0.5rem;
		pointer-events: auto;
	}

	.shop-title {
		font-weight: bold;
		margin-bottom: 0.5rem;
		color: #9ca3af;
	}

	.shop-grid {
		display: grid;
		grid-template-columns: repeat(3, 1fr);
		gap: 0.5rem;
	}

	.powerup-btn {
		display: flex;
		flex-direction: column;
		align-items: center;
		padding: 0.5rem;
		background: #374151;
		border: 1px solid #4b5563;
		border-radius: 0.375rem;
		color: white;
		cursor: pointer;
		transition: all 0.15s ease;
	}

	.powerup-btn:hover:not(:disabled) {
		background: #4b5563;
	}

	.powerup-btn:disabled {
		cursor: not-allowed;
	}

	.powerup-btn.owned {
		background: #166534;
		border-color: #22c55e;
	}

	.powerup-btn.cant-afford {
		opacity: 0.5;
	}

	.powerup-icon {
		font-size: 1.5rem;
	}

	.powerup-name {
		font-size: 0.75rem;
	}

	.powerup-stacks {
		font-size: 0.625rem;
		color: #fbbf24;
	}

	.powerup-cost {
		font-size: 0.625rem;
		color: #9ca3af;
	}

	.players {
		position: absolute;
		top: 1rem;
		right: 1rem;
		background: rgba(0, 0, 0, 0.7);
		padding: 1rem;
		border-radius: 0.5rem;
	}

	.player-row {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.25rem 0;
	}

	.player-row.local {
		font-weight: bold;
	}

	.player-color {
		width: 12px;
		height: 12px;
		border-radius: 50%;
	}

	.player-name {
		flex: 1;
	}

	.player-territory {
		color: #9ca3af;
	}

	.controls {
		position: absolute;
		bottom: 1rem;
		right: 1rem;
		background: rgba(0, 0, 0, 0.5);
		padding: 0.5rem 1rem;
		border-radius: 0.5rem;
		font-size: 0.75rem;
		color: #9ca3af;
		display: flex;
		gap: 1rem;
	}
</style>
