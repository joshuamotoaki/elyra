<script lang="ts">
	import { T, useTask } from '@threlte/core';
	import * as THREE from 'three';
	import type { Beam } from '$lib/api/types/game';

	interface Props {
		beam: Beam;
	}

	let { beam }: Props = $props();

	// 1. Setup constants
	const beamLength = 1.2;
	const rotation = $derived(Math.atan2(beam.dir_y, beam.dir_x));

	// 2. Create Geometry and Static Materials
	const tipGeom = new THREE.CylinderGeometry(0.2, 0, 0.6, 5);
	const bodyGeom = new THREE.CylinderGeometry(0, 0.2, beamLength, 5);

	// Note: The original had a slightly longer tip (0.6 vs 0.5) for the white inner part.
	// I am reusing the 0.5 geom here for performance, but you can create a second geom if needed.

	const whiteMat = new THREE.MeshStandardMaterial({
		color: 'white',
		emissive: 'white',
		emissiveIntensity: 1,
		flatShading: true
	});

	// 3. References to the dynamic materials
	let coloredMat: THREE.MeshStandardMaterial | undefined = $state();
	let transparentMat: THREE.MeshStandardMaterial | undefined = $state();

	// 4. Optimization: JS-only animation loop
	let time = 0;

	useTask((delta) => {
		if (!coloredMat || !transparentMat) return;

		time += delta * 5;
		const currentGlow = 0.8 + Math.sin(time) * 0.2;

		coloredMat.emissiveIntensity = 2 * currentGlow;
		transparentMat.emissiveIntensity = 2 * currentGlow;
	});
</script>

<T.Group position={[beam.x, 0.3, beam.y]} rotation.y={-rotation} scale={1}>
	<T.Group scale={[1.02, 1, 1.02]}>
		<T.Group rotation.z={Math.PI / 2} rotation.x={Math.PI / 4}>
			<T.Mesh geometry={tipGeom} position.y={-0.3}>
				<T.MeshStandardMaterial
					bind:ref={coloredMat}
					color={beam.color}
					emissive={beam.color}
					emissiveIntensity={2}
					flatShading
					depthWrite={false}
				/>
			</T.Mesh>

			<T.Mesh geometry={bodyGeom} position.y={beamLength / 2}>
				<T.MeshStandardMaterial
					bind:ref={transparentMat}
					color={beam.color}
					emissive={beam.color}
					emissiveIntensity={2}
					transparent
					opacity={0.4}
					flatShading
					depthWrite={false}
				/>
			</T.Mesh>
		</T.Group>
	</T.Group>

	<T.Group scale={[0.8, 1, 0.8]}>
		<T.Group rotation.z={Math.PI / 2} rotation.x={Math.PI / 4}>
			<T.Mesh geometry={tipGeom} material={whiteMat} position.y={-0.3} />
			<T.Mesh geometry={bodyGeom} material={whiteMat} position.y={beamLength / 2} />
		</T.Group>
	</T.Group>
</T.Group>
