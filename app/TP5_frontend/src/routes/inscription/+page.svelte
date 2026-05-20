<script>
	import { goto } from '$app/navigation';
	import { isConnected } from '$lib/stores/auth';

	let username = '';
	let password = '';
	let confirmPassword = '';

	let loading = false;
	let errorMessage = '';
	let successMessage = '';

	async function handleRegister() {
		errorMessage = '';
		successMessage = '';

		const cleanUsername = username.trim();

		if (!cleanUsername || !password || !confirmPassword) {
			errorMessage = 'Tous les champs sont obligatoires.';
			return;
		}

		if (password !== confirmPassword) {
			errorMessage = 'Les mots de passe ne correspondent pas.';
			return;
		}

		loading = true;

		try {
			const response = await fetch('http://localhost:4000/api/register', {
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
				throw new Error(data.error || 'Erreur lors de l’inscription.');
			}

			if (data.token) {
				localStorage.setItem('token', data.token);
			}

			if (data.user) {
				localStorage.setItem('user', JSON.stringify(data.user));
			} else {
				localStorage.setItem('user', JSON.stringify({ username: cleanUsername }));
			}

			isConnected.set(true);
			successMessage = 'Inscription réussie. Redirection...';

			setTimeout(() => {
				goto('/');
			}, 800);
		} catch (error) {
			errorMessage = error.message || 'Erreur lors de l’inscription.';
		} finally {
			loading = false;
		}
	}
</script>

<h2>Inscription</h2>

<form on:submit|preventDefault={handleRegister}>
	<h2>Créer un compte</h2>

	<label for="username">Nom d'utilisateur</label>
	<input type="text" id="username" bind:value={username} required autocomplete="username" />

	<label for="password">Mot de passe</label>
	<input
		type="password"
		id="password"
		bind:value={password}
		required
		autocomplete="new-password"
	/>

	<label for="confirmPassword">Confirmer le mot de passe</label>
	<input
		type="password"
		id="confirmPassword"
		bind:value={confirmPassword}
		required
		autocomplete="new-password"
	/>

	{#if errorMessage}
		<p class="error-message">{errorMessage}</p>
	{/if}

	{#if successMessage}
		<p class="success-message">{successMessage}</p>
	{/if}

	<button type="submit" disabled={loading}>
		{loading ? 'Inscription...' : "S'inscrire"}
	</button>
</form>

<a href="/connexion">Déjà un compte ? Se connecter</a>

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