<script lang="ts">
	import type { Snippet } from 'svelte';

	interface Props {
		variant?: 'vivid' | 'soft';
		children: Snippet;
	}

	let { variant = 'soft', children }: Props = $props();
</script>

<div
	class="relative min-h-screen overflow-hidden {variant === 'vivid'
		? 'bg-sky-gradient-vivid'
		: 'bg-sky-gradient-soft'}"
>
	{@render children()}
</div>
