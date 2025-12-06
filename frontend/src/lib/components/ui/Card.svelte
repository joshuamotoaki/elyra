<script lang="ts">
	import type { Snippet } from 'svelte';
	import type { HTMLAttributes } from 'svelte/elements';

	interface Props extends HTMLAttributes<HTMLDivElement> {
		variant?: 'elevated' | 'flat' | 'glass';
		padding?: 'none' | 'sm' | 'md' | 'lg';
		children: Snippet;
	}

	let {
		variant = 'elevated',
		padding = 'md',
		class: className = '',
		children,
		...rest
	}: Props = $props();

	const baseStyles = 'rounded-2xl transition-shadow duration-200';

	const variants = {
		elevated: 'bg-white shadow-soft hover:shadow-medium',
		flat: 'bg-white',
		glass: 'glass border border-white/20'
	};

	const paddings = {
		none: '',
		sm: 'p-4',
		md: 'p-6',
		lg: 'p-8'
	};
</script>

<div class="{baseStyles} {variants[variant]} {paddings[padding]} {className}" {...rest}>
	{@render children()}
</div>
