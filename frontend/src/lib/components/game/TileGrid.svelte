<script lang="ts">
	import { T } from '@threlte/core';
	import * as THREE from 'three';
	import { gameStore } from '$lib/stores/game.svelte';

	// Colors for different tile states - cached
	const NEUTRAL_COLOR = new THREE.Color('#ffffff');
	const WALL_COLOR = new THREE.Color('#8c8d8f');
	const GENERATOR_COLOR = new THREE.Color('#ffffff');

	// 1. Use $state to hold the texture
	let gradientTexture = $state<THREE.Texture | undefined>(undefined);

	// 2. Use $effect instead of $: to generate the texture once
	$effect(() => {
		// Prevent recreating if it already exists
		if (gradientTexture) return;

		const size = 256;
		const canvas = document.createElement('canvas');
		canvas.width = size;
		canvas.height = size;
		const ctx = canvas.getContext('2d')!;

		// Your blue gradient for the mirror
		const gradient = ctx.createLinearGradient(0, 0, 0, size);
		gradient.addColorStop(0, '#51b4da');
		gradient.addColorStop(1, '#d7d9da');

		ctx.fillStyle = gradient;
		ctx.fillRect(0, 0, size, size);

		const tex = new THREE.CanvasTexture(canvas);
		tex.wrapS = tex.wrapT = THREE.ClampToEdgeWrapping;

		// Assign to state
		gradientTexture = tex;
	});

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

	function darken(color: string | THREE.Color | undefined, amount = 0.5) {
		// color: hex string or THREE.Color
		const c = new THREE.Color(color);
		c.multiplyScalar(amount); // 1 = original, 0 = black
		return c;
	}

	const groutGeo = new THREE.BoxGeometry(1.0, 0.1, 1.0);
	const tileGeo = new THREE.BoxGeometry(0.95, 0.1, 0.95);
	const wallGeo = new THREE.BoxGeometry(0.95, 0.5, 0.95);
	const groutMaterial = new THREE.MeshStandardMaterial({ color: '#b7b7b7' });
</script>

<!-- Render walkable tiles and generators -->
{#each walkableTiles as tile (tile.key)}
	{@const color = getTileColor(tile.key, tile.type)}

	<T.Group position={[tile.x, 0, tile.y]}>
		<T.Mesh position={[0, -0.04, 0]} geometry={groutGeo} material={groutMaterial} />

		<T.Mesh position={[0, 0, 0]} geometry={tileGeo}>
			<T.MeshStandardMaterial {color} />
		</T.Mesh>
	</T.Group>
{/each}

<!-- Render walls -->
{#each wallTiles as tile (tile.key)}
	{@const isMirror = tile.type !== 'wall'}

	<T.Group position={[tile.x, 0, tile.y]}>
		<T.Mesh position={[0, -0.04, 0]} geometry={groutGeo} material={groutMaterial} />

		<T.Mesh position={[0, 0.25, 0]} geometry={wallGeo}>
			<T.MeshStandardMaterial
				map={isMirror ? gradientTexture : undefined}
				color={!isMirror ? WALL_COLOR : '#ffffff'}
				roughness={isMirror ? 0.2 : 0.8}
				metalness={isMirror ? 0.5 : 0.1}
			/>
		</T.Mesh>
	</T.Group>
{/each}

<!-- COIN LOOK -->
<!-- <T.CylinderGeometry args={[0.3, 0.3, 0.3, 8]} />
<T.MeshStandardMaterial color={ownerColor} emissive={ownerColor} emissiveIntensity={0.5} /> -->

<!-- Generator glow indicators -->
{#each gameStore.generators as gen}
	{@const genKey = `${gen.x},${gen.y}`}
	{@const owner = gameStore.tileOwners.get(genKey)}
	{@const baseColor = owner ? gameStore.getPlayerColor(owner) : GENERATOR_COLOR}
	{@const ownerColor = owner ? darken(baseColor, 0.35) : baseColor}
	<T.Mesh position={[gen.x, 0.1, gen.y]}>
		<T.BoxGeometry args={[0.4, 0.4, 0.4]} />
		<T.MeshStandardMaterial color={ownerColor} emissive={ownerColor} emissiveIntensity={0.4} />
	</T.Mesh>
{/each}
