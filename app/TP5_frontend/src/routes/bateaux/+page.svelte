<script>
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';

	const API_BASE = 'http://localhost:4000/api';

	let bateaux = [];

	let classes = [];
	let selectedClassId = '';

	let nomBateau = '';
	let numeroVoile = '';
	let classeBateau = '';
	let nomBarreur = '';
	let typeHandicap = 'PY';
	let valeurHandicap = '';

	let editMode = false;
	let editingBoatId = null;

	let errors = {};
	let generalError = '';
	let successMessage = '';

	const texteRegex = /^[A-Za-zÀ-ÿ0-9 _-]*$/;

	function getAuthHeaders(includeJson = false) {
		const token = localStorage.getItem('token');

		if (!token) {
			alert('Session expirée. Veuillez vous reconnecter.');
			goto('/connexion');
			throw new Error('Token manquant');
		}

		return {
			...(includeJson ? { 'Content-Type': 'application/json' } : {}),
			Authorization: `Bearer ${token}`
		};
	}

	function normalizeBoat(boat) {
	return {
		id: boat._id?.$oid ?? boat.id ?? boat._id,
		nom: boat.nom ?? boat.name ?? '',
		noVoile: String(boat.noVoile ?? boat.numeroVoile ?? boat.sail_number ?? ''),
		classe: boat.classe ?? boat.class_name ?? boat.class ?? '',
		classId: boat.class_id ?? boat.boat_class_id ?? '',
		NomBarreur: boat.NomBarreur ?? boat.barreur ?? boat.helm_name ?? '',
		typeHandicap: boat.typeHandicap ?? boat.handicap_type ?? boat.type_handicap ?? '',
		valeurHandicap: boat.valeurHandicap ?? boat.handicap_value ?? boat.valeur_handicap ?? ''
	};
}

	function normalizeClass(classe) {
	return {
		id: classe._id?.$oid ?? classe.id ?? classe._id,
		name: classe.name ?? classe.display_name ?? classe.nom ?? '',
		handicapType: classe.handicap_type ?? classe.typeHandicap ?? classe.type_handicap ?? '',
		handicapValue: classe.handicap_value ?? classe.valeurHandicap ?? classe.valeur_handicap ?? ''
	};
}

	async function chargerBateaux() {
		try {
			const response = await fetch(`${API_BASE}/getboats`, {
				headers: getAuthHeaders()
			});

			if (response.status === 401) {
				localStorage.removeItem('token');
				localStorage.removeItem('user');
				goto('/connexion');
				return;
			}

			if (!response.ok) {
				throw new Error('Erreur lors du chargement des bateaux');
			}

			const data = await response.json();
			bateaux = data.map(normalizeBoat);
		} catch (error) {
			console.error(error);
			if (error.message !== 'Token manquant') {
				generalError = 'Erreur lors du chargement des bateaux';
			}
		}
	}

	async function chargerClasses() {
	try {
		const response = await fetch(`${API_BASE}/classes`, {
			headers: getAuthHeaders()
		});

		if (response.status === 401) {
			localStorage.removeItem('token');
			localStorage.removeItem('user');
			goto('/connexion');
			return;
		}

		if (!response.ok) {
			throw new Error('Erreur lors du chargement des classes de bateaux');
		}

		const data = await response.json();
		classes = data.map(normalizeClass);
	} catch (error) {
		console.error(error);
		if (error.message !== 'Token manquant') {
			generalError = 'Erreur lors du chargement des classes de bateaux.';
		}
	}
}

	onMount(async () => {
	await chargerClasses();
	await chargerBateaux();
});

function onClasseChange() {
	const selectedClass = classes.find((classe) => String(classe.id) === String(selectedClassId));

	if (!selectedClass) {
		classeBateau = '';
		typeHandicap = 'PY';
		valeurHandicap = '';
		setFieldError('classeBateau', 'La classe du bateau est obligatoire.');
		return;
	}

	classeBateau = selectedClass.name;
	typeHandicap = selectedClass.handicapType;
	valeurHandicap = String(selectedClass.handicapValue ?? '');

	clearFieldError('classeBateau');

	if (numeroVoile.trim() !== '') {
		validateNumeroVoile();
	}
}

	function setFieldError(field, message) {
		errors = {
			...errors,
			[field]: message
		};
	}

	function clearFieldError(field) {
		const newErrors = { ...errors };
		delete newErrors[field];
		errors = newErrors;
	}

	function validateNomBateau() {
		const value = nomBateau.trim();

		if (value === '') {
			clearFieldError('nomBateau');
			return true;
		}

		if (value.length > 25) {
			setFieldError('nomBateau', 'Le nom du bateau doit avoir un maximum de 25 caractères.');
			return false;
		}

		if (!texteRegex.test(value)) {
			setFieldError(
				'nomBateau',
				'Le nom du bateau peut contenir seulement des lettres, chiffres, espaces, - ou _.'
			);
			return false;
		}

		clearFieldError('nomBateau');
		return true;
	}

	function validateNumeroVoile() {
		const value = numeroVoile.trim();

		if (value === '') {
			setFieldError('numeroVoile', 'Le numéro de voile est obligatoire.');
			return false;
		}

		if (!/^\d+$/.test(value)) {
			setFieldError('numeroVoile', 'Le numéro de voile doit contenir uniquement des chiffres.');
			return false;
		}

		if (value.length > 6) {
			setFieldError('numeroVoile', 'Le numéro de voile doit avoir un maximum de 6 chiffres.');
			return false;
		}

		const duplicate = bateaux.some((bateau) => {
			const sameClass = String(bateau.classe).trim().toLowerCase() === classeBateau.trim().toLowerCase();
			const sameSailNumber = String(bateau.noVoile).trim() === value;
			const notCurrentBoat = String(bateau.id) !== String(editingBoatId);

			return sameClass && sameSailNumber && notCurrentBoat;
		});

		if (duplicate) {
			setFieldError(
				'numeroVoile',
				'Ce numéro de voile existe déjà pour cette classe de bateau.'
			);
			return false;
		}

		clearFieldError('numeroVoile');
		return true;
	}

	function validateClasseBateau() {
	if (!selectedClassId) {
		setFieldError('classeBateau', 'La classe du bateau est obligatoire.');
		return false;
	}

	const selectedClass = classes.find((classe) => String(classe.id) === String(selectedClassId));

	if (!selectedClass) {
		setFieldError('classeBateau', 'La classe sélectionnée est invalide.');
		return false;
	}

	classeBateau = selectedClass.name;
	typeHandicap = selectedClass.handicapType;
	valeurHandicap = String(selectedClass.handicapValue ?? '');

	clearFieldError('classeBateau');

	if (numeroVoile.trim() !== '') {
		validateNumeroVoile();
	}

	return true;
}

	function validateNomBarreur() {
		const value = nomBarreur.trim();

		if (value === '') {
			clearFieldError('nomBarreur');
			return true;
		}

		if (value.length > 25) {
			setFieldError('nomBarreur', 'Le nom du barreur doit avoir un maximum de 25 caractères.');
			return false;
		}

		if (!texteRegex.test(value)) {
			setFieldError(
				'nomBarreur',
				'Le nom du barreur peut contenir seulement des lettres, chiffres, espaces, - ou _.'
			);
			return false;
		}

		clearFieldError('nomBarreur');
		return true;
	}

	function validateTypeHandicap() {
		const value = typeHandicap.trim().toUpperCase();

		if (value !== 'PY' && value !== 'TMF') {
			setFieldError('typeHandicap', 'Le type de handicap doit être PY ou TMF.');
			return false;
		}

		typeHandicap = value;
		clearFieldError('typeHandicap');

		if (valeurHandicap.trim() !== '') {
			validateValeurHandicap();
		}

		return true;
	}

	function validateValeurHandicap() {
		const value = valeurHandicap.trim();

		if (value === '') {
			setFieldError('valeurHandicap', 'La valeur de handicap est obligatoire.');
			return false;
		}

		const type = typeHandicap.trim().toUpperCase();

		if (type === 'PY') {
			if (!/^\d{4}$/.test(value)) {
				setFieldError('valeurHandicap', 'Pour PY, la valeur doit être un entier à 4 chiffres.');
				return false;
			}
		} else if (type === 'TMF') {
			if (!/^\d+(\.\d{1,3})?$/.test(value)) {
				setFieldError(
					'valeurHandicap',
					'Pour TMF, la valeur doit être un nombre décimal, par exemple 0.977.'
				);
				return false;
			}
		}

		clearFieldError('valeurHandicap');
		return true;
	}

	function validateForm() {
		generalError = '';
		successMessage = '';

		const validations = [
	validateNomBateau(),
	validateClasseBateau(),
	validateNumeroVoile(),
	validateNomBarreur()
];

		return validations.every(Boolean);
	}

	function modifierBateau(bateau) {
		editMode = true;
		editingBoatId = bateau.id;

		nomBateau = bateau.nom ?? '';
		numeroVoile = bateau.noVoile ?? '';
		nomBarreur = bateau.NomBarreur ?? '';
		classeBateau = bateau.classe ?? '';
selectedClassId = bateau.classId ?? '';

if (!selectedClassId && classeBateau) {
	const matchingClass = classes.find(
		(classe) => String(classe.name).trim().toLowerCase() === String(classeBateau).trim().toLowerCase()
	);

	if (matchingClass) {
		selectedClassId = matchingClass.id;
	}
}

const selectedClass = classes.find((classe) => String(classe.id) === String(selectedClassId));

if (selectedClass) {
	classeBateau = selectedClass.name;
	typeHandicap = selectedClass.handicapType;
	valeurHandicap = String(selectedClass.handicapValue ?? '');
} else {
	typeHandicap = bateau.typeHandicap || 'PY';
	valeurHandicap = String(bateau.valeurHandicap ?? '');
}

		errors = {};
		generalError = '';
		successMessage = '';
	}

	function annulerModification() {
		editMode = false;
		editingBoatId = null;

		nomBateau = '';
numeroVoile = '';
classeBateau = '';
selectedClassId = '';
nomBarreur = '';
typeHandicap = 'PY';
valeurHandicap = '';

		errors = {};
		generalError = '';
		successMessage = '';
	}

	async function enregistrerBateau() {
		if (!validateForm()) {
			generalError = 'Veuillez corriger les erreurs avant d’enregistrer.';
			return;
		}

		try {
			const url = editMode
				? `${API_BASE}/updateboat/${editingBoatId}`
				: `${API_BASE}/addboat`;

			const method = editMode ? 'PUT' : 'POST';

			const response = await fetch(url, {
				method,
				headers: getAuthHeaders(true),
				body: JSON.stringify({
	nomBateau: nomBateau.trim(),
	numeroVoile: numeroVoile.trim(),
	classeBateau: classeBateau.trim(),
	class_id: selectedClassId,
	boat_class_id: selectedClassId,
	nomBarreur: nomBarreur.trim(),
	typeHandicap: typeHandicap.trim().toUpperCase(),
	valeurHandicap:
		typeHandicap.trim().toUpperCase() === 'PY'
			? Number(valeurHandicap)
			: Number(String(valeurHandicap).replace(',', '.'))
})
			});

			if (response.status === 401) {
				localStorage.removeItem('token');
				localStorage.removeItem('user');
				goto('/connexion');
				return;
			}

			if (!response.ok) {
				const err = await response.json().catch(() => ({}));
				throw new Error(
					err.error ||
						(editMode
							? 'Erreur lors de la modification du bateau'
							: 'Erreur lors de l’ajout du bateau')
				);
			}

			await chargerBateaux();
			successMessage = editMode ? 'Bateau modifié avec succès.' : 'Bateau ajouté avec succès.';
			annulerModification();
		} catch (error) {
			console.error(error);
			if (error.message !== 'Token manquant') {
				generalError = error.message || 'Erreur lors de l’enregistrement du bateau';
			}
		}
	}

	async function deleteBoat(boatId, boatName) {
		const confirmed = confirm(`Supprimer le bateau "${boatName || 'sans nom'}" ?`);
		if (!confirmed) return;

		try {
			const response = await fetch(`${API_BASE}/deleteboat/${boatId}`, {
				method: 'DELETE',
				headers: getAuthHeaders()
			});

			if (response.status === 401) {
				localStorage.removeItem('token');
				localStorage.removeItem('user');
				goto('/connexion');
				return;
			}

			if (!response.ok) {
				const err = await response.json().catch(() => ({}));
				throw new Error(
					err.error ||
						'Impossible de supprimer ce bateau, car il est peut-être déjà inscrit à une ou plusieurs courses.'
				);
			}

			bateaux = bateaux.filter((bateau) => String(bateau.id) !== String(boatId));

			if (String(editingBoatId) === String(boatId)) {
				annulerModification();
			}

			successMessage = 'Bateau supprimé avec succès.';
		} catch (error) {
			console.error(error);
			if (error.message !== 'Token manquant') {
				generalError =
					error.message ||
					'Impossible de supprimer ce bateau, car il est déjà inscrit à une ou plusieurs courses.';
			}
		}
	}

</script>

<h2>{editMode ? 'Modifier un bateau' : 'Ajouter un bateau'}</h2>

{#if generalError}
	<div class="message error-message">{generalError}</div>
{/if}

{#if successMessage}
	<div class="message success-message">{successMessage}</div>
{/if}

<form on:submit|preventDefault={enregistrerBateau}>
	<h2>{editMode ? 'Modification du bateau' : 'Informations du bateau'}</h2>

	

	<label for="numeroVoile">Numéro de voile <strong>*</strong></label>
	<input
		type="text"
		id="numeroVoile"
		bind:value={numeroVoile}
		on:blur={validateNumeroVoile}
		class:error-input={errors.numeroVoile}
		maxlength="6"
	/>
	{#if errors.numeroVoile}
		<p class="field-error">{errors.numeroVoile}</p>
	{/if}

	<label for="classeBateau">Classe du bateau <strong>*</strong></label>
<select
	id="classeBateau"
	bind:value={selectedClassId}
	on:change={onClasseChange}
	on:blur={validateClasseBateau}
	class:error-input={errors.classeBateau}
	disabled={classes.length === 0}
>
	<option value="">-- Choisir une classe --</option>
	{#each classes as classe}
		<option value={classe.id}>
			{classe.name} - {classe.handicapType} {classe.handicapValue}
		</option>
	{/each}
</select>

{#if classes.length === 0}
	<p class="field-error">Aucune classe disponible. Créez d’abord une classe de bateau.</p>
{/if}

{#if errors.classeBateau}
	<p class="field-error">{errors.classeBateau}</p>
{/if}
<div class="readonly-handicap">
	<p><strong>Type handicap :</strong> {typeHandicap || '—'}</p>
	<p><strong>Valeur handicap :</strong> {valeurHandicap || '—'}</p>
</div>

<label for="nomBateau">Nom du bateau <span>optionnel</span></label>
	<input
		type="text"
		id="nomBateau"
		bind:value={nomBateau}
		on:blur={validateNomBateau}
		class:error-input={errors.nomBateau}
		maxlength="25"
	/>
	{#if errors.nomBateau}
		<p class="field-error">{errors.nomBateau}</p>
	{/if}
	<label for="nomBarreur">Nom du barreur <span>optionnel</span></label>
	<input
		type="text"
		id="nomBarreur"
		bind:value={nomBarreur}
		on:blur={validateNomBarreur}
		class:error-input={errors.nomBarreur}
		maxlength="25"
	/>
	{#if errors.nomBarreur}
		<p class="field-error">{errors.nomBarreur}</p>
	{/if}

	

	<button type="submit">
		{editMode ? 'Enregistrer les modifications' : 'Envoyer'}
	</button>

	{#if editMode}
		<button type="button" class="cancel-button" on:click={annulerModification}>
			Annuler
		</button>
	{/if}
</form>

<h2>Liste des bateaux</h2>

<div class="table-container">
	<table class="boats-table">
		<thead>
			<tr>
				<th>Nom</th>
				<th>Num</th>
				<th>Classe</th>
				<th>Barreur</th>
				<th>Type handicap</th>
				<th>Valeur handicap</th>
				<th>Action</th>
			</tr>
		</thead>

		<tbody>
			{#each [...bateaux].reverse() as bateau}
				<tr>
					<td>{bateau.nom || '—'}</td>
					<td>{bateau.noVoile}</td>
					<td>{bateau.classe}</td>
					<td>{bateau.NomBarreur || '—'}</td>
					<td>{bateau.typeHandicap}</td>
					<td>{bateau.valeurHandicap}</td>
					<td class="actions-cell">
						<button
							type="button"
							class="edit-button"
							on:click={() => modifierBateau(bateau)}
						>
							Modifier
						</button>

						<button
							type="button"
							class="delete-button"
							on:click={() => deleteBoat(bateau.id, bateau.nom)}
						>
							Supprimer
						</button>
					</td>
				</tr>
			{/each}
		</tbody>
	</table>
</div>

<style>
	:global(body) {
		font-family: Arial, sans-serif;
		background-color: #f4f6f8;
		margin: 0;
	}

	h2 {
		margin-top: 0;
		text-align: center;
	}

	form {
		background: white;
		padding: 20px;
		max-width: 420px;
		margin: 0 auto 24px auto;
		border-radius: 8px;
		box-shadow: 0 0 10px rgba(0, 0, 0, 0.1);
	}

	label {
		display: block;
		margin-top: 12px;
		font-weight: 600;
	}

	label span {
		color: #777;
		font-size: 0.85rem;
		font-weight: normal;
	}

	.readonly-handicap {
	margin-top: 14px;
	padding: 12px;
	background: #f4f6f8;
	border: 1px solid #ddd;
	border-radius: 6px;
}

.readonly-handicap p {
	margin: 4px 0;
	color: #333;
}

	label strong {
		color: #b23a3a;
	}

	input,
	select {
		width: 100%;
		padding: 8px;
		margin-top: 5px;
		border-radius: 4px;
		border: 1px solid #ccc;
		box-sizing: border-box;
	}

	.error-input {
		border-color: #b23a3a;
		background: #fff7f7;
	}

	.field-error {
		color: #b23a3a;
		font-size: 0.85rem;
		margin: 5px 0 0 0;
	}

	.message {
		max-width: 420px;
		margin: 0 auto 16px auto;
		padding: 12px 14px;
		border-radius: 8px;
		font-weight: 600;
	}

	.error-message {
		background: #fdecec;
		color: #8f1d1d;
		border: 1px solid #f5bcbc;
	}

	.success-message {
		background: #e6f6ea;
		color: #1e7a38;
		border: 1px solid #b7e2c2;
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

	button:hover {
		background-color: #777777;
	}

	.cancel-button {
		background: #9a9a9a;
	}

	.cancel-button:hover {
		background: #878787;
	}

	.table-container {
		background: white;
		border-radius: 14px;
		box-shadow: 0 8px 24px rgba(0, 0, 0, 0.08);
		overflow: hidden;
		border: 1px solid #e6e6e6;
		margin: 0 20px 30px 20px;
	}

	.boats-table {
		width: 100%;
		border-collapse: collapse;
		font-family: Arial, sans-serif;
	}

	.boats-table thead {
		background: linear-gradient(to right, #5f6f82, #7a8da3);
		color: white;
	}

	.boats-table th {
		text-align: left;
		padding: 14px 16px;
		font-size: 0.95rem;
		letter-spacing: 0.02em;
	}

	.boats-table td {
		padding: 14px 16px;
		border-top: 1px solid #eeeeee;
		color: #333;
		font-size: 0.95rem;
	}

	.boats-table tbody tr:nth-child(even) {
		background: #fafbfc;
	}

	.boats-table tbody tr:hover {
		background: #eef4fa;
		transition: background 0.2s ease;
	}

	.boats-table td:first-child {
		font-weight: 600;
	}

	.actions-cell {
		display: flex;
		gap: 8px;
		flex-wrap: wrap;
	}

	.edit-button,
	.delete-button {
		margin-top: 0;
		width: auto;
		padding: 8px 12px;
	}

	.edit-button {
		background: #4f78a8;
	}

	.edit-button:hover {
		background: #42678f;
	}

	.delete-button {
		background: #b23a3a;
	}

	.delete-button:hover {
		background: #992f2f;
	}

	@media (max-width: 900px) {
		.table-container {
			overflow-x: auto;
		}

		.boats-table {
			min-width: 900px;
		}
	}
</style>