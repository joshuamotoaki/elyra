<script lang="ts">
	import { auth } from '$lib/stores/auth.svelte';
	import { goto } from '$app/navigation';
	import { onMount } from 'svelte';
	import { PageBackground } from '$lib/components/layout';
	import { Card, Button } from '$lib/components/ui';
	import { GoogleLogo } from 'phosphor-svelte';

	const API_URL = 'http://localhost:4000';

	onMount(async () => {
		if (auth.token) {
			await auth.loadUser();
			if (auth.isAuthenticated) {
				goto(auth.needsOnboarding ? '/onboarding' : '/lobby');
			}
		}
	});

	function signInWithGoogle() {
		window.location.href = `${API_URL}/api/auth/google`;
	}
</script>

<PageBackground>
	<div class="flex min-h-screen flex-col items-center justify-center px-4">
		<Card variant="elevated" padding="lg" class="w-full max-w-md text-center">
			<!-- Logo/Title -->
			<div class="mb-8">
				<h1 class="text-4xl font-bold text-slate-800 tracking-tight">Elyra</h1>
				<p class="mt-2 text-slate-500">A multiplayer puzzle experience</p>
			</div>

			<!-- Decorative divider -->
			<div class="flex items-center gap-4 mb-8">
				<div class="flex-1 h-px bg-slate-200"></div>
				<div class="w-2 h-2 rounded-full bg-violet opacity-60"></div>
				<div class="flex-1 h-px bg-slate-200"></div>
			</div>

			<!-- Sign in button -->
			<Button onclick={signInWithGoogle} variant="primary" size="lg" class="w-full">
				<GoogleLogo size={20} weight="bold" class="mr-2" />
				Continue with Google
			</Button>

			<!-- Footer text -->
			<p class="mt-6 text-sm text-slate-400">Join the adventure</p>
		</Card>
	</div>
</PageBackground>
