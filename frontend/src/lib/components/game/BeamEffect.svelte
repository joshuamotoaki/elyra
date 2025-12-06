<script lang="ts">
	import { T, useTask } from '@threlte/core';
	import * as THREE from 'three';
	import type { Beam } from '$lib/api/types/game';

	interface Props {
		beam: Beam;
	}

	let { beam }: Props = $props();

	// Beam visual length
	const beamLength = 2;

	// Calculate rotation to face beam direction
	let rotation = $derived(Math.atan2(beam.dir_y, beam.dir_x));

	// Animated glow
	let glowIntensity = $state(1);
	let time = $state(0);

	useTask((delta) => {
		time += delta * 10;
		glowIntensity = 0.8 + Math.sin(time) * 0.2;
	});
</script>

<T.Group position={[beam.x, 0.3, beam.y]} rotation.y={-rotation}>
	<!-- Main beam cylinder -->
	<T.Mesh rotation.z={Math.PI / 2}>
		<T.CylinderGeometry args={[0.08, 0.08, beamLength, 8]} />
		<T.MeshStandardMaterial
			color={beam.color}
			emissive={beam.color}
			emissiveIntensity={glowIntensity}
		/>
	</T.Mesh>

	<!-- Glow effect -->
	<T.PointLight color={beam.color} intensity={0.3} distance={2} />
</T.Group>
