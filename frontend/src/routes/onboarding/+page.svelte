<script lang="ts">
	import { auth } from '$lib/stores/auth.svelte';
	import { goto } from '$app/navigation';
	import { onMount } from 'svelte';
	import { PageBackground } from '$lib/components/layout';
	import { Card, Button } from '$lib/components/ui';
	import { SpinnerGap, CheckCircle, XCircle } from 'phosphor-svelte';

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
			goto('/lobby');
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
			goto('/lobby');
		} catch (err) {
			error = err instanceof Error ? err.message : 'Failed to set username';
		} finally {
			isSubmitting = false;
		}
	}
</script>

<PageBackground variant="animated">
	<div class="flex min-h-screen flex-col items-center justify-center px-4">
		<Card variant="elevated" padding="lg" class="w-full max-w-md">
			<div class="text-center mb-8">
				<h1 class="text-3xl font-bold text-slate-800">Choose your username</h1>
				<p class="mt-2 text-slate-500">This will be your unique identifier on Elyra.</p>
			</div>

			<form onsubmit={handleSubmit}>
				<div class="relative">
					<input
						type="text"
						value={username}
						oninput={handleInput}
						placeholder="username"
						minlength={3}
						maxlength={30}
						class="w-full rounded-lg border bg-white px-4 py-3 text-lg text-slate-700 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-violet focus:border-violet transition-all
						{isAvailable === true
							? 'border-success'
							: isAvailable === false
								? 'border-error'
								: 'border-slate-200'}"
					/>

					<span class="absolute right-4 top-1/2 -translate-y-1/2">
						{#if isChecking}
							<SpinnerGap class="animate-spin text-slate-400" size={20} />
						{:else if isAvailable === true}
							<CheckCircle class="text-success" size={20} weight="fill" />
						{:else if isAvailable === false}
							<XCircle class="text-error" size={20} weight="fill" />
						{/if}
					</span>
				</div>

				<p class="mt-2 text-sm text-slate-400">
					{#if isAvailable === true}
						<span class="text-success">Username is available!</span>
					{:else if isAvailable === false}
						<span class="text-error">Username is already taken</span>
					{:else}
						Lowercase letters, numbers, and underscores only
					{/if}
				</p>

				{#if error}
					<p class="mt-2 text-sm text-error">{error}</p>
				{/if}

				<Button
					type="submit"
					disabled={!isAvailable || isSubmitting}
					loading={isSubmitting}
					variant="primary"
					size="lg"
					class="w-full mt-6"
				>
					Continue
				</Button>
			</form>
		</Card>
	</div>
</PageBackground>
