/**
 * Input manager for the game.
 * Handles WASD keys for movement and mouse for aiming/shooting.
 */

import type { InputState } from '$lib/api/types/game';
import { socketService } from '$lib/api/services/SocketService';
import { gameStore } from '$lib/stores/game.svelte';

class InputManager {
	private keys: InputState = { w: false, a: false, s: false, d: false };
	private mouseX = 0;
	private mouseY = 0;
	private isActive = false;
	private boundKeyDown: (e: KeyboardEvent) => void;
	private boundKeyUp: (e: KeyboardEvent) => void;
	private boundMouseMove: (e: MouseEvent) => void;
	private boundMouseDown: (e: MouseEvent) => void;
	private boundContextMenu: (e: Event) => void;

	constructor() {
		this.boundKeyDown = this.handleKeyDown.bind(this);
		this.boundKeyUp = this.handleKeyUp.bind(this);
		this.boundMouseMove = this.handleMouseMove.bind(this);
		this.boundMouseDown = this.handleMouseDown.bind(this);
		this.boundContextMenu = this.handleContextMenu.bind(this);
	}

	/**
	 * Start listening for input events.
	 */
	start(): void {
		if (this.isActive) return;
		this.isActive = true;

		window.addEventListener('keydown', this.boundKeyDown);
		window.addEventListener('keyup', this.boundKeyUp);
		window.addEventListener('mousemove', this.boundMouseMove);
		window.addEventListener('mousedown', this.boundMouseDown);
		window.addEventListener('contextmenu', this.boundContextMenu);
	}

	/**
	 * Stop listening for input events.
	 */
	stop(): void {
		if (!this.isActive) return;
		this.isActive = false;

		window.removeEventListener('keydown', this.boundKeyDown);
		window.removeEventListener('keyup', this.boundKeyUp);
		window.removeEventListener('mousemove', this.boundMouseMove);
		window.removeEventListener('mousedown', this.boundMouseDown);
		window.removeEventListener('contextmenu', this.boundContextMenu);

		// Reset keys
		this.keys = { w: false, a: false, s: false, d: false };
		this.sendInputUpdate();
	}

	/**
	 * Get current input state.
	 */
	getInput(): InputState {
		return { ...this.keys };
	}

	/**
	 * Get mouse position.
	 */
	getMousePosition(): { x: number; y: number } {
		return { x: this.mouseX, y: this.mouseY };
	}

	private handleKeyDown(e: KeyboardEvent): void {
		// Ignore if typing in an input
		if (e.target instanceof HTMLInputElement || e.target instanceof HTMLTextAreaElement) {
			return;
		}

		const key = e.key.toLowerCase();
		let changed = false;

		switch (key) {
			case 'w':
			case 'arrowup':
				if (!this.keys.w) {
					this.keys.w = true;
					changed = true;
				}
				break;
			case 'a':
			case 'arrowleft':
				if (!this.keys.a) {
					this.keys.a = true;
					changed = true;
				}
				break;
			case 's':
			case 'arrowdown':
				if (!this.keys.s) {
					this.keys.s = true;
					changed = true;
				}
				break;
			case 'd':
			case 'arrowright':
				if (!this.keys.d) {
					this.keys.d = true;
					changed = true;
				}
				break;
			// Space bar shooting is handled in GameScene
		}

		if (changed) {
			this.sendInputUpdate();
		}
	}

	private handleKeyUp(e: KeyboardEvent): void {
		const key = e.key.toLowerCase();
		let changed = false;

		switch (key) {
			case 'w':
			case 'arrowup':
				if (this.keys.w) {
					this.keys.w = false;
					changed = true;
				}
				break;
			case 'a':
			case 'arrowleft':
				if (this.keys.a) {
					this.keys.a = false;
					changed = true;
				}
				break;
			case 's':
			case 'arrowdown':
				if (this.keys.s) {
					this.keys.s = false;
					changed = true;
				}
				break;
			case 'd':
			case 'arrowright':
				if (this.keys.d) {
					this.keys.d = false;
					changed = true;
				}
				break;
		}

		if (changed) {
			this.sendInputUpdate();
		}
	}

	private handleMouseMove(e: MouseEvent): void {
		this.mouseX = e.clientX;
		this.mouseY = e.clientY;
	}

	private handleMouseDown(_e: MouseEvent): void {
		// Shooting is now handled in GameScene via raycasting
		// This is kept for potential future use (e.g., UI clicks)
	}

	private handleContextMenu(e: Event): void {
		// Prevent right-click menu in game area
		e.preventDefault();
	}

	private sendInputUpdate(): void {
		// Update local store
		gameStore.setInput({ ...this.keys });

		// Send to server
		socketService.sendInput(this.keys);
	}

	/**
	 * Shoot in the direction of the mouse relative to player.
	 */
	shoot(): void {
		const player = gameStore.localPlayer;
		if (!player) return;

		// Get player screen position (this would need to be calculated from 3D scene)
		// For now, we'll use a simple approach: shoot in mouse direction from center
		const centerX = window.innerWidth / 2;
		const centerY = window.innerHeight / 2;

		const dx = this.mouseX - centerX;
		const dy = this.mouseY - centerY;

		// Normalize
		const length = Math.sqrt(dx * dx + dy * dy);
		if (length < 1) return;

		const dirX = dx / length;
		const dirY = dy / length;

		socketService.shoot(dirX, dirY);
	}

	/**
	 * Calculate aim direction for a given canvas/3D context.
	 * Returns normalized direction vector.
	 */
	getAimDirection(playerScreenX: number, playerScreenY: number): { x: number; y: number } {
		const dx = this.mouseX - playerScreenX;
		const dy = this.mouseY - playerScreenY;

		const length = Math.sqrt(dx * dx + dy * dy);
		if (length < 1) {
			return { x: 1, y: 0 };
		}

		return { x: dx / length, y: dy / length };
	}
}

export const inputManager = new InputManager();
