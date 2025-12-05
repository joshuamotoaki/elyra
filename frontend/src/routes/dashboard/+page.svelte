<script lang="ts">
	import { auth } from '$lib/stores/auth.svelte';
	import { goto } from '$app/navigation';
	import { onMount } from 'svelte';

	onMount(async () => {
		await auth.loadUser();
		if (!auth.isAuthenticated) {
			goto('/');
		} else if (auth.needsOnboarding) {
			goto('/onboarding');
		}
	});

	function handleLogout() {
		auth.logout();
		goto('/');
	}
</script>

{#if auth.isLoading}
	<div class="flex min-h-screen items-center justify-center bg-gray-50">
		<p class="text-gray-600">Loading...</p>
	</div>
{:else if auth.user}
	<div class="min-h-screen bg-gray-50 p-8">
		<header class="flex items-center justify-between">
			<h1 class="text-2xl font-bold text-gray-900">Dashboard</h1>
			<div class="flex items-center gap-4">
				<div class="flex items-center gap-2">
					{#if auth.user.picture}
						<img src={auth.user.picture} alt="Profile" class="h-8 w-8 rounded-full" />
					{/if}
					<span class="text-gray-700">@{auth.user.username}</span>
				</div>
				<button onclick={handleLogout} class="rounded bg-gray-200 px-4 py-2 hover:bg-gray-300">
					Logout
				</button>
			</div>
		</header>

		<main class="mt-8">
			<div class="rounded-lg bg-white p-6 shadow">
				<h2 class="text-xl font-semibold text-gray-900">
					Welcome, {auth.user.name || auth.user.username}!
				</h2>
				<p class="mt-2 text-gray-600">You are successfully authenticated.</p>
			</div>
		</main>
	</div>
{/if}
