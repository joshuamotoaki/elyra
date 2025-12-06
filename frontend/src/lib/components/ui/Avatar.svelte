<script lang="ts">
	interface Props {
		src?: string | null;
		fallback?: string;
		size?: 'sm' | 'md' | 'lg';
		class?: string;
	}

	let { src, fallback = '?', size = 'md', class: className = '' }: Props = $props();

	const initial = $derived(fallback?.charAt(0).toUpperCase() || '?');

	const sizes = {
		sm: 'w-8 h-8 text-sm',
		md: 'w-10 h-10 text-base',
		lg: 'w-12 h-12 text-lg'
	};
</script>

{#if src}
	<img {src} alt="" class="rounded-full object-cover {sizes[size]} {className}" />
{:else}
	<div
		class="
			rounded-full flex items-center justify-center
			bg-gradient-to-br from-teal to-violet text-white font-medium
			{sizes[size]} {className}
		"
	>
		{initial}
	</div>
{/if}
