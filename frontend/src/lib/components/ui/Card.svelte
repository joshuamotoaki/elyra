<script lang="ts">
	import type { Snippet } from 'svelte';
	import type { HTMLAttributes } from 'svelte/elements';

	interface Props extends HTMLAttributes<HTMLDivElement> {
		variant?: 'elevated' | 'flat';
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
		elevated: 'bg-white border border-slate-200/60 shadow-lg shadow-slate-200/50',
		flat: 'bg-white border border-slate-100'
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
