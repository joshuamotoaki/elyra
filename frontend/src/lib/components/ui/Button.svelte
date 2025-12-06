<script lang="ts">
	import type { Snippet } from 'svelte';
	import type { HTMLButtonAttributes } from 'svelte/elements';

	interface Props extends HTMLButtonAttributes {
		variant?: 'primary' | 'secondary' | 'ghost';
		size?: 'sm' | 'md' | 'lg';
		loading?: boolean;
		children: Snippet;
	}

	let {
		variant = 'primary',
		size = 'md',
		loading = false,
		disabled = false,
		class: className = '',
		children,
		...rest
	}: Props = $props();

	const baseStyles = `
		inline-flex items-center justify-center gap-2
		font-medium rounded-lg
		transition-all duration-200 ease-out
		focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-offset-white
		disabled:opacity-50 disabled:cursor-not-allowed
	`;

	const variants = {
		primary: `
			bg-violet text-white
			hover:bg-purple-dark hover:shadow-medium hover:-translate-y-0.5
			focus:ring-violet
			active:translate-y-0
		`,
		secondary: `
			bg-teal text-white
			hover:bg-teal-dark hover:shadow-medium hover:-translate-y-0.5
			focus:ring-teal
			active:translate-y-0
		`,
		ghost: `
			bg-white/80 text-slate-700
			hover:bg-white hover:text-slate-900
			focus:ring-slate-400
		`
	};

	const sizes = {
		sm: 'px-3 py-1.5 text-sm',
		md: 'px-4 py-2.5 text-base',
		lg: 'px-6 py-3 text-lg'
	};
</script>

<button
	class="{baseStyles} {variants[variant]} {sizes[size]} {className}"
	disabled={disabled || loading}
	{...rest}
>
	{#if loading}
		<svg class="animate-spin h-4 w-4" viewBox="0 0 24 24" fill="none">
			<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"
			></circle>
			<path
				class="opacity-75"
				fill="currentColor"
				d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
			></path>
		</svg>
	{/if}
	{@render children()}
</button>
