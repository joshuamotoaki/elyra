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

	// Glow ring rotation
	let glowRotation = $state(0);

	// Update position each frame
	useTask((delta) => {
		if (isLocal) {
			// Local player uses visual position for immediate feedback
			displayX = gameStore.localVisualX;
			displayZ = gameStore.localVisualY;
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
</script>

{#if player}
	<T.Group position={[displayX, 0, displayZ]}>
		<!-- Player body (capsule) -->
		<T.Mesh position.y={0.4}>
			<T.CapsuleGeometry args={[0.2, 0.4, 8, 16]} />
			<T.MeshStandardMaterial {color} />
		</T.Mesh>

		<!-- Direction indicator -->
		<T.Mesh position={[0.3, 0.4, 0]} rotation.z={Math.PI / 2}>
			<T.ConeGeometry args={[0.1, 0.2, 8]} />
			<T.MeshStandardMaterial {color} />
		</T.Mesh>

		<!-- Glow radius indicator (ring on ground) -->
		<T.Mesh position.y={0.02} rotation.x={-Math.PI / 2} rotation.z={glowRotation}>
			<T.RingGeometry args={[glowRadius - 0.05, glowRadius, 32]} />
			<T.MeshBasicMaterial {color} transparent opacity={0.3} side={THREE.DoubleSide} />
		</T.Mesh>

		<!-- Local player highlight -->
		{#if isLocal}
			<T.PointLight position.y={1} intensity={0.5} {color} distance={3} />
		{/if}
	</T.Group>
{/if}
