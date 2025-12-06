<script lang="ts">
	interface Props {
		checked?: boolean;
		disabled?: boolean;
		label?: string;
		description?: string;
	}

	let { checked = $bindable(false), disabled = false, label, description }: Props = $props();
</script>

<label
	class="flex items-center justify-between gap-4 cursor-pointer {disabled
		? 'opacity-50 cursor-not-allowed'
		: ''}"
>
	<div class="flex-1">
		{#if label}
			<div class="font-medium text-slate-700">{label}</div>
		{/if}
		{#if description}
			<div class="text-sm text-slate-500">{description}</div>
		{/if}
	</div>

	<button
		type="button"
		role="switch"
		aria-checked={checked}
		aria-label={label || 'Toggle'}
		{disabled}
		onclick={() => !disabled && (checked = !checked)}
		class="
			relative w-12 h-6 rounded-full
			transition-colors duration-200
			focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-violet
			{checked ? 'bg-violet' : 'bg-slate-300'}
		"
	>
		<span
			class="
				absolute top-1 left-1
				w-4 h-4 bg-white rounded-full shadow-sm
				transition-transform duration-200
				{checked ? 'translate-x-6' : 'translate-x-0'}
			"
		></span>
	</button>
</label>
