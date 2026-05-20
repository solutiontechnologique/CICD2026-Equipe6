<script>
	import { goto } from '$app/navigation';
	import { browser } from '$app/environment';
	import { isConnected } from '$lib/stores/auth';

	let { children } = $props();
	let connectedUsername = $state('');

	function clearAuthState() {
		if (browser) {
			localStorage.removeItem('token');
			localStorage.removeItem('user');
		}

		isConnected.set(false);
		connectedUsername = '';
	}

	function restoreAuthFromStorage() {
		if (!browser) return;

		const token = localStorage.getItem('token');
		const userRaw = localStorage.getItem('user');

		if (!token || typeof token !== 'string' || token.trim() === '') {
			clearAuthState();
			return;
		}

		isConnected.set(true);

		if (userRaw) {
			try {
				const user = JSON.parse(userRaw);

				if (user && typeof user.username === 'string' && user.username.trim() !== '') {
					connectedUsername = user.username.trim();
				} else {
					connectedUsername = '';
				}
			} catch (e) {
				console.error('Erreur lecture utilisateur :', e);
				connectedUsername = '';
			}
		} else {
			connectedUsername = '';
		}
	}

	if (browser) {
		restoreAuthFromStorage();
	}

	$effect(() => {
		if (!browser) return;

		if ($isConnected) {
			const token = localStorage.getItem('token');

			if (!token || token.trim() === '') {
				clearAuthState();
				return;
			}

			const userRaw = localStorage.getItem('user');

			if (userRaw) {
				try {
					const user = JSON.parse(userRaw);
					connectedUsername =
						user && typeof user.username === 'string' ? user.username.trim() : '';
				} catch (e) {
					console.error('Erreur lecture utilisateur :', e);
					connectedUsername = '';
				}
			} else {
				connectedUsername = '';
			}
		} else {
			connectedUsername = '';
		}
	});

	function logout() {
		clearAuthState();
		goto('/');
	}

	async function downloadBackup() {
  const response = await fetch('http://localhost:4000/api/backup');

  const blob = await response.blob();

  const url = URL.createObjectURL(blob);

  const a = document.createElement('a');
  a.href = url;
  a.download = 'backup.json';
  a.click();

  URL.revokeObjectURL(url);
}
</script>

<header class="header">
	<div class="logo-container">
		<a href="/" class="logo-link">
			<img src="/logo.png" alt="logo" height="80px" />
			<h1>YRR - Courses de bateaux</h1>
		</a>
	</div>

	{#if !$isConnected}
		<nav>
			<a href="/inscription">S'inscrire</a>
			<a href="/connexion">Se connecter</a>
		</nav>
	{:else}
		<div class="right-side">
			<div class="user-info">
				Connecté en tant que <strong>{connectedUsername || 'utilisateur inconnu'}</strong>
			</div>

			<nav>
				<a href="/bateaux">Bateaux</a>
				<a href="/classes">Classes</a>
				<a href="/courses">Courses</a>
				<a href="/series">Séries</a>
				<a href="/inscriptions">Inscriptions</a>
				<button class="download" on:click={downloadBackup}>Télécharger la base de données</button>
				<button on:click={logout}>Déconnexion</button>
			</nav>
		</div>
	{/if}
</header>

<main class="content">
	{@render children()}
</main>

<style>
	:global(body) {
		margin: 0;
		font-family: Arial, sans-serif;
		background: #f4f6f8;
	}

	.header {
		background: #1f2937;
		color: white;
		padding: 12px 24px;
		display: flex;
		justify-content: space-between;
		align-items: center;
		border-bottom: 1px solid rgba(255,255,255,0.08);
		gap: 16px;
		flex-wrap: wrap;
	}

	.logo-container {
		display: flex;
		align-items: center;
	}

	.logo-link {
		display: flex;
		align-items: center;
		gap: 10px;
		text-decoration: none;
		color: white;
	}

	.header h1 {
		margin: 0;
		font-size: 1.2rem;
		font-weight: 600;
	}

	.right-side {
		display: flex;
		flex-direction: column;
		align-items: flex-end;
		gap: 10px;
	}

	.download {
		background: #808080;
	}

	.download:hover {
		background: #6d6d6d;
	}

	.user-info {
		font-size: 0.95rem;
		color: #e5e7eb;
	}

	nav {
		display: flex;
		gap: 8px;
		flex-wrap: wrap;
	}

	nav a {
		color: #e5e7eb;
		padding: 8px 12px;
		border-radius: 6px;
		text-decoration: none;
		transition: all 0.2s ease;
	}

	nav a:visited {
		color: #e5e7eb;
	}

	nav a:hover {
		background: rgba(255,255,255,0.1);
		color: white;
	}

	nav button {
		background: #ef4444;
		color: white;
		padding: 8px 12px;
		border-radius: 6px;
		border: none;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	nav button:hover {
		background: #dc2626;
	}

	.content {
		padding: 32px;
		max-width: 1200px;
		margin: 0 auto;
	}
</style>