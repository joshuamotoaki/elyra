<script lang="ts">
	import { T, useTask } from '@threlte/core';
	import * as THREE from 'three';
	import { gameStore } from '$lib/stores/game.svelte';

	interface Props {
		userId: number;
		color: string;
		isLocal: boolean;
	}

	let { userId, color, isLocal }: Props = $props();

	// Smooth position for rendering
	let displayX = $state(0);
	let displayY = $state(0);
	let displayZ = $state(0);

	let indicatorRotation = $state(0);

	// Glow ring rotation
	let glowRotation = $state(0);

	// Update position each frame
	useTask((delta) => {
		if (isLocal) {
			// Local player uses visual position for immediate feedback
			displayX = gameStore.localVisualX;
			displayZ = gameStore.localVisualY;

			const dx = gameStore.cursorWorldPosition.x - displayX;
			const dz = gameStore.cursorWorldPosition.z - displayZ;

			// 2. Calculate angle (atan2 is perfect for X/Y coordinates)
			// We subtract Math.PI/2 because the cylinder geometry is likely
			// oriented incorrectly by default. You might need to tweak this offset.
			indicatorRotation = Math.atan2(dz, dx);
		} else {
			// Remote players use interpolated position
			const interp = gameStore.getInterpolatedPosition(userId);
			if (interp) {
				displayX = interp.x;
				displayZ = interp.y;
			}
		}

		// Animate glow ring
		glowRotation += delta * 2;
	});

	// Get player data
	let player = $derived(gameStore.players.get(userId));
	let glowRadius = $derived(player?.glow_radius ?? 1.5);

	const WHITE = new THREE.Color(0xffffff);

	// Create a NEW color instance, otherwise we mutate the original if we aren't careful
	// 0.6 means "60% of the way to black"
	let darkColor = $derived(new THREE.Color(color).lerp(WHITE, -0.02));
</script>

{#if player}
	<T.Group position={[displayX, 0, displayZ]}>
		<!-- Player body (capsule) -->
		<T.Mesh position.y={0.4}>
			<T.CapsuleGeometry args={[0.4, 0.6, 8, 16]} />
			<T.MeshStandardMaterial {color} />
		</T.Mesh>

		<!-- Direction indicator -->
		<T.Group position={[0, 0.6, 0]} rotation.y={-indicatorRotation}>
			<T.Mesh position.x={0.4} rotation.z={Math.PI / 2}>
				<T.CylinderGeometry args={[0.15, 0.15, 0.4]} />
				<T.MeshStandardMaterial {color} />
			</T.Mesh>
		</T.Group>

		<!-- Glow radius indicator (ring on ground) -->
		<T.Mesh position.y={0.06} rotation.x={-Math.PI / 2} rotation.z={glowRotation}>
			<T.RingGeometry args={[glowRadius - 0.05, glowRadius, 32]} />
			<T.MeshBasicMaterial color={darkColor} transparent opacity={0.8} side={THREE.DoubleSide} />
		</T.Mesh>

		<!-- Local player highlight -->
		{#if isLocal}
			<T.PointLight position.y={1} intensity={0.5} {color} distance={3} />
		{/if}
	</T.Group>
{/if}
