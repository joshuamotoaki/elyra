<script lang="ts">
	import { T, useTask } from '@threlte/core';
	import * as THREE from 'three';
	import type { Beam } from '$lib/api/types/game';

	interface Props {
		beam: Beam;
	}

	let { beam }: Props = $props();

	// Beam visual length
	const beamLength = 1.2;

	// Calculate rotation to face beam direction
	let rotation = $derived(Math.atan2(beam.dir_y, beam.dir_x));

	// Animated glow
	let glowIntensity = $state(5);
	let time = $state(0);

	useTask((delta) => {
		time += delta * 5;
		glowIntensity = 0.8 + Math.sin(time) * 0.2;
	});
</script>

<T.Group position={[beam.x, 0.3, beam.y]} rotation.y={-rotation} scale={1}>
	<T.Group scale={[1.02, 1, 1.02]}>
		<T.Group rotation.z={Math.PI / 2} rotation.x={Math.PI / 4}>
			<T.Mesh position.y={-0.3}>
				<T.CylinderGeometry args={[0.2, 0, 0.5, 5]} />
				<T.MeshStandardMaterial
					color={beam.color}
					emissive={beam.color}
					emissiveIntensity={2}
					flatShading={true}
					depthWrite={false}
				/>
			</T.Mesh>
			<T.Mesh position.y={beamLength / 2}>
				<T.CylinderGeometry args={[0, 0.2, beamLength, 5]} />
				<T.MeshStandardMaterial
					color={beam.color}
					emissive={beam.color}
					emissiveIntensity={2}
					transparent={true}
					opacity={0.4}
					flatShading={true}
					depthWrite={false}
				/>
			</T.Mesh>
		</T.Group>
	</T.Group>
	<T.Group scale={[0.8, 1, 0.8]}>
		<T.Group rotation.z={Math.PI / 2} rotation.x={Math.PI / 4}>
			<T.Mesh position.y={-0.3}>
				<T.CylinderGeometry args={[0.2, 0, 0.6, 5]} />
				<T.MeshStandardMaterial
					color="white"
					emissive="white"
					emissiveIntensity={1}
					flatShading={true}
				/>
			</T.Mesh>
			<T.Mesh position.y={beamLength / 2}>
				<T.CylinderGeometry args={[0, 0.2, beamLength, 5]} />
				<T.MeshStandardMaterial
					color="white"
					emissive="white"
					emissiveIntensity={1}
					flatShading={true}
				/>
			</T.Mesh>
		</T.Group>
	</T.Group>

	<T.PointLight color={beam.color} intensity={2} distance={4} decay={2} />
</T.Group>
