<script lang="ts">
	import { T } from '@threlte/core';
	import * as THREE from 'three';
	import { gameStore } from '$lib/stores/game.svelte';

	// Colors for different tile states - cached
	const NEUTRAL_COLOR = new THREE.Color('#374151');
	const WALL_COLOR = new THREE.Color('#1f2937');
	const GENERATOR_COLOR = new THREE.Color('#fbbf24');

	// Cache player colors to avoid creating new Color objects
	const colorCache = new Map<string, THREE.Color>();

	function getCachedColor(hexColor: string): THREE.Color {
		let color = colorCache.get(hexColor);
		if (!color) {
			color = new THREE.Color(hexColor);
			colorCache.set(hexColor, color);
		}
		return color;
	}

	// Generate tile instances - pre-split into walkable and walls
	interface TileInstance {
		x: number;
		y: number;
		key: string;
		type: string;
	}

	// Render all tiles since camera shows the full map
	let walkableTiles = $derived.by(() => {
		const result: TileInstance[] = [];
		const gridSize = gameStore.gridSize;

		for (let x = 0; x < gridSize; x++) {
			for (let y = 0; y < gridSize; y++) {
				const key = `${x},${y}`;
				const type = gameStore.mapTiles.get(key) || 'walkable';
				if (type === 'walkable' || type === 'generator') {
					result.push({ x, y, key, type });
				}
			}
		}
		return result;
	});

	let wallTiles = $derived.by(() => {
		const result: TileInstance[] = [];
		const gridSize = gameStore.gridSize;

		for (let x = 0; x < gridSize; x++) {
			for (let y = 0; y < gridSize; y++) {
				const key = `${x},${y}`;
				const type = gameStore.mapTiles.get(key) || 'walkable';
				if (type === 'wall' || type === 'mirror_ne' || type === 'mirror_nw') {
					result.push({ x, y, key, type });
				}
			}
		}
		return result;
	});

	// Get color for a tile - uses cached colors
	function getTileColor(key: string, type: string): THREE.Color {
		if (type === 'generator') {
			return GENERATOR_COLOR;
		}

		const owner = gameStore.tileOwners.get(key);
		if (owner !== null && owner !== undefined) {
			const player = gameStore.players.get(owner);
			if (player) {
				return getCachedColor(player.color);
			}
		}

		return NEUTRAL_COLOR;
	}
</script>

<!-- Render walkable tiles and generators -->
{#each walkableTiles as tile (tile.key)}
	{@const color = getTileColor(tile.key, tile.type)}
	<T.Mesh position={[tile.x, 0, tile.y]}>
		<T.BoxGeometry args={[0.95, 0.1, 0.95]} />
		<T.MeshStandardMaterial {color} />
	</T.Mesh>
{/each}

<!-- Render walls -->
{#each wallTiles as tile (tile.key)}
	<T.Mesh position={[tile.x, 0.25, tile.y]}>
		<T.BoxGeometry args={[0.95, 0.5, 0.95]} />
		<T.MeshStandardMaterial color={WALL_COLOR} />
	</T.Mesh>
{/each}

<!-- Generator glow indicators -->
{#each gameStore.generators as gen}
	{@const genKey = `${gen.x},${gen.y}`}
	{@const owner = gameStore.tileOwners.get(genKey)}
	{@const ownerColor = owner ? gameStore.getPlayerColor(owner) : '#fbbf24'}
	<T.Mesh position={[gen.x, 0.2, gen.y]}>
		<T.CylinderGeometry args={[0.3, 0.3, 0.3, 8]} />
		<T.MeshStandardMaterial color={ownerColor} emissive={ownerColor} emissiveIntensity={0.5} />
	</T.Mesh>
{/each}
