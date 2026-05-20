<script>
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';

	const API_BASE = 'http://localhost:4000/api';

	let classes = [];

	let nomClasse = '';
	let typeHandicap = 'PY';
	let valeurHandicap = '';

	let editMode = false;
	let editingClassId = null;

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

	function normalizeClass(classe) {
		return {
			id: classe._id?.$oid ?? classe.id ?? classe._id,
			name: classe.name ?? classe.display_name ?? classe.nom ?? '',
			normalizedName: classe.normalized_name ?? classe.name ?? '',
			handicapType: classe.handicap_type ?? classe.typeHandicap ?? classe.type_handicap ?? '',
			handicapValue: classe.handicap_value ?? classe.valeurHandicap ?? classe.valeur_handicap ?? ''
		};
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
	});

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

	function validateNomClasse() {
		const value = nomClasse.trim();

		if (value === '') {
			setFieldError('nomClasse', 'Le nom de la classe est obligatoire.');
			return false;
		}

		if (value.length > 25) {
			setFieldError('nomClasse', 'Le nom de la classe doit avoir un maximum de 25 caractères.');
			return false;
		}

		if (!texteRegex.test(value)) {
			setFieldError(
				'nomClasse',
				'Le nom de la classe peut contenir seulement des lettres, chiffres, espaces, - ou _.'
			);
			return false;
		}

		const duplicate = classes.some((classe) => {
			const sameName = String(classe.name).trim().toLowerCase() === value.toLowerCase();
			const notCurrentClass = String(classe.id) !== String(editingClassId);

			return sameName && notCurrentClass;
		});

		if (duplicate) {
			setFieldError('nomClasse', 'Une classe avec ce nom existe déjà.');
			return false;
		}

		clearFieldError('nomClasse');
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
		const value = valeurHandicap.trim().replace(',', '.');

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
			validateNomClasse(),
			validateTypeHandicap(),
			validateValeurHandicap()
		];

		return validations.every(Boolean);
	}

	function modifierClasse(classe) {
		editMode = true;
		editingClassId = classe.id;

		nomClasse = classe.name ?? '';
		typeHandicap = classe.handicapType || 'PY';
		valeurHandicap = String(classe.handicapValue ?? '');

		errors = {};
		generalError = '';
		successMessage = '';
	}

	function annulerModification() {
		editMode = false;
		editingClassId = null;

		nomClasse = '';
		typeHandicap = 'PY';
		valeurHandicap = '';

		errors = {};
		generalError = '';
		successMessage = '';
	}

	async function enregistrerClasse() {
		if (!validateForm()) {
			generalError = 'Veuillez corriger les erreurs avant d’enregistrer.';
			return;
		}

		try {
			const url = editMode
				? `${API_BASE}/classes/${editingClassId}`
				: `${API_BASE}/classes`;

			const method = editMode ? 'PUT' : 'POST';

			const response = await fetch(url, {
				method,
				headers: getAuthHeaders(true),
				body: JSON.stringify({
					name: nomClasse.trim(),
					handicap_type: typeHandicap.trim().toUpperCase(),
					handicap_value:
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
							? 'Erreur lors de la modification de la classe'
							: 'Erreur lors de l’ajout de la classe')
				);
			}

			await chargerClasses();
			successMessage = editMode
				? 'Classe de bateau modifiée avec succès.'
				: 'Classe de bateau ajoutée avec succès.';

			annulerModification();
		} catch (error) {
			console.error(error);
			if (error.message !== 'Token manquant') {
				generalError = error.message || 'Erreur lors de l’enregistrement de la classe.';
			}
		}
	}

	async function supprimerClasse(classId, className) {
		const confirmed = confirm(`Supprimer la classe "${className}" ?`);
		if (!confirmed) return;

		try {
			const response = await fetch(`${API_BASE}/classes/${classId}`, {
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
						'Impossible de supprimer cette classe, car elle est peut-être déjà utilisée par un bateau.'
				);
			}

			classes = classes.filter((classe) => String(classe.id) !== String(classId));

			if (String(editingClassId) === String(classId)) {
				annulerModification();
			}

			successMessage = 'Classe de bateau supprimée avec succès.';
		} catch (error) {
			console.error(error);
			if (error.message !== 'Token manquant') {
				generalError =
					error.message ||
					'Impossible de supprimer cette classe, car elle est déjà utilisée par un ou plusieurs bateaux.';
			}
		}
	}
</script>

<h2>{editMode ? 'Modifier une classe de bateau' : 'Ajouter une classe de bateau'}</h2>

{#if generalError}
	<div class="message error-message">{generalError}</div>
{/if}

{#if successMessage}
	<div class="message success-message">{successMessage}</div>
{/if}

<form on:submit|preventDefault={enregistrerClasse}>
	<h2>{editMode ? 'Modification de la classe' : 'Informations de la classe'}</h2>

	<label for="nomClasse">Nom de la classe <strong>*</strong></label>
	<input
		type="text"
		id="nomClasse"
		bind:value={nomClasse}
		on:blur={validateNomClasse}
		class:error-input={errors.nomClasse}
		maxlength="25"
		placeholder="Ex: Laser, J22, Optimist"
	/>
	{#if errors.nomClasse}
		<p class="field-error">{errors.nomClasse}</p>
	{/if}

	<label for="typeHandicap">Type handicap <strong>*</strong></label>
	<select
		id="typeHandicap"
		bind:value={typeHandicap}
		on:change={validateTypeHandicap}
		class:error-input={errors.typeHandicap}
	>
		<option value="PY">PY</option>
		<option value="TMF">TMF</option>
	</select>
	{#if errors.typeHandicap}
		<p class="field-error">{errors.typeHandicap}</p>
	{/if}

	<label for="valeurHandicap">Valeur handicap <strong>*</strong></label>
	<input
		type="text"
		id="valeurHandicap"
		bind:value={valeurHandicap}
		on:blur={validateValeurHandicap}
		class:error-input={errors.valeurHandicap}
		placeholder={typeHandicap === 'PY' ? 'Ex: 1095' : 'Ex: 0.977'}
	/>
	{#if errors.valeurHandicap}
		<p class="field-error">{errors.valeurHandicap}</p>
	{/if}

	<button type="submit">
		{editMode ? 'Enregistrer les modifications' : 'Ajouter la classe'}
	</button>

	{#if editMode}
		<button type="button" class="cancel-button" on:click={annulerModification}>
			Annuler
		</button>
	{/if}
</form>

<h2>Liste des classes de bateaux</h2>

{#if classes.length === 0}
	<div class="empty-state">
		Aucune classe de bateau enregistrée.
	</div>
{:else}
	<div class="table-container">
		<table class="classes-table">
			<thead>
				<tr>
					<th>Nom</th>
					<th>Type handicap</th>
					<th>Valeur handicap</th>
					<th>Action</th>
				</tr>
			</thead>

			<tbody>
				{#each [...classes].reverse() as classe}
					<tr>
						<td>{classe.name}</td>
						<td>{classe.handicapType}</td>
						<td>{classe.handicapValue}</td>
						<td class="actions-cell">
							<button
								type="button"
								class="edit-button"
								on:click={() => modifierClasse(classe)}
							>
								Modifier
							</button>

							<button
								type="button"
								class="delete-button"
								on:click={() => supprimerClasse(classe.id, classe.name)}
							>
								Supprimer
							</button>
						</td>
					</tr>
				{/each}
			</tbody>
		</table>
	</div>
{/if}

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

	.empty-state {
		background: white;
		max-width: 600px;
		margin: 0 auto 30px auto;
		padding: 20px;
		text-align: center;
		border-radius: 8px;
		color: #555;
		box-shadow: 0 0 10px rgba(0, 0, 0, 0.08);
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

	.classes-table {
		width: 100%;
		border-collapse: collapse;
		font-family: Arial, sans-serif;
	}

	.classes-table thead {
		background: linear-gradient(to right, #5f6f82, #7a8da3);
		color: white;
	}

	.classes-table th {
		text-align: left;
		padding: 14px 16px;
		font-size: 0.95rem;
		letter-spacing: 0.02em;
	}

	.classes-table td {
		padding: 14px 16px;
		border-top: 1px solid #eeeeee;
		color: #333;
		font-size: 0.95rem;
	}

	.classes-table tbody tr:nth-child(even) {
		background: #fafbfc;
	}

	.classes-table tbody tr:hover {
		background: #eef4fa;
		transition: background 0.2s ease;
	}

	.classes-table td:first-child {
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

	@media (max-width: 700px) {
		.table-container {
			overflow-x: auto;
		}

		.classes-table {
			min-width: 650px;
		}
	}
</style>