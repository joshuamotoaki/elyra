<script lang="ts">
	import { auth } from '$lib/stores/auth.svelte';
	import { goto } from '$app/navigation';
	import { onMount } from 'svelte';

	let username = $state('');
	let error = $state<string | null>(null);
	let isChecking = $state(false);
	let isAvailable = $state<boolean | null>(null);
	let isSubmitting = $state(false);

	let checkTimeout: ReturnType<typeof setTimeout>;

	onMount(async () => {
		await auth.loadUser();
		if (!auth.isAuthenticated) {
			goto('/');
		} else if (!auth.needsOnboarding) {
			goto('/dashboard');
		}
	});

	async function checkUsername(value: string) {
		if (value.length < 3) {
			isAvailable = null;
			return;
		}

		isChecking = true;
		try {
			const response = await fetch(
				`http://localhost:4000/api/users/check-username?username=${encodeURIComponent(value)}`
			);
			const data = await response.json();
			isAvailable = data.available;
		} catch {
			isAvailable = null;
		} finally {
			isChecking = false;
		}
	}

	function handleInput(e: Event) {
		const value = (e.target as HTMLInputElement).value;
		username = value.toLowerCase().replace(/[^a-z0-9_]/g, '');

		clearTimeout(checkTimeout);
		checkTimeout = setTimeout(() => checkUsername(username), 300);
	}

	async function handleSubmit(e: Event) {
		e.preventDefault();
		if (!isAvailable || isSubmitting) return;

		isSubmitting = true;
		error = null;

		try {
			await auth.setUsername(username);
			goto('/dashboard');
		} catch (err) {
			error = err instanceof Error ? err.message : 'Failed to set username';
		} finally {
			isSubmitting = false;
		}
	}
</script>

<div class="flex min-h-screen flex-col items-center justify-center bg-gray-50 p-4">
	<div class="w-full max-w-md">
		<h1 class="mb-2 text-3xl font-bold text-gray-900">Choose your username</h1>
		<p class="mb-8 text-gray-600">This will be your unique identifier on Elyra.</p>

		<form onsubmit={handleSubmit}>
			<div class="relative">
				<input
					type="text"
					value={username}
					oninput={handleInput}
					placeholder="username"
					minlength={3}
					maxlength={30}
					class="w-full rounded-lg border border-gray-300 px-4 py-3 text-lg focus:border-blue-500 focus:outline-none"
				/>

				{#if isChecking}
					<span class="absolute right-4 top-1/2 -translate-y-1/2 text-gray-400"> Checking... </span>
				{:else if isAvailable === true}
					<span class="absolute right-4 top-1/2 -translate-y-1/2 text-green-500"> Available </span>
				{:else if isAvailable === false}
					<span class="absolute right-4 top-1/2 -translate-y-1/2 text-red-500"> Taken </span>
				{/if}
			</div>

			{#if error}
				<p class="mt-2 text-sm text-red-600">{error}</p>
			{/if}

			<button
				type="submit"
				disabled={!isAvailable || isSubmitting}
				class="mt-6 w-full rounded-lg bg-blue-600 py-3 font-semibold text-white transition hover:bg-blue-700 disabled:cursor-not-allowed disabled:opacity-50"
			>
				{isSubmitting ? 'Setting username...' : 'Continue'}
			</button>
		</form>
	</div>
</div>
