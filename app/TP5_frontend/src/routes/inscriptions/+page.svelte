<script>
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';

	const API_BASE = 'http://localhost:4000/api';

	let courses = [];
	let series = [];
	let bateaux = [];
	let participants = [];

	let typeInscription = 'course'; // 'course' | 'serie'
	let selectedCourse = null;
	let selectedSerie = null;

	let mode = 'voir';
	let bateauxSelectionnes = [];

	let loadingCourses = false;
	let loadingSeries = false;
	let loadingBoats = false;
	let loadingParticipants = false;
	let submitting = false;
	let errorMessage = '';

	function getAuthHeaders(includeJson = false) {
		const token = localStorage.getItem('token');

		if (!token) {
			localStorage.removeItem('token');
			localStorage.removeItem('user');
			goto('/connexion');
			throw new Error('Token manquant');
		}

		return {
			...(includeJson ? { 'Content-Type': 'application/json' } : {}),
			Authorization: `Bearer ${token}`
		};
	}

	function handleUnauthorized() {
		localStorage.removeItem('token');
		localStorage.removeItem('user');
		goto('/connexion');
	}

	onMount(async () => {
		await Promise.all([chargerCourses(), chargerSeries(), chargerBateaux()]);
	});

	async function chargerCourses() {
		loadingCourses = true;
		errorMessage = '';

		try {
			const response = await fetch(`${API_BASE}/getraces`, {
				headers: getAuthHeaders()
			});

			if (response.status === 401) {
				handleUnauthorized();
				return;
			}

			if (!response.ok) throw new Error('Impossible de charger les courses');

			const data = await response.json();
			courses = data.map(mapRaceFromApi);

			if (!selectedCourse && courses.length > 0) {
				selectedCourse = courses[0];

				if (typeInscription === 'course') {
					await chargerParticipantsCourse(selectedCourse.id);
				}
			}
		} catch (error) {
			console.error(error);
			if (error.message !== 'Token manquant') {
				errorMessage = error.message || 'Erreur lors du chargement des courses';
			}
		} finally {
			loadingCourses = false;
		}
	}

	async function chargerSeries() {
		loadingSeries = true;
		errorMessage = '';

		try {
			const response = await fetch(`${API_BASE}/getSeries`, {
				headers: getAuthHeaders()
			});

			if (response.status === 401) {
				handleUnauthorized();
				return;
			}

			if (!response.ok) throw new Error('Impossible de charger les séries');

			const data = await response.json();
			series = data.map(mapSerieFromApi);

			if (!selectedSerie && series.length > 0) {
				selectedSerie = series[0];

				if (typeInscription === 'serie') {
					await chargerParticipantsSerie(selectedSerie.id);
				}
			}
		} catch (error) {
			console.error(error);
			if (error.message !== 'Token manquant') {
				errorMessage = error.message || 'Erreur lors du chargement des séries';
			}
		} finally {
			loadingSeries = false;
		}
	}

	async function chargerBateaux() {
		loadingBoats = true;
		errorMessage = '';

		try {
			const response = await fetch(`${API_BASE}/getboats`, {
				headers: getAuthHeaders()
			});

			if (response.status === 401) {
				handleUnauthorized();
				return;
			}

			if (!response.ok) throw new Error('Impossible de charger les bateaux');

			const data = await response.json();
			bateaux = data.map(mapBoatFromApi);
		} catch (error) {
			console.error(error);
			if (error.message !== 'Token manquant') {
				errorMessage = error.message || 'Erreur lors du chargement des bateaux';
			}
		} finally {
			loadingBoats = false;
		}
	}

	async function chargerParticipantsCourse(courseId) {
		if (!courseId) return;

		loadingParticipants = true;
		errorMessage = '';

		try {
			const response = await fetch(`${API_BASE}/getparticipantsforrace/${courseId}`, {
				headers: getAuthHeaders()
			});

			if (response.status === 401) {
				handleUnauthorized();
				return;
			}

			if (!response.ok) {
				const err = await response.json().catch(() => ({}));
				throw new Error(err.error || 'Impossible de charger les participants');
			}

			const data = await response.json();
			participants = data.map(mapParticipantFromApi);
		} catch (error) {
			console.error(error);
			if (error.message !== 'Token manquant') {
				errorMessage = error.message || 'Erreur lors du chargement des participants';
			}
			participants = [];
		} finally {
			loadingParticipants = false;
		}
	}

	async function chargerParticipantsSerie(serieId) {
		if (!serieId) return;

		loadingParticipants = true;
		errorMessage = '';

		try {
			const response = await fetch(`${API_BASE}/getSeries`, {
				headers: getAuthHeaders()
			});

			if (response.status === 401) {
				handleUnauthorized();
				return;
			}

			if (!response.ok) {
				throw new Error('Impossible de charger les participants de la série');
			}

			const data = await response.json();
			const serie = data.find((s) => String(s._id?.$oid ?? s.id ?? s._id) === String(serieId));

			if (!serie) {
				participants = [];
				return;
			}

			participants = (serie.participants || []).map(mapParticipantFromApi);
		} catch (error) {
			console.error(error);
			if (error.message !== 'Token manquant') {
				errorMessage =
					error.message || 'Erreur lors du chargement des participants de la série';
			}
			participants = [];
		} finally {
			loadingParticipants = false;
		}
	}

	async function refreshParticipants() {
		bateauxSelectionnes = [];
		mode = 'voir';

		if (typeInscription === 'course' && selectedCourse?.id) {
			await chargerParticipantsCourse(selectedCourse.id);
		} else if (typeInscription === 'serie' && selectedSerie?.id) {
			await chargerParticipantsSerie(selectedSerie.id);
		} else {
			participants = [];
		}
	}

	function mapRaceFromApi(race) {
		return {
			id: race._id?.$oid ?? race.id ?? race._id,
			nom: race.name ?? race.nom ?? '',
			date: race.date ?? '',
			classe: race.class ?? race.classe ?? race.location ?? '',
			terminee: race.finished ?? race.terminee ?? false
		};
	}

	function mapSerieFromApi(serie) {
		return {
			id: serie._id?.$oid ?? serie.id ?? serie._id,
			nom: serie.nom ?? serie.name ?? '',
			type: serie.type ?? 'OD',
			classe: serie.classe ?? serie.class ?? '',
			nombreCourses: serie.nombreCourses ?? serie.nombre_courses ?? 0,
			nombreComptabilisees: serie.nombreComptabilisees ?? serie.nombre_comptabilisees ?? 0,
			participants: serie.participants ?? []
		};
	}

	function mapBoatFromApi(boat) {
		return {
			id: boat._id?.$oid ?? boat.id ?? boat._id,
			nom: boat.name ?? boat.nom ?? '',
			numeroVoile: String(boat.sail_number ?? boat.numeroVoile ?? boat.noVoile ?? ''),
			classe: boat.class ?? boat.classe ?? '',
			barreur: boat.helm_name ?? boat.barreur ?? boat.NomBarreur ?? '',
			typeHandicap: boat.type_handicap ?? boat.typeHandicap ?? '',
			valeurHandicap: boat.valeur_handicap ?? boat.valeurHandicap ?? 1
		};
	}

	function mapParticipantFromApi(participant) {
	return {
		id: participant.id ?? participant.boat_id,
		boatId: participant.boat_id ?? participant.id,
		nom: participant.boat_name ?? participant.nom ?? '',
		numeroVoile: String(participant.sail_number ?? participant.numeroVoile ?? ''),
		classe: participant.boat_class ?? participant.classe ?? '',
		barreur: participant.helm_name ?? participant.barreur ?? '',
		typeHandicap: participant.type_handicap ?? participant.typeHandicap ?? '',
		valeurHandicap: participant.valeur_handicap ?? participant.valeurHandicap ?? 1
	};
}

	async function selectCourse(course) {
		selectedCourse = course;
		typeInscription = 'course';
		mode = 'voir';
		bateauxSelectionnes = [];
		await chargerParticipantsCourse(course.id);
	}

	async function selectSerie(serie) {
		selectedSerie = serie;
		typeInscription = 'serie';
		mode = 'voir';
		bateauxSelectionnes = [];
		await chargerParticipantsSerie(serie.id);
	}

	function getCurrentTitle() {
		if (typeInscription === 'course') return selectedCourse?.nom ?? '';
		return selectedSerie?.nom ?? '';
	}

	function getCurrentDate() {
		if (typeInscription === 'course') return selectedCourse?.date ?? '';
		return '';
	}

	function getCurrentClasse() {
		if (typeInscription === 'course') return selectedCourse?.classe ?? '';
		return selectedSerie?.classe ?? '';
	}

	function getParticipants() {
		return participants;
	}

	function getBateauxDisponibles() {
		const dejaInscrits = new Set(participants.map((p) => String(p.boatId ?? p.id)));
		return bateaux.filter((b) => !dejaInscrits.has(String(b.id)));
	}

	function toggleBoatSelection(boatId) {
		if (bateauxSelectionnes.includes(boatId)) {
			bateauxSelectionnes = bateauxSelectionnes.filter((id) => id !== boatId);
		} else {
			bateauxSelectionnes = [...bateauxSelectionnes, boatId];
		}
	}

	async function ajouterParticipants() {
		if (typeInscription === 'course' && !selectedCourse) return;
		if (typeInscription === 'serie' && !selectedSerie) return;

		if (typeInscription === 'course' && selectedCourse.terminee) {
			alert('Cette course est terminée. Impossible d’ajouter des participants.');
			return;
		}

		submitting = true;
		errorMessage = '';

		try {
			for (const boatId of bateauxSelectionnes) {
				const bateau = bateaux.find((b) => String(b.id) === String(boatId));
				if (!bateau) continue;

				let url;
				let payload;

				if (typeInscription === 'course') {
					url = `${API_BASE}/addparticipanttorace`;

					payload = {
						race_id: String(selectedCourse.id),
						boat_id: String(bateau.id),
						boat_name: bateau.nom,
						sail_number: String(bateau.numeroVoile),
						boat_class: bateau.classe,
						helm_name: bateau.barreur,
						type_handicap: bateau.typeHandicap,
						valeur_handicap: Number(bateau.valeurHandicap || 1)
					};
				} else {
					url = `${API_BASE}/addparticipanttoserie`;

					payload = {
						serie_id: String(selectedSerie.id),
						boat_id: String(bateau.id),
						boat_name: bateau.nom,
						sail_number: String(bateau.numeroVoile),
						boat_class: bateau.classe,
						helm_name: bateau.barreur,
						type_handicap: bateau.typeHandicap,
						valeur_handicap: Number(bateau.valeurHandicap || 1)
					};
				}

				const response = await fetch(url, {
					method: 'POST',
					headers: getAuthHeaders(true),
					body: JSON.stringify(payload)
				});

				if (response.status === 401) {
					handleUnauthorized();
					return;
				}

				if (!response.ok) {
					const err = await response.json().catch(() => ({}));
					throw new Error(err.error || 'Erreur lors de l’ajout des participants');
				}
			}

			bateauxSelectionnes = [];
			mode = 'voir';

			await chargerCourses();
			await chargerSeries();
			await refreshParticipants();
		} catch (error) {
			console.error(error);
			if (error.message !== 'Token manquant') {
				errorMessage = error.message || 'Erreur lors de l’ajout des participants';
				alert(errorMessage);
			}
		} finally {
			submitting = false;
		}
	}

async function retirerParticipantSerie(participant) {
	if (!selectedSerie?.id || !participant?.boatId) return;

	const confirmed = confirm(`Retirer le bateau "${participant.nom}" de cette série ?`);
	if (!confirmed) return;

	try {
		const response = await fetch(
			`${API_BASE}/removeparticipantfromserie/${selectedSerie.id}/${participant.boatId}`,
			{
				method: 'DELETE',
				headers: getAuthHeaders()
			}
		);

		if (response.status === 401) {
			handleUnauthorized();
			return;
		}

		if (!response.ok) {
			const err = await response.json().catch(() => ({}));
			throw new Error(err.error || 'Erreur lors de la suppression de l’inscription à la série');
		}

		await chargerSeries();
		await chargerParticipantsSerie(selectedSerie.id);
	} catch (error) {
		console.error(error);
		if (error.message !== 'Token manquant') {
			alert(error.message || 'Erreur lors de la suppression de l’inscription à la série');
		}
	}
}

	async function retirerParticipant(participant) {
		if (typeInscription !== 'course') {
			alert("La suppression est seulement gérée ici pour l'inscription à une course.");
			return;
		}

		if (!selectedCourse?.id || !participant?.id) return;

		if (selectedCourse.terminee) {
			alert('Cette course est terminée. Impossible de retirer un participant.');
			return;
		}

		const confirmed = confirm(`Retirer le bateau "${participant.nom}" de cette course ?`);
		if (!confirmed) return;

		try {
			const response = await fetch(
				`${API_BASE}/removeparticipantfromrace/${selectedCourse.id}/${participant.id}`,
				{
					method: 'DELETE',
					headers: getAuthHeaders()
				}
			);

			if (response.status === 401) {
				handleUnauthorized();
				return;
			}

			if (!response.ok) {
				const err = await response.json().catch(() => ({}));
				throw new Error(err.error || 'Erreur lors de la suppression de l’inscription');
			}

			await chargerParticipantsCourse(selectedCourse.id);
		} catch (error) {
			console.error(error);
			if (error.message !== 'Token manquant') {
				alert(error.message || 'Erreur lors de la suppression de l’inscription');
			}
		}
	}

	function imprimerFormulaire() {
		if (typeInscription === 'course' && !selectedCourse) return;
		if (typeInscription === 'serie' && !selectedSerie) return;

		const titre = typeInscription === 'course' ? 'FICHE D’INSCRIPTION COURSE' : 'FICHE D’INSCRIPTION SÉRIE';

		const rows = Array.from({ length: 15 })
			.map(
				(_, i) => `
					<tr>
						<td>${participants[i]?.nom ?? ''}</td>
						<td>${participants[i]?.numeroVoile ?? ''}</td>
						<td>${participants[i]?.classe ?? ''}</td>
						<td>${participants[i]?.barreur ?? ''}</td>
						<td>${participants[i]?.typeHandicap ?? ''}</td>
						<td>${participants[i]?.valeurHandicap ?? ''}</td>
						<td></td>
					</tr>
				`
			)
			.join('');

		const html = `
			<html>
			<head>
				<title>Fiche inscription</title>
				<style>
					body {
						font-family: Arial, sans-serif;
						padding: 20px;
					}

					h1 {
						text-align: center;
						font-size: 18px;
						margin-bottom: 24px;
					}

					table {
						width: 100%;
						border-collapse: collapse;
						margin-top: 20px;
					}

					th,
					td {
						border: 1px solid black;
						padding: 8px;
						font-size: 12px;
						height: 28px;
					}

					th {
						background: #f0f0f0;
					}

					.signature-block {
						margin-top: 32px;
					}

					.signature-line {
						border-bottom: 1px solid black;
						width: 260px;
						height: 32px;
					}
				</style>
			</head>
			<body>
				<h1>${titre}</h1>

				<p><strong>${typeInscription === 'course' ? 'Course' : 'Série'} :</strong> ${getCurrentTitle()}</p>
				${typeInscription === 'course' ? `<p><strong>Date :</strong> ${getCurrentDate()}</p>` : ''}
				<p><strong>Classe :</strong> ${getCurrentClasse()}</p>

				<table>
					<thead>
						<tr>
							<th>Nom du bateau</th>
							<th>No voile</th>
							<th>Classe</th>
							<th>Barreur</th>
							<th>Type handicap</th>
							<th>Valeur handicap</th>
							<th>Signature</th>
						</tr>
					</thead>
					<tbody>
						${rows}
					</tbody>
				</table>

				<div class="signature-block">
					<p>Signature responsable :</p>
					<div class="signature-line"></div>
				</div>
			</body>
			</html>
		`;

		const win = window.open('', '_blank');
		win.document.write(html);
		win.document.close();
		win.print();
	}
</script>

<svelte:head>
	<title>Inscriptions - YRR</title>
</svelte:head>

<div class="page">
	<div class="left-panel">
		<div class="type-switch">
			<button
				class:selected-type={typeInscription === 'course'}
				on:click={async () => {
					typeInscription = 'course';
					await refreshParticipants();
				}}
			>
				Courses
			</button>

			<button
				class:selected-type={typeInscription === 'serie'}
				on:click={async () => {
					typeInscription = 'serie';
					await refreshParticipants();
				}}
			>
				Séries
			</button>
		</div>

		{#if typeInscription === 'course'}
			<h1>Courses</h1>

			{#if loadingCourses}
				<p>Chargement des courses...</p>
			{:else if courses.length === 0}
				<p>Aucune course disponible.</p>
			{:else}
				{#each courses as course}
					<button
						class:selected={selectedCourse?.id === course.id}
						class="course-button"
						on:click={() => selectCourse(course)}
					>
						<div class="course-top">
							<strong>{course.nom}</strong>
							<span
								class:badge-finished={course.terminee}
								class:badge-active={!course.terminee}
								class="status-badge"
							>
								{course.terminee ? 'Terminée' : 'En cours'}
							</span>
						</div>
						<span>{course.date}</span>
						<small>{course.classe}</small>
					</button>
				{/each}
			{/if}
		{:else}
			<h1>Séries</h1>

			{#if loadingSeries}
				<p>Chargement des séries...</p>
			{:else if series.length === 0}
				<p>Aucune série disponible.</p>
			{:else}
				{#each series as serie}
					<button
						class:selected={selectedSerie?.id === serie.id}
						class="course-button"
						on:click={() => selectSerie(serie)}
					>
						<div class="course-top">
							<strong>{serie.nom}</strong>
							<span class="status-badge badge-active">{serie.type}</span>
						</div>
						<span>Classe : {serie.classe}</span>
						<small>
							{serie.nombreCourses} courses | {serie.nombreComptabilisees} comptabilisées
						</small>
					</button>
				{/each}
			{/if}
		{/if}
	</div>

	<button
		class="print-btn"
		on:click={imprimerFormulaire}
		disabled={
			(typeInscription === 'course' && !selectedCourse) ||
			(typeInscription === 'serie' && !selectedSerie)
		}
	>
		Imprimer formulaire
	</button>

	<div class="right-panel">
		<div class="print-form">
			<h1>
				{typeInscription === 'course'
					? 'FICHE D’INSCRIPTION COURSE'
					: 'FICHE D’INSCRIPTION SÉRIE'}
			</h1>

			<p>
				<strong>{typeInscription === 'course' ? 'Course' : 'Série'} :</strong>
				{getCurrentTitle()}
			</p>

			{#if typeInscription === 'course'}
				<p><strong>Date :</strong> {getCurrentDate()}</p>
			{/if}

			<p><strong>Classe :</strong> {getCurrentClasse()}</p>

			<table class="print-table">
				<thead>
					<tr>
						<th>Nom du bateau</th>
						<th>No voile</th>
						<th>Classe</th>
						<th>Barreur</th>
						<th>Type handicap</th>
						<th>Valeur handicap</th>
						<th>Signature</th>
					</tr>
				</thead>

				<tbody>
					{#each Array(15) as _, i}
						<tr>
							<td>{participants[i]?.nom ?? ''}</td>
							<td>{participants[i]?.numeroVoile ?? ''}</td>
							<td>{participants[i]?.classe ?? ''}</td>
							<td>{participants[i]?.barreur ?? ''}</td>
							<td>{participants[i]?.typeHandicap ?? ''}</td>
							<td>{participants[i]?.valeurHandicap ?? ''}</td>
							<td></td>
						</tr>
					{/each}
				</tbody>
			</table>

			<div class="signature-block">
				<p>Signature responsable :</p>
				<div class="signature-line"></div>
			</div>
		</div>

		{#if typeInscription === 'course' && selectedCourse}
			<h2>Participants - {selectedCourse.nom}</h2>
			<p class="subtitle">
				Date : {selectedCourse.date} | Classe : {selectedCourse.classe}
			</p>

			{#if selectedCourse.terminee}
				<div class="warning-box">
					Cette course est terminée. Les participants sont visibles, mais on ne peut plus en ajouter.
				</div>
			{/if}
		{:else if typeInscription === 'serie' && selectedSerie}
			<h2>Participants - {selectedSerie.nom}</h2>
			<p class="subtitle">
				Type : {selectedSerie.type} | Classe : {selectedSerie.classe} | Courses :
				{selectedSerie.nombreCourses}
			</p>
		{:else}
			<h2>Inscriptions</h2>
		{/if}

		{#if errorMessage}
			<div class="error-box">{errorMessage}</div>
		{/if}

		{#if (typeInscription === 'course' && selectedCourse) || (typeInscription === 'serie' && selectedSerie)}
			<div class="top-actions">
				<button class:active={mode === 'voir'} class="top-button" on:click={() => (mode = 'voir')}>
					Voir les participants
				</button>

				<button
					class:active={mode === 'ajouter'}
					class="top-button"
					on:click={() => (mode = 'ajouter')}
					disabled={typeInscription === 'course' && selectedCourse?.terminee}
				>
					Ajouter des bateaux
				</button>
			</div>

			{#if mode === 'voir'}
				<div class="content-box">
					<h3>Participants inscrits</h3>

					{#if loadingParticipants}
						<p>Chargement des participants...</p>
					{:else if getParticipants().length > 0}
						<table>
							<thead>
								<tr>
									<th>Nom du bateau</th>
									<th>No voile</th>
									<th>Classe</th>
									<th>Barreur</th>
									<th>Type handicap</th>
									<th>Valeur handicap</th>
									<th>Action</th>
								</tr>
							</thead>
							<tbody>
								{#each getParticipants() as bateau}
									<tr>
										<td>{bateau.nom}</td>
										<td>{bateau.numeroVoile}</td>
										<td>{bateau.classe}</td>
										<td>{bateau.barreur}</td>
										<td>{bateau.typeHandicap}</td>
										<td>{bateau.valeurHandicap}</td>
										<td>
	{#if typeInscription === 'course'}
		<button
			type="button"
			class="delete-button"
			on:click={() => retirerParticipant(bateau)}
			disabled={selectedCourse?.terminee}
		>
			Supprimer
		</button>
	{:else}
		<button
			type="button"
			class="delete-button"
			on:click={() => retirerParticipantSerie(bateau)}
		>
			Supprimer
		</button>
	{/if}
</td>
									</tr>
								{/each}
							</tbody>
						</table>
					{:else}
						<p>Aucun participant inscrit.</p>
					{/if}
				</div>
			{/if}

			{#if mode === 'ajouter'}
				<div class="content-box">
					<h3>
						{#if typeInscription === 'course'}
							Ajouter un ou plusieurs bateaux à la course
						{:else}
							Ajouter un ou plusieurs bateaux à la série
						{/if}
					</h3>

					{#if loadingBoats}
						<p>Chargement des bateaux...</p>
					{:else if getBateauxDisponibles().length > 0}
						<div class="boat-list">
							{#each getBateauxDisponibles() as bateau}
								<label class="boat-item">
									<input
										type="checkbox"
										checked={bateauxSelectionnes.includes(bateau.id)}
										on:change={() => toggleBoatSelection(bateau.id)}
									/>

									<div>
										<strong>{bateau.nom}</strong>
										<div>No voile : {bateau.numeroVoile}</div>
										<div>Classe : {bateau.classe}</div>
										<div>Barreur : {bateau.barreur}</div>
										<div>Type handicap : {bateau.typeHandicap || '—'}</div>
										<div>Valeur handicap : {bateau.valeurHandicap || '—'}</div>
									</div>
								</label>
							{/each}
						</div>

						<button
							class="submit-button"
							on:click={ajouterParticipants}
							disabled={bateauxSelectionnes.length === 0 || submitting}
						>
							{submitting
								? 'Ajout en cours...'
								: typeInscription === 'course'
									? 'Inscrire à la course'
									: 'Inscrire à la série'}
						</button>
					{:else}
						<p>
							{#if typeInscription === 'course'}
								Tous les bateaux disponibles sont déjà inscrits à cette course.
							{:else}
								Tous les bateaux disponibles sont déjà inscrits à cette série.
							{/if}
						</p>
					{/if}
				</div>
			{/if}
		{:else}
			<p>
				{#if typeInscription === 'course'}
					Aucune course sélectionnée.
				{:else}
					Aucune série sélectionnée.
				{/if}
			</p>
		{/if}
	</div>
</div>

<style>
	:global(body) {
		margin: 0;
		font-family: Arial, sans-serif;
		background: #f4f6f8;
	}

	.page {
		display: grid;
		grid-template-columns: 320px 1fr;
		gap: 24px;
		padding: 24px;
		min-height: 100vh;
		box-sizing: border-box;
	}

	.left-panel,
	.right-panel {
		background: white;
		border-radius: 10px;
		padding: 20px;
		box-shadow: 0 0 10px rgba(0, 0, 0, 0.08);
	}

	.type-switch {
		display: flex;
		gap: 10px;
		margin-bottom: 20px;
	}

	.type-switch button {
		flex: 1;
		padding: 10px 12px;
		border: none;
		border-radius: 8px;
		background: #d8dde3;
		cursor: pointer;
		font-weight: bold;
	}

	.type-switch button.selected-type {
		background: #4f78a8;
		color: white;
	}

	h1,
	h2,
	h3 {
		margin-top: 0;
	}

	.subtitle {
		color: #666;
		margin-bottom: 20px;
	}

	.course-button {
		width: 100%;
		text-align: left;
		padding: 12px;
		margin-bottom: 10px;
		border: 1px solid #d0d0d0;
		border-radius: 8px;
		background: #fafafa;
		cursor: pointer;
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.course-button:hover {
		background: #f0f0f0;
	}

	.course-button.selected {
		background: #dfe9f3;
		border-color: #7a9bbd;
	}

	.course-top {
		display: flex;
		justify-content: space-between;
		align-items: center;
		gap: 8px;
	}

	.status-badge {
		font-size: 0.75rem;
		padding: 4px 8px;
		border-radius: 999px;
		font-weight: bold;
		white-space: nowrap;
	}

	.badge-active {
		background: #e6f6ea;
		color: #1e7a38;
	}

	.badge-finished {
		background: #ececec;
		color: #555;
	}

	.course-button span,
	.course-button small {
		color: #666;
	}

	.warning-box {
		background: #fff4e5;
		color: #8a5a00;
		border: 1px solid #f0d3a2;
		padding: 12px 14px;
		border-radius: 8px;
		margin-bottom: 16px;
	}

	.error-box {
		background: #fdecec;
		color: #8f1d1d;
		border: 1px solid #f5bcbc;
		padding: 12px 14px;
		border-radius: 8px;
		margin-bottom: 16px;
	}

	.top-actions {
		display: flex;
		gap: 12px;
		margin-bottom: 20px;
	}

	.top-button,
	.submit-button {
		padding: 10px 14px;
		border: none;
		border-radius: 6px;
		background: #6f6f6f;
		color: white;
		cursor: pointer;
	}

	.top-button.active {
		background: #4f78a8;
	}

	.top-button:hover,
	.submit-button:hover {
		background: #5d5d5d;
	}

	.top-button:disabled,
	.submit-button:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.content-box {
		background: #fafafa;
		border: 1px solid #e0e0e0;
		border-radius: 8px;
		padding: 20px;
		overflow-x: auto;
	}

	table {
		width: 100%;
		border-collapse: collapse;
		margin-top: 12px;
	}

	th,
	td {
		border: 1px solid #ddd;
		padding: 10px;
		text-align: left;
	}

	th {
		background: #f0f0f0;
	}

	.delete-button {
		padding: 8px 12px;
		border: none;
		border-radius: 6px;
		background: #b23a3a;
		color: white;
		cursor: pointer;
	}

	.delete-button:hover:enabled {
		background: #992f2f;
	}

	.delete-button:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.boat-list {
		display: flex;
		flex-direction: column;
		gap: 12px;
		margin-bottom: 20px;
	}

	.boat-item {
		display: flex;
		gap: 12px;
		align-items: flex-start;
		background: white;
		padding: 12px;
		border: 1px solid #ddd;
		border-radius: 8px;
		cursor: pointer;
	}

	.print-btn {
		position: fixed;
		bottom: 20px;
		right: 20px;
		padding: 10px 14px;
		font-size: 14px;
		background: #2563eb;
		color: white;
		border: none;
		border-radius: 8px;
		cursor: pointer;
		z-index: 1000;
		width: auto;
	}

	.print-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.print-form {
		display: none;
	}

	.signature-block {
		margin-top: 32px;
	}

	.signature-line {
		border-bottom: 1px solid black;
		width: 260px;
		height: 32px;
	}

	@media print {
		.left-panel,
		.top-actions,
		.content-box,
		.subtitle,
		.warning-box,
		.error-box,
		.print-btn,
		button,
		nav,
		header {
			display: none !important;
		}

		.page {
			display: block;
			padding: 0;
			min-height: auto;
		}

		.right-panel {
			box-shadow: none;
			border: none;
			padding: 0;
		}

		.right-panel > h2,
		.right-panel > p {
			display: none;
		}

		.print-form {
			display: block;
		}

		body {
			background: white;
		}

		.print-form h1 {
			text-align: center;
			font-size: 18px;
			margin-bottom: 24px;
		}

		.print-table {
			width: 100%;
			border-collapse: collapse;
		}

		.print-table th,
		.print-table td {
			border: 1px solid black;
			padding: 8px;
			font-size: 12px;
			height: 28px;
		}

		.signature-line {
			border-bottom: 1px solid black;
			width: 260px;
			height: 32px;
		}
	}
</style>