<script>
	import { onMount } from "svelte";
	import { goto } from "$app/navigation";

	const API_BASE = "http://localhost:4000/api";

	let seriesList = [];
	let races = [];
	let classes = [];

	let selectedSerie = null;
	let selectedIndex = -1;
	let editMode = false;
	let createMode = false;
	let loading = true;
	let errorMessage = "";

	let formErrors = {};
	let formMessage = "";

	const texteRegex = /^[A-Za-zÀ-ÿ0-9 _-]*$/;

	function setFieldError(field, message) {
		formErrors = {
			...formErrors,
			[field]: message,
		};
	}

	function clearFieldError(field) {
		const newErrors = { ...formErrors };
		delete newErrors[field];
		formErrors = newErrors;
	}

	function isRaceCompatibleWithSerie(race, serie) {
		if (!race || !serie) return false;

		const serieType = String(serie.type ?? "")
			.trim()
			.toUpperCase();
		const raceType = String(race.type ?? "")
			.trim()
			.toUpperCase();

		if (serieType !== raceType) {
			return false;
		}

		if (serieType === "H") {
			return true;
		}

		const serieClassId = serie.classId || serie.boatClassId;
		const raceClassId = race.class_id || race.boat_class_id;

		return String(serieClassId) === String(raceClassId);
	}

	function getCompatibleRaces() {
		return races.filter((race) => {
			const alreadyAdded = selectedSerie?.race_ids?.includes(race.id);
			return (
				!alreadyAdded && isRaceCompatibleWithSerie(race, selectedSerie)
			);
		});
	}

	function serieHasRaces(serie) {
		return (
			(Array.isArray(serie?.race_ids) && serie.race_ids.length > 0) ||
			(Array.isArray(serie?.races) && serie.races.length > 0)
		);
	}

	function validateSerieName() {
		const value = String(selectedSerie?.nom ?? "").trim();

		if (value === "") {
			setFieldError("nom", "Le nom de la série est obligatoire.");
			return false;
		}

		if (value.length > 25) {
			setFieldError(
				"nom",
				"Le nom de la série doit avoir un maximum de 25 caractères.",
			);
			return false;
		}

		if (!texteRegex.test(value)) {
			setFieldError(
				"nom",
				"Le nom de la série peut contenir seulement des lettres, chiffres, espaces, - ou _.",
			);
			return false;
		}

		const duplicate = seriesList.some((serie) => {
			const sameName =
				String(serie.nom ?? "")
					.trim()
					.toLowerCase() === value.toLowerCase();
			const notCurrentSerie =
				String(serie.id) !== String(selectedSerie?.id);

			return sameName && notCurrentSerie;
		});

		if (duplicate) {
			setFieldError("nom", "Ce nom de série existe déjà.");
			return false;
		}

		clearFieldError("nom");
		return true;
	}

	function validateSerieType() {
		const value = String(selectedSerie?.type ?? "")
			.trim()
			.toUpperCase();

		if (value !== "OD" && value !== "H") {
			setFieldError("type", "Le type de série doit être OD ou H.");
			return false;
		}

		selectedSerie.type = value;
		clearFieldError("type");

		if (value === "H") {
			selectedSerie.classId = "";
			selectedSerie.boatClassId = "";
			selectedSerie.classe = "";
			selectedSerie.typeHandicap = "";
			selectedSerie.handicapValue = "";
			clearFieldError("classe");
		}

		return true;
	}

	function validateSerieClasse() {
		const type = String(selectedSerie?.type ?? "")
			.trim()
			.toUpperCase();

		if (type === "H") {
			selectedSerie.classId = "";
			selectedSerie.boatClassId = "";
			selectedSerie.classe = "";
			selectedSerie.typeHandicap = "";
			selectedSerie.handicapValue = "";
			clearFieldError("classe");
			return true;
		}

		if (editMode && serieHasRaces(selectedSerie)) {
			clearFieldError("classe");
			return true;
		}

		if (!selectedSerie?.classId) {
			setFieldError(
				"classe",
				"La classe est obligatoire pour une série OD.",
			);
			return false;
		}

		const selectedClass = classes.find(
			(classe) => String(classe.id) === String(selectedSerie.classId),
		);

		if (!selectedClass) {
			setFieldError("classe", "La classe sélectionnée est invalide.");
			return false;
		}

		selectedSerie.classe = selectedClass.name;
		selectedSerie.boatClassId = selectedClass.id;
		selectedSerie.typeHandicap = selectedClass.handicapType;
		selectedSerie.handicapValue = selectedClass.handicapValue;

		clearFieldError("classe");
		return true;
	}

	function normalizeClass(classe) {
		return {
			id: classe._id?.$oid ?? classe.id ?? classe._id,
			name: classe.name ?? classe.display_name ?? classe.nom ?? "",
			handicapType:
				classe.handicap_type ??
				classe.typeHandicap ??
				classe.type_handicap ??
				"",
			handicapValue:
				classe.handicap_value ??
				classe.valeurHandicap ??
				classe.valeur_handicap ??
				"",
		};
	}

	function normalizeSerie(serie) {
		return {
			...serie,
			id: serie._id?.$oid ?? serie.id ?? serie._id,
			nom: serie.nom ?? serie.name ?? "",
			type: serie.type ?? "OD",
			classe: serie.classe ?? serie.class ?? "",
			classId: serie.class_id ?? serie.boat_class_id ?? "",
			boatClassId: serie.boat_class_id ?? serie.class_id ?? "",
			typeHandicap: serie.type_handicap ?? "",
			handicapValue: serie.handicap_value ?? "",
			nombreCourses: serie.nombreCourses ?? serie.nombre_courses ?? 2,
			nombreComptabilisees:
				serie.nombreComptabilisees ?? serie.nombre_comptabilisees ?? 1,
			description: serie.description ?? "",
			race_ids: serie.race_ids ?? [],
			races: serie.races ?? [],
			participants: serie.participants ?? [],
		};
	}

	function normalizeRace(race) {
		return {
			...race,
			id: race._id?.$oid ?? race.id ?? race._id,
			name: race.name ?? race.nom ?? "",
			type: race.type ?? "OD",
			class: race.class ?? race.classe ?? "",
			class_id: race.class_id ?? race.boat_class_id ?? "",
			boat_class_id: race.boat_class_id ?? race.class_id ?? "",
		};
	}

	function onClassChange() {
		if (!selectedSerie) return;

		if (String(selectedSerie.type).trim().toUpperCase() === "H") {
			selectedSerie.classId = "";
			selectedSerie.boatClassId = "";
			selectedSerie.classe = "";
			selectedSerie.typeHandicap = "";
			selectedSerie.handicapValue = "";
			clearFieldError("classe");
			return;
		}

		const selectedClass = classes.find(
			(classe) => String(classe.id) === String(selectedSerie.classId),
		);

		if (!selectedClass) {
			selectedSerie.classe = "";
			selectedSerie.boatClassId = "";
			selectedSerie.typeHandicap = "";
			selectedSerie.handicapValue = "";
			setFieldError(
				"classe",
				"La classe est obligatoire pour une série OD.",
			);
			return;
		}

		selectedSerie.classe = selectedClass.name;
		selectedSerie.boatClassId = selectedClass.id;
		selectedSerie.typeHandicap = selectedClass.handicapType;
		selectedSerie.handicapValue = selectedClass.handicapValue;

		clearFieldError("classe");
	}

	function validateNombreCourses() {
		const value = Number(selectedSerie?.nombreCourses);

		if (!Number.isInteger(value)) {
			setFieldError(
				"nombreCourses",
				"Le nombre de courses doit être un nombre entier.",
			);
			return false;
		}

		if (value < 2 || value > 99) {
			setFieldError(
				"nombreCourses",
				"Le nombre de courses doit être compris entre 2 et 99.",
			);
			return false;
		}

		clearFieldError("nombreCourses");

		if (selectedSerie?.nombreComptabilisees !== undefined) {
			validateNombreComptabilisees();
		}

		return true;
	}

	function validateNombreComptabilisees() {
		const total = Number(selectedSerie?.nombreCourses);
		const value = Number(selectedSerie?.nombreComptabilisees);

		if (!Number.isInteger(value)) {
			setFieldError(
				"nombreComptabilisees",
				"Le nombre de courses comptabilisées doit être un nombre entier.",
			);
			return false;
		}

		if (value < 1) {
			setFieldError(
				"nombreComptabilisees",
				"Le nombre de courses comptabilisées doit être au moins 1.",
			);
			return false;
		}

		if (Number.isInteger(total) && value > total) {
			setFieldError(
				"nombreComptabilisees",
				"Le nombre de courses comptabilisées ne peut pas dépasser le nombre total de courses.",
			);
			return false;
		}

		clearFieldError("nombreComptabilisees");
		return true;
	}

	function proposeNombreComptabilisees() {
		if (!selectedSerie) return;

		const total = Number(selectedSerie.nombreCourses);

		if (!Number.isInteger(total) || total < 2 || total > 99) {
			validateNombreCourses();
			return;
		}

		const suggested = getSuggestedNombreComptabilisees();
		const current = selectedSerie.nombreComptabilisees;

		if (
			current === "" ||
			current === null ||
			current === undefined ||
			Number(current) > total ||
			createMode
		) {
			selectedSerie.nombreComptabilisees = suggested;
		}

		validateNombreCourses();
		validateNombreComptabilisees();
	}

	function validateSerieForm() {
		formMessage = "";

		const validations = [
			validateSerieName(),
			validateSerieType(),
			validateSerieClasse(),
			validateNombreCourses(),
			validateNombreComptabilisees(),
		];

		const isValid = validations.every(Boolean);

		if (!isValid) {
			formMessage = "Veuillez corriger les erreurs avant d’enregistrer.";
		}

		return isValid;
	}

	function resetValidation() {
		formErrors = {};
		formMessage = "";
	}

	function getAuthHeaders(includeJson = false) {
		const token = localStorage.getItem("token");

		if (!token) {
			localStorage.removeItem("token");
			localStorage.removeItem("user");
			goto("/connexion");
			throw new Error("Token manquant");
		}

		return {
			...(includeJson ? { "Content-Type": "application/json" } : {}),
			Authorization: `Bearer ${token}`,
		};
	}

	function handleUnauthorized() {
		localStorage.removeItem("token");
		localStorage.removeItem("user");
		goto("/connexion");
	}

	onMount(async () => {
		await loadData();
	});

	async function loadData() {
		loading = true;
		errorMessage = "";

		try {
			const classesRes = await fetch(`${API_BASE}/classes`, {
				headers: getAuthHeaders(),
			});

			if (classesRes.status === 401) {
				handleUnauthorized();
				return;
			}

			if (!classesRes.ok) {
				throw new Error("Erreur chargement classes");
			}

			const classesData = await classesRes.json();
			classes = classesData.map(normalizeClass);

			const response = await fetch(`${API_BASE}/getSeries`, {
				headers: getAuthHeaders(),
			});

			if (response.status === 401) {
				handleUnauthorized();
				return;
			}

			if (!response.ok) {
				throw new Error("Erreur chargement séries");
			}

			const data = await response.json();
			seriesList = data.map(normalizeSerie);

			const racesRes = await fetch(`${API_BASE}/getraces`, {
				headers: getAuthHeaders(),
			});

			if (racesRes.status === 401) {
				handleUnauthorized();
				return;
			}

			if (!racesRes.ok) {
				throw new Error("Erreur chargement courses");
			}

			const racesData = await racesRes.json();
			races = racesData.map(normalizeRace);

			attachRacesToSeries();

			if (seriesList.length > 0) {
				selectedSerie = { ...seriesList[0] };
				selectedIndex = 0;
			} else {
				selectedSerie = null;
				selectedIndex = -1;
			}
		} catch (error) {
			console.error(error);
			if (error.message !== "Token manquant") {
				errorMessage =
					error.message || "Erreur lors du chargement des séries";
			}
			seriesList = [];
			selectedSerie = null;
			selectedIndex = -1;
		} finally {
			loading = false;
		}
	}

	function addRaceToSerie(race) {
		if (!selectedSerie) return;

		if (!selectedSerie.race_ids) {
			selectedSerie.race_ids = [];
		}

		const alreadyExists = selectedSerie.race_ids.includes(race.id);

		if (!alreadyExists) {
			selectedSerie.race_ids = [...selectedSerie.race_ids, race.id];
			selectedSerie.races = [...(selectedSerie.races || []), race];
		}
	}

	function removeRaceFromSerie(raceId) {
		if (!selectedSerie) return;

		selectedSerie.race_ids = (selectedSerie.race_ids || []).filter(
			(id) => id !== raceId,
		);
		selectedSerie.races = (selectedSerie.races || []).filter(
			(r) => r.id !== raceId,
		);
	}

	function attachRacesToSeries() {
		seriesList = seriesList.map((serie) => {
			const linkedRaces = races.filter((r) =>
				serie.race_ids?.includes(r.id),
			);

			return {
				...serie,
				races: linkedRaces,
			};
		});
	}

	function selectSerie(serie, index) {
		selectedSerie = { ...serie };
		selectedIndex = index;
		editMode = false;
		createMode = false;
		resetValidation();
	}

	function toggleEdit() {
		if (createMode || !selectedSerie) return;

		editMode = !editMode;
		resetValidation();

		if (!editMode && selectedIndex >= 0 && seriesList[selectedIndex]) {
			selectedSerie = { ...seriesList[selectedIndex] };
		}
	}

	async function saveChanges() {
		if (!selectedSerie) return;

		if (!validateSerieForm()) return;

		try {
			const payload = {
				nom: selectedSerie.nom.trim(),
				nombreCourses: Number(selectedSerie.nombreCourses),
				nombreComptabilisees: Number(
					selectedSerie.nombreComptabilisees,
				),
				description: selectedSerie.description,
				race_ids: selectedSerie.race_ids || [],
			};

			const canModifyTypeAndClass = !serieHasRaces(selectedSerie);

			if (canModifyTypeAndClass) {
				payload.type = selectedSerie.type.trim().toUpperCase();
				payload.class_id =
					payload.type === "H" ? "" : selectedSerie.classId;
				payload.boat_class_id =
					payload.type === "H" ? "" : selectedSerie.classId;
			}

			const res = await fetch(`${API_BASE}/series/${selectedSerie.id}`, {
				method: "PUT",
				headers: getAuthHeaders(true),
				body: JSON.stringify(payload),
			});

			if (res.status === 401) {
				handleUnauthorized();
				return;
			}

			if (!res.ok) {
				const err = await res.json().catch(() => ({}));
				throw new Error(err.error || "Erreur update");
			}

			await reloadSeries();
			editMode = false;
			resetValidation();
		} catch (e) {
			console.error(e);
			if (e.message !== "Token manquant") {
				alert(e.message);
			}
		}
	}

	async function deleteSerie() {
		if (!selectedSerie?.id || createMode) return;

		const confirmed = confirm(
			`Avertissement : supprimer la série "${selectedSerie.nom}" supprimera aussi les détails des courses associées à cette série.\n\nVoulez-vous continuer ?`,
		);

		if (!confirmed) return;

		try {
			const res = await fetch(`${API_BASE}/series/${selectedSerie.id}`, {
				method: "DELETE",
				headers: getAuthHeaders(),
			});

			if (res.status === 401) {
				handleUnauthorized();
				return;
			}

			if (!res.ok) {
				const err = await res.json().catch(() => ({}));
				throw new Error(err.error || "Erreur suppression");
			}

			await reloadSeries();
			editMode = false;
			createMode = false;
			resetValidation();
		} catch (e) {
			console.error(e);
			if (e.message !== "Token manquant") {
				alert(e.message || "Erreur lors de la suppression de la série");
			}
		}
	}
	async function reloadSeries() {
		const response = await fetch(`${API_BASE}/getSeries`, {
			headers: getAuthHeaders(),
		});

		if (response.status === 401) {
			handleUnauthorized();
			return;
		}

		const data = await response.json();

		seriesList = data.map(normalizeSerie);
		attachRacesToSeries();

		if (seriesList.length === 0) {
			selectedSerie = null;
			selectedIndex = -1;
			return;
		}

		if (selectedIndex < 0 || selectedIndex >= seriesList.length) {
			selectedIndex = 0;
		}

		selectedSerie = { ...seriesList[selectedIndex] };
	}

	function startCreateSerie() {
		createMode = true;
		editMode = false;
		resetValidation();

		selectedSerie = {
			id: null,
			nom: "",
			type: "OD",
			classe: "",
			classId: "",
			boatClassId: "",
			typeHandicap: "",
			handicapValue: "",
			nombreCourses: 2,
			nombreComptabilisees: Math.round((2 * 2) / 3),
			description: "",
			race_ids: [],
			races: [],
		};
	}

	function cancelCreate() {
		createMode = false;
		resetValidation();

		if (seriesList.length > 0 && selectedIndex >= 0) {
			selectedSerie = { ...seriesList[selectedIndex] };
		} else if (seriesList.length > 0) {
			selectedIndex = 0;
			selectedSerie = { ...seriesList[0] };
		} else {
			selectedSerie = null;
			selectedIndex = -1;
		}
	}

	async function createSerie() {
		if (!validateSerieForm()) return;

		try {
			const response = await fetch(`${API_BASE}/series`, {
				method: "POST",
				headers: getAuthHeaders(true),
				body: JSON.stringify({
					nom: selectedSerie.nom.trim(),
					type: selectedSerie.type.trim().toUpperCase(),
					class_id:
						selectedSerie.type.trim().toUpperCase() === "H"
							? ""
							: selectedSerie.classId,
					boat_class_id:
						selectedSerie.type.trim().toUpperCase() === "H"
							? ""
							: selectedSerie.classId,
					nombreCourses: Number(selectedSerie.nombreCourses),
					nombreComptabilisees: Number(
						selectedSerie.nombreComptabilisees,
					),
					description: selectedSerie.description,
					race_ids: selectedSerie.race_ids || [],
				}),
			});

			if (response.status === 401) {
				handleUnauthorized();
				return;
			}

			if (!response.ok) {
				const err = await response.json().catch(() => ({}));
				throw new Error(err.error || "Erreur création");
			}

			await reloadSeries();

			if (seriesList.length > 0) {
				selectedIndex = seriesList.length - 1;
				selectedSerie = { ...seriesList[selectedIndex] };
			}

			createMode = false;
			resetValidation();
		} catch (e) {
			console.error(e);
			if (e.message !== "Token manquant") {
				alert(e.message);
			}
		}
	}

	function getSuggestedNombreComptabilisees() {
		const total = Number(selectedSerie?.nombreCourses);

		if (!Number.isInteger(total) || total < 2) {
			return "";
		}

		return Math.round((total * 2) / 3);
	}

	function appliquerNombreComptabiliseesSuggere() {
		if (!selectedSerie) return;

		const suggested = getSuggestedNombreComptabilisees();

		if (suggested === "") return;

		selectedSerie.nombreComptabilisees = suggested;
		validateNombreComptabilisees();
	}

	function getNombreCoursesAssociees() {
		return (
			selectedSerie?.races?.length ?? selectedSerie?.race_ids?.length ?? 0
		);
	}

	function manqueCoursesRequises() {
		if (!selectedSerie) return false;

		const totalRequis = Number(selectedSerie.nombreCourses);
		const totalAssocie = getNombreCoursesAssociees();

		return Number.isInteger(totalRequis) && totalAssocie < totalRequis;
	}
</script>

<svelte:head>
	<title>Séries - YRR</title>
</svelte:head>

<div class="page">
	<div class="left-panel">
		<div class="left-header">
			<h1>Liste des séries</h1>
			<button class="create-button" on:click={startCreateSerie}>
				Créer une série
			</button>
		</div>

		{#if loading}
			<p>Chargement des séries...</p>
		{:else if errorMessage}
			<p>{errorMessage}</p>
		{:else if seriesList.length === 0}
			<p>Aucune série disponible.</p>
		{:else}
			{#each seriesList as serie, index (serie.id)}
				<button
					class:selected={selectedIndex === index && !createMode}
					class="serie-button"
					on:click={() => selectSerie(serie, index)}
				>
					<strong>{serie.nom}</strong>
					<span>{serie.classe || "Toutes classes"}</span>
				</button>
			{/each}
		{/if}
	</div>

	<div class="right-panel">
		<div class="header-row">
			<h2>{createMode ? "Créer une série" : "Détails de la série"}</h2>

			{#if !createMode && selectedSerie}
				<div class="header-actions">
					<button class="edit-button" on:click={toggleEdit}>
						{editMode ? "Annuler la modification" : "Modifier"}
					</button>

					<button class="delete-serie-button" on:click={deleteSerie}>
						Supprimer
					</button>
				</div>
			{/if}
		</div>

		{#if selectedSerie}
			<div class="details-card">
				{#if formMessage}
					<div class="form-message error-message">{formMessage}</div>
				{/if}

				<label>
					<strong>Nom :</strong>
					<input
						bind:value={selectedSerie.nom}
						disabled={!editMode && !createMode}
						on:blur={validateSerieName}
						class:error-input={formErrors.nom}
						maxlength="25"
					/>
				</label>
				{#if formErrors.nom}
					<p class="field-error">{formErrors.nom}</p>
				{/if}

				<label>
					<strong>Type :</strong>
					<select
						bind:value={selectedSerie.type}
						disabled={(!editMode && !createMode) ||
							(editMode && serieHasRaces(selectedSerie))}
						on:change={() => {
							validateSerieType();
							validateSerieClasse();
						}}
						class:error-input={formErrors.type}
					>
						<option value="OD">OD</option>
						<option value="H">H</option>
					</select>
				</label>
				{#if formErrors.type}
					<p class="field-error">{formErrors.type}</p>
				{/if}

				<label>
					<strong>Classe :</strong>
					<select
						bind:value={selectedSerie.classId}
						disabled={(!editMode && !createMode) ||
							(editMode && serieHasRaces(selectedSerie)) ||
							String(selectedSerie.type).trim().toUpperCase() ===
								"H" ||
							classes.length === 0}
						on:change={onClassChange}
						on:blur={validateSerieClasse}
						class:error-input={formErrors.classe}
					>
						<option value="">
							{String(selectedSerie.type).trim().toUpperCase() ===
							"H"
								? "Toutes classes"
								: "-- Choisir une classe --"}
						</option>
						{#each classes as classe}
							<option value={classe.id}>
								{classe.name} - {classe.handicapType}
								{classe.handicapValue}
							</option>
						{/each}
					</select>
				</label>
				{#if editMode && serieHasRaces(selectedSerie)}
					<p class="field-info">
						Le type et la classe ne peuvent pas être modifiés parce
						que des courses sont déjà associées à cette série.
					</p>
				{/if}
				{#if classes.length === 0 && String(selectedSerie.type)
						.trim()
						.toUpperCase() === "OD"}
					<p class="field-error">
						Aucune classe disponible. Créez d’abord une classe de
						bateau.
					</p>
				{/if}

				{#if formErrors.classe}
					<p class="field-error">{formErrors.classe}</p>
				{/if}

				<div class="readonly-handicap">
					<p>
						<strong>Type handicap :</strong>
						{selectedSerie.typeHandicap || "—"}
					</p>
					<p>
						<strong>Valeur handicap :</strong>
						{selectedSerie.handicapValue || "—"}
					</p>
				</div>

				<label>
					<strong>Nombre de courses :</strong>
					<input
						type="number"
						min="2"
						max="99"
						bind:value={selectedSerie.nombreCourses}
						disabled={!editMode && !createMode}
						on:change={proposeNombreComptabilisees}
						on:blur={proposeNombreComptabilisees}
						class:error-input={formErrors.nombreCourses}
					/>
				</label>
				{#if formErrors.nombreCourses}
					<p class="field-error">{formErrors.nombreCourses}</p>
				{/if}

				<label>
					<strong>Nombre de courses comptabilisées :</strong>
					<input
						type="number"
						min="1"
						max={selectedSerie.nombreCourses}
						bind:value={selectedSerie.nombreComptabilisees}
						disabled={!editMode && !createMode}
						on:blur={validateNombreComptabilisees}
						class:error-input={formErrors.nombreComptabilisees}
					/>
				</label>

				{#if editMode || createMode}
					<div class="suggestion-box">
						<span>
							Suggestion : {getSuggestedNombreComptabilisees() ||
								"—"} course(s) comptabilisée(s) pour {selectedSerie.nombreCourses ||
								0} course(s).
						</span>

						<button
							type="button"
							class="suggestion-button"
							on:click={appliquerNombreComptabiliseesSuggere}
							disabled={!getSuggestedNombreComptabilisees()}
						>
							Utiliser le nombre de courses suggéré
						</button>
					</div>
				{/if}

				{#if formErrors.nombreComptabilisees}
					<p class="field-error">{formErrors.nombreComptabilisees}</p>
				{/if}

				<label>
					<strong>Description :</strong>
					<textarea
						bind:value={selectedSerie.description}
						disabled={!editMode && !createMode}
					></textarea>
				</label>

				<div class="races-section">
					<h3>Courses de la série</h3>
					{#if manqueCoursesRequises()}
						<div class="warning-box">
							Cette série demande {selectedSerie.nombreCourses} course(s),
							mais seulement
							{getNombreCoursesAssociees()} course(s) sont associées
							pour le moment. Il manque donc {Number(
								selectedSerie.nombreCourses,
							) - getNombreCoursesAssociees()} course(s).
						</div>
					{:else if selectedSerie}
						<div class="success-box">
							Le nombre de courses associées correspond au nombre
							requis pour cette série.
						</div>
					{/if}
					{#if selectedSerie.races && selectedSerie.races.length > 0}
						<ul>
							{#each selectedSerie.races as race}
								<li>
									{race.name}
									{#if editMode || createMode}
										<button
											type="button"
											on:click={() =>
												removeRaceFromSerie(race.id)}
											>❌</button
										>
									{/if}
								</li>
							{/each}
						</ul>
					{:else}
						<p>Aucune course dans cette série.</p>
					{/if}

					{#if editMode || createMode}
						<h4>Ajouter une course</h4>
						<div class="race-list">
							{#if getCompatibleRaces().length > 0}
								{#each getCompatibleRaces() as race}
									<button
										type="button"
										on:click={() => addRaceToSerie(race)}
									>
										+ {race.name}
									</button>
								{/each}
							{:else}
								<p>
									Aucune course compatible disponible à
									ajouter.
								</p>
							{/if}
						</div>
					{/if}
				</div>

				{#if editMode}
					<button class="save-button" on:click={saveChanges}>
						Enregistrer
					</button>
				{/if}

				{#if createMode}
					<div class="create-actions">
						<button class="save-button" on:click={createSerie}>
							Créer
						</button>
						<button class="cancel-button" on:click={cancelCreate}>
							Annuler
						</button>
					</div>
				{/if}
			</div>
		{:else if !loading}
			<p>Aucune série sélectionnée.</p>
		{/if}
	</div>
</div>

<style>
	.races-section {
		background: #f9fafb;
		border: 1px solid #e5e7eb;
		padding: 16px;
		border-radius: 10px;
	}

	.races-section ul {
		list-style: none;
		padding: 0;
	}

	.races-section li {
		display: flex;
		justify-content: space-between;
		padding: 6px 0;
	}

	.field-info {
		color: #1e40af;
		background: #eff6ff;
		border: 1px solid #bfdbfe;
		border-radius: 6px;
		padding: 10px 12px;
		font-size: 0.9rem;
		margin: -6px 0 4px 0;
	}
	.race-list {
		display: flex;
		flex-wrap: wrap;
		gap: 8px;
		margin-top: 10px;
	}

	.race-list button {
		background: #e0f2fe;
		color: #0369a1;
	}

	.page {
		display: grid;
		grid-template-columns: 1fr;
		gap: 24px;
		padding: 24px;
		min-height: 100vh;
		box-sizing: border-box;
	}

	@media (min-width: 900px) {
		.page {
			grid-template-columns: 320px 1fr;
		}
	}

	.left-panel,
	.right-panel {
		background: white;
		border-radius: 12px;
		padding: 24px;
		box-shadow: 0 4px 20px rgba(0, 0, 0, 0.05);
		border: 1px solid #e5e7eb;
	}

	h1,
	h2 {
		margin-top: 0;
	}

	.left-header,
	.header-row {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 20px;
		gap: 10px;
	}

	.readonly-handicap {
		background: #f9fafb;
		border: 1px solid #e5e7eb;
		border-radius: 8px;
		padding: 12px 14px;
	}

	.readonly-handicap p {
		margin: 4px 0;
		color: #374151;
	}

	.serie-button {
		width: 100%;
		text-align: left;
		padding: 14px;
		margin-bottom: 10px;
		border: 1px solid #e5e7eb;
		border-radius: 10px;
		background: white;
		cursor: pointer;
		display: flex;
		flex-direction: column;
		gap: 4px;
		transition: all 0.2s ease;
	}

	.serie-button:hover {
		transform: translateY(-2px);
		box-shadow: 0 6px 14px rgba(0, 0, 0, 0.08);
	}

	.field-error {
		color: #b91c1c;
		font-size: 0.85rem;
		margin: -8px 0 4px 0;
	}

	.error-input {
		border-color: #dc2626 !important;
		background: #fff7f7;
	}

	.form-message {
		padding: 12px 14px;
		border-radius: 8px;
		font-weight: 600;
		margin-bottom: 8px;
	}

	.error-message {
		background: #fdecec;
		color: #8f1d1d;
		border: 1px solid #f5bcbc;
	}

	.serie-button.selected {
		background: #eff6ff;
		border-color: #2563eb;
	}

	.serie-button span {
		font-size: 0.85rem;
		color: #6b7280;
	}

	.details-card {
		display: flex;
		flex-direction: column;
		gap: 14px;
	}

	label {
		display: flex;
		flex-direction: column;
		gap: 6px;
	}

	label strong {
		font-size: 0.8rem;
		color: #6b7280;
		text-transform: uppercase;
		letter-spacing: 0.05em;
	}

	input,
	select,
	textarea {
		padding: 10px;
		border: 1px solid #d1d5db;
		border-radius: 6px;
		font-size: 1rem;
	}

	input:focus,
	select:focus,
	textarea:focus {
		outline: none;
		border-color: #2563eb;
		box-shadow: 0 0 0 2px rgba(37, 99, 235, 0.2);
	}

	textarea {
		min-height: 90px;
		resize: vertical;
	}

	input:disabled,
	select:disabled,
	textarea:disabled {
		background: #f3f3f3;
		color: #555;
	}

	button {
		border: none;
		border-radius: 6px;
		cursor: pointer;
		padding: 10px 14px;
		transition: all 0.15s ease;
	}

	button:hover {
		filter: brightness(1.1);
	}

	button:active {
		transform: scale(0.97);
	}

	.suggestion-box {
		display: flex;
		justify-content: space-between;
		align-items: center;
		gap: 12px;
		background: #eff6ff;
		color: #1e40af;
		border: 1px solid #bfdbfe;
		padding: 12px 14px;
		border-radius: 8px;
		flex-wrap: wrap;
	}

	.suggestion-button {
		background: #2563eb;
		color: white;
		padding: 8px 12px;
		border-radius: 6px;
	}

	.suggestion-button:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.warning-box {
		background: #fff4e5;
		color: #8a5a00;
		border: 1px solid #f0d3a2;
		padding: 12px 14px;
		border-radius: 8px;
		font-weight: 600;
		margin-bottom: 12px;
	}

	.success-box {
		background: #e6f6ea;
		color: #1e7a38;
		border: 1px solid #b7e2c2;
		padding: 12px 14px;
		border-radius: 8px;
		font-weight: 600;
		margin-bottom: 12px;
	}

	.create-button {
		background: #16a34a;
		color: white;
	}

	.edit-button {
		background: #f59e0b;
		color: white;
	}

	.save-button {
		background: #2563eb;
		color: white;
	}

	.cancel-button {
		background: #9ca3af;
		color: white;
	}

	.create-actions {
		display: flex;
		gap: 12px;
	}

	.header-actions {
		display: flex;
		gap: 10px;
		flex-wrap: wrap;
	}

	.delete-serie-button {
		background: #dc2626;
		color: white;
	}
</style>
