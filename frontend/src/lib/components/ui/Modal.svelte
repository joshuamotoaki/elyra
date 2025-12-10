<script lang="ts">
	import type { Snippet } from 'svelte';
	import { X } from 'phosphor-svelte';

	interface Props {
		open: boolean;
		onClose: () => void;
		title?: string;
		children: Snippet;
	}

	let { open = $bindable(), onClose, title, children }: Props = $props();

	function handleBackdropClick(e: MouseEvent) {
		if (e.target === e.currentTarget) {
			onClose();
		}
	}

	function handleKeydown(e: KeyboardEvent) {
		if (e.key === 'Escape') {
			onClose();
		}
	}
</script>

<svelte:window onkeydown={handleKeydown} />

{#if open}
	<!-- Backdrop -->
	<div
		class="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/50 backdrop-blur-sm"
		onclick={handleBackdropClick}
		onkeydown={(e) => e.key === 'Enter' && onClose()}
		role="button"
		tabindex="-1"
		aria-label="Close modal"
	>
		<!-- Modal -->
		<div
			class="relative mx-4 max-h-[85vh] w-full max-w-lg overflow-auto rounded-2xl bg-white p-6 shadow-large"
			role="dialog"
			aria-modal="true"
			aria-labelledby={title ? 'modal-title' : undefined}
		>
			<!-- Header -->
			{#if title}
				<div class="mb-4 flex items-center justify-between">
					<h2 id="modal-title" class="text-xl font-semibold text-slate-800">{title}</h2>
					<button
						onclick={onClose}
						class="rounded-lg p-1 text-slate-400 transition-colors hover:bg-slate-100 hover:text-slate-600"
						aria-label="Close modal"
					>
						<X size={20} />
					</button>
				</div>
			{:else}
				<button
					onclick={onClose}
					class="absolute right-4 top-4 rounded-lg p-1 text-slate-400 transition-colors hover:bg-slate-100 hover:text-slate-600"
					aria-label="Close modal"
				>
					<X size={20} />
				</button>
			{/if}

			<!-- Content -->
			<div class="text-slate-600">
				{@render children()}
			</div>
		</div>
	</div>
{/if}
