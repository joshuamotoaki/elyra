<script lang="ts">
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';
	import { PageBackground } from '$lib/components/layout';
	import { Card, Button } from '$lib/components/ui';
	import { Warning, House } from 'phosphor-svelte';
</script>

<PageBackground variant="static">
	<div class="flex min-h-screen flex-col items-center justify-center px-4">
		<Card variant="elevated" padding="lg" class="w-full max-w-md text-center">
			<!-- Error Icon -->
			<div class="w-16 h-16 mx-auto mb-6 rounded-full bg-error/10 flex items-center justify-center">
				<Warning class="text-error" size={32} weight="fill" />
			</div>

			<!-- Error Code -->
			<p class="text-5xl font-bold text-slate-800 mb-2">{$page.status}</p>

			<!-- Error Message -->
			<h1 class="text-xl font-semibold text-slate-700 mb-8">
				{#if $page.status === 404}
					Page not found
				{:else if $page.status === 500}
					Server error
				{:else}
					Something went wrong
				{/if}
			</h1>

			<!-- Return Button -->
			<Button onclick={() => goto('/lobby')} variant="primary" size="lg" class="w-full">
				<House size={20} class="mr-2" />
				Return to Lobby
			</Button>
		</Card>
	</div>
</PageBackground>
