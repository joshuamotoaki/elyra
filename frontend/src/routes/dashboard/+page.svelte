<script lang="ts">
	import { goto } from '$app/navigation';
	import { onMount } from 'svelte';

	onMount(() => {
		goto('/lobby');
	});
</script>

<div class="flex min-h-screen items-center justify-center bg-gray-900">
	<p class="text-gray-400">Redirecting...</p>
</div>
