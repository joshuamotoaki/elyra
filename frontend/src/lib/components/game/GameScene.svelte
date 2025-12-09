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
	const mapCenter = 15; // Center of 30x30 grid
	const cameraHeight = 40;
	const cameraDistance = 28;

	// Get threlte context for raycasting
	const { camera, renderer } = useThrelte();

	// Raycaster for mouse-to-world conversion
	const raycaster = new THREE.Raycaster();
	const groundPlane = new THREE.Plane(new THREE.Vector3(0, 1, 0), 0);
	const mouse = new THREE.Vector2();
	const worldPoint = new THREE.Vector3();

	// Track current mouse position
	let mouseClientX = 0;
	let mouseClientY = 0;

	function handleMouseMove(event: MouseEvent) {
		mouseClientX = event.clientX;
		mouseClientY = event.clientY;
	}

	// Shoot towards mouse cursor position
	function shootTowardsCursor() {
		if (gameStore.status !== 'playing') return;

		const player = gameStore.localPlayer;
		if (!player) return;

		const canvas = renderer.domElement;
		const rect = canvas.getBoundingClientRect();

		// Convert mouse position to normalized device coordinates (-1 to +1)
		mouse.x = ((mouseClientX - rect.left) / rect.width) * 2 - 1;
		mouse.y = -((mouseClientY - rect.top) / rect.height) * 2 + 1;

		const cam = camera.current;
		if (!cam) return;

		raycaster.setFromCamera(mouse, cam);

		// Find where the ray intersects the ground plane (y=0)
		const hit = raycaster.ray.intersectPlane(groundPlane, worldPoint);
		if (!hit) return;

		// Calculate direction from player to cursor point
		const playerX = gameStore.localVisualX;
		const playerZ = gameStore.localVisualY;

		const dx = worldPoint.x - playerX;
		const dz = worldPoint.z - playerZ;

		// Normalize the direction
		const length = Math.sqrt(dx * dx + dz * dz);
		if (length < 0.1) return;

		const dirX = dx / length;
		const dirY = dz / length;

		socketService.shoot(dirX, dirY);
	}

	// Handle spacebar for shooting
	function handleKeyDown(event: KeyboardEvent) {
		if (event.code === 'Space' && gameStore.status === 'playing') {
			event.preventDefault();
			shootTowardsCursor();
		}
	}

	// fix camera original position
	let controls: any = $state(undefined);
	$effect(() => {
		if (controls) {
			controls.target.set(mapCenter, 0, mapCenter);
			controls.update();
		}
	});
</script>

<svelte:window onkeydown={handleKeyDown} onmousemove={handleMouseMove} />

<!-- Isometric-style camera centered on map -->
<T.PerspectiveCamera
	makeDefault
	position={[mapCenter + cameraDistance, cameraHeight, mapCenter + cameraDistance]}
	fov={45}
	near={0.1}
	far={1000}
>
	{#snippet children({ ref })}
		<OrbitControls
			bind:ref={controls}
			enableRotate={true}
			enableZoom={true}
			enablePan={false}
			target={[mapCenter, 0, mapCenter]}
			minZoom={3}
			maxZoom={25}
			rotateSpeed={0.5}
			zoomSpeed={1.2}
			minPolarAngle={0.3}
			maxPolarAngle={Math.PI / 2.5}
		/>
	{/snippet}
</T.PerspectiveCamera>

<!-- Lighting - Monument Valley style -->
<T.AmbientLight intensity={0.8} color="#ffffff" />
<T.DirectionalLight
	position={[50, 100, 50]}
	intensity={2}
	color="#fff5e6"
	castShadow
	shadow.mapSize.width={2048}
	shadow.mapSize.height={2048}
/>

<!-- Background -->
<!-- <T.Mesh position={[50, -1, 50]} rotation.x={-Math.PI / 2}>
	<T.PlaneGeometry args={[200, 200]} />
	<T.MeshStandardMaterial color="#64badb" />
</T.Mesh> -->

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
