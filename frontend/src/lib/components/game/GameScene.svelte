<script lang="ts">
	import { T, useThrelte } from '@threlte/core';
	import { OrbitControls } from '@threlte/extras';
	import * as THREE from 'three';
	import { gameStore } from '$lib/stores/game.svelte';
	import { socketService } from '$lib/api/services/SocketService';
	import TileGrid from './TileGrid.svelte';
	import PlayerAvatar from './PlayerAvatar.svelte';
	import BeamEffect from './BeamEffect.svelte';

	// Camera is centered on the map
	const mapCenter = 25; // Center of 50x50 grid
	const cameraHeight = 80;
	const cameraDistance = 60;

	// Get threlte context for raycasting
	const { camera, renderer } = useThrelte();

	// Raycaster for mouse-to-world conversion
	const raycaster = new THREE.Raycaster();
	const groundPlane = new THREE.Plane(new THREE.Vector3(0, 1, 0), 0);
	const mouse = new THREE.Vector2();
	const worldPoint = new THREE.Vector3();

	// Handle mouse click for shooting
	function handleClick(event: MouseEvent) {
		// Only shoot on left click when not panning
		if (event.button !== 0) return;

		// Don't shoot if game isn't playing
		if (gameStore.status !== 'playing') return;

		const player = gameStore.localPlayer;
		if (!player) return;

		// Get canvas bounds
		const canvas = renderer.domElement;
		const rect = canvas.getBoundingClientRect();

		// Convert mouse position to normalized device coordinates (-1 to +1)
		mouse.x = ((event.clientX - rect.left) / rect.width) * 2 - 1;
		mouse.y = -((event.clientY - rect.top) / rect.height) * 2 + 1;

		// Update raycaster with camera and mouse position
		const cam = camera.current;
		if (!cam) return;

		raycaster.setFromCamera(mouse, cam);

		// Find where the ray intersects the ground plane (y=0)
		const hit = raycaster.ray.intersectPlane(groundPlane, worldPoint);
		if (!hit) return;

		// Calculate direction from player to click point
		// Player position is (localVisualX, 0, localVisualY) in 3D space
		const playerX = gameStore.localVisualX;
		const playerZ = gameStore.localVisualY;

		const dx = worldPoint.x - playerX;
		const dz = worldPoint.z - playerZ;

		// Normalize the direction
		const length = Math.sqrt(dx * dx + dz * dz);
		if (length < 0.1) return;

		const dirX = dx / length;
		const dirY = dz / length; // Note: Z in 3D maps to Y in 2D game coords

		socketService.shoot(dirX, dirY);
	}

	// Handle spacebar for shooting (shoot towards center of view)
	function handleKeyDown(event: KeyboardEvent) {
		if (event.code === 'Space' && gameStore.status === 'playing') {
			event.preventDefault();
			// Shoot towards center of screen (simulate click at center)
			const canvas = renderer.domElement;
			const rect = canvas.getBoundingClientRect();
			const centerX = rect.left + rect.width / 2;
			const centerY = rect.top + rect.height / 2;

			handleClick({
				button: 0,
				clientX: centerX,
				clientY: centerY
			} as MouseEvent);
		}
	}
</script>

<svelte:window onkeydown={handleKeyDown} />

<!-- Invisible ground plane for click detection -->
<T.Mesh
	position={[mapCenter, 0, mapCenter]}
	rotation.x={-Math.PI / 2}
	onclick={handleClick}
	visible={false}
>
	<T.PlaneGeometry args={[200, 200]} />
	<T.MeshBasicMaterial transparent opacity={0} />
</T.Mesh>

<!-- Isometric-style camera centered on map -->
<T.OrthographicCamera
	makeDefault
	position={[mapCenter + cameraDistance, cameraHeight, mapCenter + cameraDistance]}
	zoom={8}
	near={0.1}
	far={1000}
>
	{#snippet children({ ref })}
		<OrbitControls
			enableRotate={false}
			enableZoom={true}
			enablePan={true}
			target={[mapCenter, 0, mapCenter]}
			minZoom={3}
			maxZoom={25}
			panSpeed={1.5}
			zoomSpeed={1.2}
			mouseButtons.LEFT={-1}
			mouseButtons.MIDDLE={2}
			mouseButtons.RIGHT={2}
		/>
	{/snippet}
</T.OrthographicCamera>

<!-- Lighting - Monument Valley style -->
<T.AmbientLight intensity={0.6} color="#ffffff" />
<T.DirectionalLight
	position={[50, 100, 50]}
	intensity={0.8}
	color="#fff5e6"
	castShadow
	shadow.mapSize.width={2048}
	shadow.mapSize.height={2048}
/>

<!-- Background -->
<T.Mesh position={[50, -1, 50]} rotation.x={-Math.PI / 2}>
	<T.PlaneGeometry args={[200, 200]} />
	<T.MeshStandardMaterial color="#1a1a2e" />
</T.Mesh>

<!-- Tile Grid -->
<TileGrid />

<!-- Players -->
{#each gameStore.playerList as player (player.user_id)}
	<PlayerAvatar
		userId={player.user_id}
		color={player.color}
		isLocal={player.user_id === gameStore.localPlayerId}
	/>
{/each}

<!-- Beams -->
{#each gameStore.beams as beam (beam.id)}
	<BeamEffect {beam} />
{/each}
