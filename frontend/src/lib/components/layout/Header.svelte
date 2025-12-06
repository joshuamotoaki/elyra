<script lang="ts">
	import { Avatar, Button } from '../ui';

	interface User {
		username?: string | null;
		name?: string | null;
		picture?: string | null;
	}

	interface Props {
		user?: User | null;
		onLogout?: () => void;
	}

	let { user, onLogout }: Props = $props();
</script>

<header class="flex items-center justify-between p-6">
	<h1 class="text-2xl font-bold text-slate-800">Elyra</h1>

	{#if user}
		<div class="flex items-center gap-4">
			<div class="flex items-center gap-2">
				<Avatar src={user.picture} fallback={user.username || user.name || '?'} size="sm" />
				<span class="text-slate-600 font-medium">@{user.username}</span>
			</div>
			<Button variant="ghost" size="sm" onclick={onLogout}>Logout</Button>
		</div>
	{/if}
</header>
