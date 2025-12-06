<script lang="ts">
	import type { Snippet } from 'svelte';

	interface Props {
		variant?: 'animated' | 'static';
		children: Snippet;
	}

	let { variant = 'animated', children }: Props = $props();
</script>

<div class="relative min-h-screen overflow-x-hidden overflow-y-auto bg-slate-100">
	<!-- Base soft gradient -->
	<div class="absolute inset-0 bg-linear-to-br from-teal-100 via-indigo-100 to-purple-100"></div>

	{#if variant === 'animated'}
		<!-- Animated soft pastel orbs -->
		<div
			class="absolute top-[-30%] left-[-20%] w-[70%] h-[70%] rounded-full bg-linear-to-r from-teal-200/60 to-cyan-200/60 blur-3xl animate-aurora-1"
		></div>
		<div
			class="absolute top-[10%] right-[-25%] w-[60%] h-[60%] rounded-full bg-linear-to-r from-violet-200/60 to-purple-200/60 blur-3xl animate-aurora-2"
		></div>
		<div
			class="absolute bottom-[-20%] left-[10%] w-[65%] h-[65%] rounded-full bg-linear-to-r from-pink-200/50 to-rose-200/50 blur-3xl animate-aurora-3"
		></div>
		<div
			class="absolute top-[30%] left-[40%] w-[50%] h-[50%] rounded-full bg-linear-to-r from-sky-200/50 to-indigo-200/50 blur-3xl animate-aurora-4"
		></div>
	{/if}

	<!-- Content -->
	<div class="relative z-10">
		{@render children()}
	</div>
</div>

<style>
	@keyframes aurora-1 {
		0%,
		100% {
			transform: translate(0%, 0%) scale(1);
		}
		33% {
			transform: translate(15%, 10%) scale(1.1);
		}
		66% {
			transform: translate(-5%, -5%) scale(0.95);
		}
	}

	@keyframes aurora-2 {
		0%,
		100% {
			transform: translate(0%, 0%) scale(1);
		}
		33% {
			transform: translate(-20%, 15%) scale(1.15);
		}
		66% {
			transform: translate(10%, -10%) scale(0.9);
		}
	}

	@keyframes aurora-3 {
		0%,
		100% {
			transform: translate(0%, 0%) scale(1);
		}
		33% {
			transform: translate(10%, -15%) scale(1.05);
		}
		66% {
			transform: translate(-15%, 10%) scale(1.1);
		}
	}

	@keyframes aurora-4 {
		0%,
		100% {
			transform: translate(0%, 0%) scale(1);
		}
		33% {
			transform: translate(-10%, 20%) scale(1.2);
		}
		66% {
			transform: translate(15%, -5%) scale(0.85);
		}
	}

	:global(.animate-aurora-1) {
		animation: aurora-1 25s ease-in-out infinite;
	}

	:global(.animate-aurora-2) {
		animation: aurora-2 30s ease-in-out infinite;
	}

	:global(.animate-aurora-3) {
		animation: aurora-3 28s ease-in-out infinite;
	}

	:global(.animate-aurora-4) {
		animation: aurora-4 22s ease-in-out infinite;
	}
</style>
