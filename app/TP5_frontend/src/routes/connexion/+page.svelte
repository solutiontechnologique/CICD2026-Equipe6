<script>
	import { goto } from '$app/navigation';
	import { isConnected } from '$lib/stores/auth';

	let username = '';
	let password = '';

	let loading = false;
	let errorMessage = '';
	let successMessage = '';

	async function handleLogin() {
		errorMessage = '';
		successMessage = '';

		const cleanUsername = username.trim();

		if (!cleanUsername || !password) {
			errorMessage = 'Nom d’utilisateur et mot de passe requis.';
			return;
		}

		loading = true;

		try {
			const response = await fetch('http://localhost:4000/api/login', {
				method: 'POST',
				headers: {
					'Content-Type': 'application/json'
				},
				body: JSON.stringify({
					username: cleanUsername,
					password
				})
			});

			const data = await response.json().catch(() => ({}));

			if (!response.ok) {
				throw new Error(data.error || 'Erreur lors de la connexion.');
			}

			if (data.token) {
				localStorage.setItem('token', data.token);
			}

			if (data.user) {
				localStorage.setItem('user', JSON.stringify(data.user));
			} else {
				localStorage.setItem(
					'user',
					JSON.stringify({ username: cleanUsername })
				);
			}

			isConnected.set(true);
			successMessage = 'Connexion réussie. Redirection...';

			setTimeout(() => {
				goto('/');
			}, 800);
		} catch (error) {
			errorMessage = error.message || 'Erreur lors de la connexion.';
		} finally {
			loading = false;
		}
	}
</script>

<h2>Connexion</h2>

<form on:submit|preventDefault={handleLogin}>
	<h2>Se connecter</h2>

	<label for="username">Nom d'utilisateur</label>
	<input type="text" id="username" bind:value={username} required />

	<label for="password">Mot de passe</label>
	<input type="password" id="password" bind:value={password} required />

	{#if errorMessage}
		<p class="error-message">{errorMessage}</p>
	{/if}

	{#if successMessage}
		<p class="success-message">{successMessage}</p>
	{/if}

	<button type="submit" disabled={loading}>
		{loading ? 'Connexion...' : 'Se connecter'}
	</button>
</form>

<a href="/inscription">Créer un compte</a>

<style>
	form {
		background: white;
		padding: 20px;
		max-width: 400px;
		margin: auto;
		border-radius: 8px;
		box-shadow: 0 0 10px rgba(0,0,0,0.1);
	}

	label {
		display: block;
		margin-top: 10px;
	}

	label strong {
		font-size: 0.85rem;
		color: #6b7280;
		text-transform: uppercase;
		letter-spacing: 0.05em;
	}

	input {
		width: 100%;
		padding: 8px;
		margin-top: 5px;
		border-radius: 4px;
		border: 1px solid #ccc;
		box-sizing: border-box;
	}

	button {
		margin-top: 15px;
		padding: 10px;
		width: 100%;
		background-color: #888888;
		color: white;
		border: none;
		border-radius: 4px;
		cursor: pointer;
	}

	button:hover:enabled {
		background-color: #777777;
	}

	button:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	a {
		display: block;
		text-align: center;
		margin-top: 10px;
	}

	.error-message {
		color: #b00020;
		margin-top: 12px;
	}

	.success-message {
		color: #1f7a1f;
		margin-top: 12px;
	}
</style>