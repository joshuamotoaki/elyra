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
		// 1. Standard mouse tracking
		mouseClientX = event.clientX;
		mouseClientY = event.clientY;

		// 2. IMMEDIATE Raycasting (formerly in shootTowardsCursor)
		const canvas = renderer.domElement;
		const rect = canvas.getBoundingClientRect();
		const cam = camera.current;

		if (!cam) return;

		// Convert to -1 to +1 coords
		mouse.x = ((mouseClientX - rect.left) / rect.width) * 2 - 1;
		mouse.y = -((mouseClientY - rect.top) / rect.height) * 2 + 1;

		raycaster.setFromCamera(mouse, cam);

		// Intersect with ground
		const hit = raycaster.ray.intersectPlane(groundPlane, worldPoint);

		if (hit) {
			// 3. Update the store immediately
			gameStore.cursorWorldPosition = { x: worldPoint.x, z: worldPoint.z };
		}
	}

	// Shoot towards mouse cursor position
	function shootTowardsCursor() {
		if (gameStore.status !== 'playing') return;

		const player = gameStore.localPlayer;
		if (!player) return;

		// Get player position
		const playerX = gameStore.localVisualX;
		const playerZ = gameStore.localVisualY;

		// Get target from the STORE (updated by handleMouseMove)
		const targetX = gameStore.cursorWorldPosition.x;
		const targetZ = gameStore.cursorWorldPosition.z;

		const dx = targetX - playerX;
		const dz = targetZ - playerZ;

		// Normalize and shoot
		const length = Math.sqrt(dx * dx + dz * dz);
		if (length < 0.1) return;

		socketService.shoot(dx / length, dz / length);
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
	shadow.mapSize.width={1024}
	shadow.mapSize.height={1024}
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
