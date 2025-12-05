<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { page } from '$app/stores';
  import { auth } from '$lib/stores/auth.svelte';

  let error = $state<string | null>(null);

  onMount(async () => {
    const params = $page.url.searchParams;
    const token = params.get('token');
    const redirect = params.get('redirect') || '/dashboard';
    const errorMsg = params.get('error');

    if (errorMsg) {
      error = decodeURIComponent(errorMsg);
      return;
    }

    if (token) {
      auth.setToken(token);
      await auth.loadUser();
      goto(redirect);
    } else {
      error = 'No authentication token received';
    }
  });
</script>

<div class="flex min-h-screen items-center justify-center">
	{#if error}
		<div class="text-center">
			<h1 class="text-2xl font-bold text-red-600">Authentication Error</h1>
			<p class="mt-2 text-gray-600">{error}</p>
			<a href="/" class="mt-4 inline-block text-blue-600 hover:underline"> Return to Home </a>
		</div>
	{:else}
		<div class="text-center">
			<p class="text-gray-600">Completing sign in...</p>
		</div>
	{/if}
</div>
