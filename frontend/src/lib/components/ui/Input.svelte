<script lang="ts">
	import type { HTMLInputAttributes } from 'svelte/elements';

	interface Props extends Omit<HTMLInputAttributes, 'value'> {
		value?: string;
		label?: string;
		error?: string;
		hint?: string;
	}

	let {
		value = $bindable(''),
		label,
		error,
		hint,
		id,
		class: className = '',
		...rest
	}: Props = $props();

	const fallbackId = `input-${Math.random().toString(36).slice(2, 9)}`;
	const inputId = $derived(id || fallbackId);
</script>

<div class="w-full">
	{#if label}
		<label for={inputId} class="block text-sm font-medium text-slate-700 mb-1.5">
			{label}
		</label>
	{/if}

	<input
		id={inputId}
		bind:value
		class="
			w-full px-4 py-2.5
			bg-white border rounded-sm
			text-slate-700 placeholder:text-slate-400
			transition-all duration-200
			focus:outline-none focus:ring-2 focus:ring-offset-1 focus:ring-offset-white
			disabled:opacity-50 disabled:cursor-not-allowed
			{error
			? 'border-error focus:ring-error focus:border-error'
			: 'border-slate-200 focus:ring-violet focus:border-violet'}
			{className}
		"
		{...rest}
	/>

	{#if error}
		<p class="mt-1.5 text-sm text-error">{error}</p>
	{:else if hint}
		<p class="mt-1.5 text-sm text-slate-400">{hint}</p>
	{/if}
</div>
