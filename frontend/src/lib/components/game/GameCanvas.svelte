<script lang="ts">
	import { Canvas } from '@threlte/core';
	import { onMount, onDestroy } from 'svelte';
	import GameScene from './GameScene.svelte';
	import { gameStore } from '$lib/stores/game.svelte';
	import { inputManager } from '$lib/game/input';

	let lastTime = 0;
	let animationId: number;

	function gameLoop(time: number) {
		const dt = lastTime ? (time - lastTime) / 1000 : 0.016;
		lastTime = time;

		// Update local player visual position based on input
		if (gameStore.status === 'playing') {
			gameStore.updateLocalVisualPosition(dt);
		}

		animationId = requestAnimationFrame(gameLoop);
	}

	onMount(() => {
		inputManager.start();
		animationId = requestAnimationFrame(gameLoop);
	});

	onDestroy(() => {
		inputManager.stop();
		if (animationId) {
			cancelAnimationFrame(animationId);
		}
	});
</script>

<div class="game-canvas">
	<Canvas>
		<GameScene />
	</Canvas>
</div>

<style>
	.game-canvas {
		width: 100%;
		height: 100%;
		position: absolute;
		inset: 0;
	}
</style>
