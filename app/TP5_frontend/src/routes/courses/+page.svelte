<script>
	import { onMount } from "svelte";
	import { goto } from "$app/navigation";

	const API_BASE = "http://localhost:4000/api";

	let courses = [];
	let classes = [];
	let selectedCourse = null;
	let selectedIndex = -1;

	let editMode = false;
	let createMode = false;
	let resultMode = false;
	let loading = false;
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

	function isCourseFromSerie(course) {
		return Boolean(
			course?.serie_id ||
				course?.serieId ||
				course?.series_id ||
				course?.seriesId ||
				course?.nomSerie ||
				course?.serieName,
		);
	}

	function validateCourseType() {
		const value = String(selectedCourse?.type ?? "")
			.trim()
			.toUpperCase();

		if (value !== "OD" && value !== "H") {
			setFieldError("type", "Le type de course doit être OD ou H.");
			return false;
		}

		selectedCourse.type = value;
		clearFieldError("type");

		if (value === "H") {
			selectedCourse.classId = "";
			selectedCourse.boatClassId = "";
			selectedCourse.classe = "";
			selectedCourse.typeHandicap = "";
			selectedCourse.handicapValue = "";
			clearFieldError("classe");
		}

		return true;
	}

	function validateCourseClasse() {
		const type = String(selectedCourse?.type ?? "")
			.trim()
			.toUpperCase();

		if (type === "H") {
			selectedCourse.classId = "";
			selectedCourse.boatClassId = "";
			selectedCourse.classe = "";
			selectedCourse.typeHandicap = "";
			selectedCourse.handicapValue = "";
			clearFieldError("classe");
			return true;
		}

		if (editMode && courseHasParticipants(selectedCourse)) {
			clearFieldError("classe");
			return true;
		}

		if (!selectedCourse?.classId) {
			setFieldError(
				"classe",
				"La classe de course est obligatoire pour une course OD.",
			);
			return false;
		}

		const selectedClass = classes.find(
			(classe) => String(classe.id) === String(selectedCourse.classId),
		);

		if (!selectedClass) {
			setFieldError("classe", "La classe sélectionnée est invalide.");
			return false;
		}

		selectedCourse.classe = selectedClass.name;
		selectedCourse.boatClassId = selectedClass.id;
		selectedCourse.typeHandicap = selectedClass.handicapType;
		selectedCourse.handicapValue = selectedClass.handicapValue;

		clearFieldError("classe");
		return true;
	}

	function courseHasParticipants(course) {
		return Array.isArray(course?.resultats) && course.resultats.length > 0;
	}

	function validateCourseName() {
		const value = String(selectedCourse?.nom ?? "").trim();

		if (value === "") {
			setFieldError("nom", "Le nom de la course est obligatoire.");
			return false;
		}

		if (value.length > 25) {
			setFieldError(
				"nom",
				"Le nom de la course doit avoir un maximum de 25 caractères.",
			);
			return false;
		}

		if (!texteRegex.test(value)) {
			setFieldError(
				"nom",
				"Le nom de la course peut contenir seulement des lettres, chiffres, espaces, - ou _.",
			);
			return false;
		}

		const duplicate = courses.some((course) => {
			const sameName =
				String(course.nom ?? "")
					.trim()
					.toLowerCase() === value.toLowerCase();
			const notCurrentCourse =
				String(course.id) !== String(selectedCourse?.id);

			return sameName && notCurrentCourse;
		});

		if (duplicate) {
			setFieldError("nom", "Ce nom de course existe déjà.");
			return false;
		}

		clearFieldError("nom");
		return true;
	}

	function validateCourseForm() {
		formMessage = "";

		const fromSerie = isCourseFromSerie(selectedCourse);

		const validations = [validateCourseName()];

		if (!fromSerie) {
			validations.push(validateCourseType());
			validations.push(validateCourseClasse());
		}

		const isValid = validations.every(Boolean);

		if (!isValid) {
			formMessage = "Veuillez corriger les erreurs avant d’enregistrer.";
		}

		return isValid;
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
		await loadClasses();
		await loadCourses();
	});

	function normalizeRace(r) {
		return {
			id: r._id?.$oid || r.id || r._id,
			nom: r.name ?? "",
			type: r.type ?? "OD",
			classe: r.class ?? "",
			classId: r.class_id ?? r.boat_class_id ?? "",
			boatClassId: r.boat_class_id ?? r.class_id ?? "",
			typeHandicap: r.type_handicap ?? "",
			handicapValue: r.handicap_value ?? "",
			date: r.date ?? "",
			heureDepart: r.start_time ?? "",
			parcours: r.course ?? "",
			description: r.description ?? "",
			terminee: r.finished ?? false,

			serie_id:
				r.serie_id ?? r.serieId ?? r.series_id ?? r.seriesId ?? null,
			nomSerie: r.nomSerie ?? r.serieName ?? r.series_name ?? "",

			resultats: (r.participants ?? []).map((p) => ({
				id: p.id,
				bateau: p.boat_name,
				resultat: p.result ?? "",
				position: p.position ?? null,
				points: p.points ?? null,
				boat_id: p.boat_id,
				sail_number: p.sail_number,
				boat_class: p.boat_class,
				class_id: p.class_id ?? p.boat_class_id ?? "",
				boat_class_id: p.boat_class_id ?? p.class_id ?? "",
				type_handicap: p.type_handicap ?? "",
				handicap_value: p.handicap_value ?? "",
				helm_name: p.helm_name,
			})),
		};
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

	async function loadCourses() {
		loading = true;
		errorMessage = "";

		try {
			const res = await fetch(`${API_BASE}/getraces`, {
				headers: getAuthHeaders(),
			});

			if (res.status === 401) {
				handleUnauthorized();
				return;
			}

			if (!res.ok) throw new Error("Erreur chargement courses");

			const data = await res.json();
			courses = data.map(normalizeRace);

			if (courses.length > 0) {
				if (selectedCourse) {
					const refreshed = courses.find(
						(c) => c.id === selectedCourse.id,
					);
					selectedCourse = refreshed
						? structuredClone(refreshed)
						: structuredClone(courses[0]);
				} else {
					selectedCourse = structuredClone(courses[0]);
				}
				selectedIndex = findRealIndex(selectedCourse.id);
			} else {
				selectedCourse = null;
				selectedIndex = -1;
			}
		} catch (e) {
			console.error(e);
			if (e.message !== "Token manquant") {
				errorMessage = e.message;
			}
		} finally {
			loading = false;
		}
	}

	async function loadClasses() {
		try {
			const res = await fetch(`${API_BASE}/classes`, {
				headers: getAuthHeaders(),
			});

			if (res.status === 401) {
				handleUnauthorized();
				return;
			}

			if (!res.ok) throw new Error("Erreur chargement classes");

			const data = await res.json();
			classes = data.map(normalizeClass);
		} catch (e) {
			console.error(e);
			if (e.message !== "Token manquant") {
				errorMessage = e.message;
			}
		}
	}

	function findRealIndex(courseId) {
		return courses.findIndex((course) => course.id === courseId);
	}

	function selectCourse(course) {
		selectedCourse = structuredClone(course);
		selectedIndex = findRealIndex(course.id);
		editMode = false;
		createMode = false;
		resultMode = false;
		formErrors = {};
		formMessage = "";
	}

	function toggleEdit() {
		if (createMode || resultMode) return;
		editMode = !editMode;
		formErrors = {};
		formMessage = "";

		if (!editMode && selectedIndex >= 0) {
			selectedCourse = structuredClone(courses[selectedIndex]);
		}
	}

	function startCreateCourse() {
		createMode = true;
		editMode = false;
		resultMode = false;
		formErrors = {};
		formMessage = "";

		selectedCourse = {
			id: null,
			nom: "",
			type: "OD",
			classe: "",
			classId: "",
			boatClassId: "",
			typeHandicap: "",
			handicapValue: "",
			date: "",
			heureDepart: "",
			parcours: "",
			description: "",
			terminee: false,
			serie_id: null,
			nomSerie: "",
			resultats: [],
		};
	}

	function cancelCreate() {
		createMode = false;
		formErrors = {};
		formMessage = "";

		if (selectedIndex >= 0) {
			selectedCourse = structuredClone(courses[selectedIndex]);
		} else if (courses.length > 0) {
			selectedCourse = structuredClone(courses[0]);
			selectedIndex = 0;
		} else {
			selectedCourse = null;
		}
	}

	async function saveChanges() {
		if (!validateCourseForm()) return;

		try {
			const payload = {
				name: selectedCourse.nom.trim(),
				date: selectedCourse.date,
				start_time: selectedCourse.heureDepart,
				course: selectedCourse.parcours,
				description: selectedCourse.description,
			};

			if (!isCourseFromSerie(selectedCourse)) {
				const canModifyTypeAndClass =
					!courseHasParticipants(selectedCourse);

				if (canModifyTypeAndClass) {
					payload.type = selectedCourse.type.trim().toUpperCase();

					if (payload.type === "H") {
						payload.class_id = "";
						payload.boat_class_id = "";
					} else {
						payload.class_id = selectedCourse.classId;
						payload.boat_class_id = selectedCourse.classId;
					}
				}
			}

			const res = await fetch(
				`${API_BASE}/updaterace/${selectedCourse.id}`,
				{
					method: "PUT",
					headers: getAuthHeaders(true),
					body: JSON.stringify(payload),
				},
			);

			if (res.status === 401) {
				handleUnauthorized();
				return;
			}

			if (!res.ok) {
				const err = await res.json().catch(() => ({}));
				throw new Error(err.error || "Erreur lors de la modification");
			}

			await loadCourses();
			editMode = false;
			formErrors = {};
			formMessage = "";
		} catch (e) {
			console.error(e);
			if (e.message !== "Token manquant") {
				alert(e.message);
			}
		}
	}

	async function createCourse() {
		if (!validateCourseForm()) return;

		try {
			const courseType = selectedCourse.type.trim().toUpperCase();

			const payload = {
				name: selectedCourse.nom.trim(),
				type: courseType,
				class_id: courseType === "H" ? "" : selectedCourse.classId,
				boat_class_id: courseType === "H" ? "" : selectedCourse.classId,
				date: selectedCourse.date,
				start_time: selectedCourse.heureDepart,
				course: selectedCourse.parcours,
				description: selectedCourse.description,
			};

			const response = await fetch(`${API_BASE}/addrace`, {
				method: "POST",
				headers: getAuthHeaders(true),
				body: JSON.stringify(payload),
			});

			if (response.status === 401) {
				handleUnauthorized();
				return;
			}

			if (!response.ok) {
				const err = await response.json().catch(() => ({}));
				throw new Error(
					err.error || "Erreur lors de la création de la course",
				);
			}

			await loadCourses();
			createMode = false;
			formErrors = {};
			formMessage = "";
		} catch (error) {
			console.error(error);
			if (error.message !== "Token manquant") {
				alert(error.message);
			}
		}
	}

	async function deleteCourse() {
		if (!selectedCourse?.id) return;

		const confirmed = confirm(
			`Avertissement : supprimer la course "${selectedCourse.nom}" supprimera tous les détails associés à cette course, incluant les inscriptions et les résultats.\n\nVoulez-vous continuer ?`,
		);

		if (!confirmed) return;

		try {
			const res = await fetch(
				`${API_BASE}/deleterace/${selectedCourse.id}`,
				{
					method: "DELETE",
					headers: getAuthHeaders(),
				},
			);

			if (res.status === 401) {
				handleUnauthorized();
				return;
			}

			if (!res.ok) {
				const err = await res.json().catch(() => ({}));
				throw new Error(
					err.error || "Erreur lors de la suppression de la course",
				);
			}

			await loadCourses();
			editMode = false;
			resultMode = false;
			createMode = false;
			formErrors = {};
			formMessage = "";
		} catch (e) {
			console.error(e);
			if (e.message !== "Token manquant") {
				alert(e.message);
			}
		}
	}

	function toggleResultsMode() {
		if (createMode || editMode) return;

		resultMode = !resultMode;

		if (!resultMode && selectedIndex >= 0) {
			selectedCourse = structuredClone(courses[selectedIndex]);
		}
	}

	function recalculateODPositions() {
		const valides = selectedCourse.resultats
			.filter((r) => r.resultat !== "" && !isNaN(Number(r.resultat)))
			.sort((a, b) => Number(a.resultat) - Number(b.resultat));

		for (const participant of selectedCourse.resultats) {
			participant.position = null;
		}

		valides.forEach((participant, index) => {
			participant.position = index + 1;
		});
	}

	function onClassChange() {
		if (!selectedCourse) return;

		if (String(selectedCourse.type).trim().toUpperCase() === "H") {
			selectedCourse.classId = "";
			selectedCourse.boatClassId = "";
			selectedCourse.classe = "";
			selectedCourse.typeHandicap = "";
			selectedCourse.handicapValue = "";
			clearFieldError("classe");
			return;
		}

		const selectedClass = classes.find(
			(classe) => String(classe.id) === String(selectedCourse.classId),
		);

		if (!selectedClass) {
			selectedCourse.classe = "";
			selectedCourse.boatClassId = "";
			selectedCourse.typeHandicap = "";
			selectedCourse.handicapValue = "";
			setFieldError(
				"classe",
				"La classe de course est obligatoire pour une course OD.",
			);
			return;
		}

		selectedCourse.classe = selectedClass.name;
		selectedCourse.boatClassId = selectedClass.id;
		selectedCourse.typeHandicap = selectedClass.handicapType;
		selectedCourse.handicapValue = selectedClass.handicapValue;

		clearFieldError("classe");
	}

	async function saveResults() {
		try {
			if (selectedCourse.type === "OD") {
				recalculateODPositions();
			}

			const participants = selectedCourse.resultats.map((p) => ({
				id: p.id,
				boat_id: p.boat_id,
				boat_name: p.bateau,
				sail_number: p.sail_number,
				boat_class: p.boat_class,
				class_id: p.class_id,
				boat_class_id: p.boat_class_id,
				type_handicap: p.type_handicap,
				handicap_value: p.handicap_value,
				helm_name: p.helm_name,
				result: p.resultat,
				position: p.position,
				points: p.points ?? null,
			}));

			const res = await fetch(
				`${API_BASE}/updateraceresults/${selectedCourse.id}`,
				{
					method: "PUT",
					headers: getAuthHeaders(true),
					body: JSON.stringify({ participants }),
				},
			);

			if (res.status === 401) {
				handleUnauthorized();
				return;
			}

			if (!res.ok) {
				const err = await res.json().catch(() => ({}));
				throw new Error(
					err.error || "Erreur lors de la sauvegarde des résultats",
				);
			}

			await loadCourses();
			resultMode = false;
		} catch (e) {
			console.error(e);
			if (e.message !== "Token manquant") {
				alert(e.message);
			}
		}
	}

	async function setFinishedState(finished) {
		try {
			const res = await fetch(
				`${API_BASE}/setracefinished/${selectedCourse.id}`,
				{
					method: "PUT",
					headers: getAuthHeaders(true),
					body: JSON.stringify({ finished }),
				},
			);

			if (res.status === 401) {
				handleUnauthorized();
				return;
			}

			if (!res.ok) {
				const err = await res.json().catch(() => ({}));
				throw new Error(
					err.error || "Erreur lors du changement d’état",
				);
			}

			await loadCourses();
			resultMode = false;
			editMode = false;
		} catch (e) {
			console.error(e);
			if (e.message !== "Token manquant") {
				alert(e.message);
			}
		}
	}

	function markFinished() {
		return setFinishedState(true);
	}

	function reopenCourse() {
		return setFinishedState(false);
	}

	function getPodium(course) {
		if (!course?.resultats) return [];

		return [...course.resultats]
			.filter((r) => r.position !== null && r.position !== undefined)
			.sort((a, b) => a.position - b.position)
			.slice(0, 3);
	}
</script>

<svelte:head>
	<title>Courses - YRR</title>
</svelte:head>

<div class="page">
	<div class="left-panel">
		<div class="left-header">
			<h1>Liste des courses</h1>
			<button class="create-button" on:click={startCreateCourse}>
				Créer une course
			</button>
		</div>

		{#if loading}
			<p>Chargement...</p>
		{:else if courses.length === 0}
			<p>Aucune course.</p>
		{:else}
			{#each courses as course}
				<button
					class:selected={selectedCourse?.id === course.id &&
						!createMode}
					class="course-button"
					on:click={() => selectCourse(course)}
				>
					<div class="course-top-row">
						<strong>{course.nom}</strong>
						<span
							class:status-finished={course.terminee}
							class:status-active={!course.terminee}
							class="status-badge"
						>
							{course.terminee ? "Terminée" : "En cours"}
						</span>
					</div>
					<span>{course.date}</span>
					<small>{course.classe || "Toutes classes"}</small>
				</button>
			{/each}
		{/if}
	</div>

	<div class="right-panel">
		{#if errorMessage}
			<p>{errorMessage}</p>
		{/if}

		{#if selectedCourse}
			<div class="header-row">
				<h2>
					{createMode ? "Créer une course" : "Détails de la course"}
				</h2>

				{#if !createMode}
					<div class="header-actions">
						<button
							class="secondary-button"
							on:click={toggleResultsMode}
						>
							{resultMode
								? "Annuler résultats"
								: "Entrer / modifier les résultats"}
						</button>

						<button
							class="edit-button"
							on:click={toggleEdit}
							disabled={resultMode}
						>
							{editMode ? "Annuler la modification" : "Modifier"}
						</button>

						<button
							class="delete-button"
							on:click={deleteCourse}
							disabled={resultMode || editMode}
						>
							Supprimer
						</button>
					</div>
				{/if}
			</div>

			<div class="details-card">
				<div class="summary-banner">
					<div>
						<strong>État :</strong>
						<span
							class:status-finished={selectedCourse.terminee}
							class:status-active={!selectedCourse.terminee}
							class="status-badge inline-badge"
						>
							{selectedCourse.terminee
								? "Course terminée"
								: "Course non terminée"}
						</span>
					</div>

					<div class="course-lock-note">
						{#if selectedCourse.terminee}
							Participants verrouillés, résultats modifiables.
						{:else}
							Participants modifiables, résultats à saisir après
							la course.
						{/if}
					</div>
				</div>

				{#if formMessage}
					<div class="form-message error-message">{formMessage}</div>
				{/if}

				{#if isCourseFromSerie(selectedCourse)}
					<div class="serie-info-box">
						Cette course appartient à une série. Le type et la
						classe sont hérités de la série et ne peuvent pas être
						modifiés ici.
					</div>
				{/if}

				<label>
					<strong>Nom :</strong>
					<input
						bind:value={selectedCourse.nom}
						disabled={!editMode && !createMode}
						on:blur={validateCourseName}
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
						bind:value={selectedCourse.type}
						disabled={(!editMode && !createMode) ||
							isCourseFromSerie(selectedCourse) ||
							(editMode && courseHasParticipants(selectedCourse))}
						on:change={() => {
							validateCourseType();
							validateCourseClasse();
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
						bind:value={selectedCourse.classId}
						disabled={(!editMode && !createMode) ||
							isCourseFromSerie(selectedCourse) ||
							(editMode &&
								courseHasParticipants(selectedCourse)) ||
							selectedCourse.type === "H" ||
							classes.length === 0}
						on:change={onClassChange}
						on:blur={validateCourseClasse}
						class:error-input={formErrors.classe}
					>
						<option value="">
							{selectedCourse.type === "H"
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

				{#if classes.length === 0 && selectedCourse.type === "OD"}
					<p class="field-error">
						Aucune classe disponible. Créez d’abord une classe de
						bateau.
					</p>
				{/if}

				{#if editMode && courseHasParticipants(selectedCourse) && !isCourseFromSerie(selectedCourse)}
					<p class="field-info">
						La classe ne peut pas être modifiée parce que des
						participants sont déjà inscrits à cette course.
					</p>
				{/if}

				{#if formErrors.classe}
					<p class="field-error">{formErrors.classe}</p>
				{/if}

				<div class="readonly-handicap">
					<p>
						<strong>Type handicap :</strong>
						{selectedCourse.typeHandicap || "—"}
					</p>
					<p>
						<strong>Valeur handicap :</strong>
						{selectedCourse.handicapValue || "—"}
					</p>
				</div>

				<label>
					<strong>Date :</strong>
					<input
						type="date"
						bind:value={selectedCourse.date}
						disabled={!editMode && !createMode}
					/>
				</label>

				<label>
					<strong>Heure de départ :</strong>
					<input
						type="time"
						bind:value={selectedCourse.heureDepart}
						disabled={!editMode && !createMode}
					/>
				</label>

				<label>
					<strong>Parcours :</strong>
					<input
						bind:value={selectedCourse.parcours}
						disabled={!editMode && !createMode}
					/>
				</label>

				<label>
					<strong>Description :</strong>
					<textarea
						bind:value={selectedCourse.description}
						disabled={!editMode && !createMode}
					></textarea>
				</label>

				{#if editMode}
					<button class="save-button" on:click={saveChanges}>
						Enregistrer
					</button>
				{/if}

				{#if createMode}
					<div class="create-actions">
						<button class="save-button" on:click={createCourse}>
							Créer
						</button>
						<button class="cancel-button" on:click={cancelCreate}>
							Annuler
						</button>
					</div>
				{/if}

				{#if !createMode}
					<div class="results-section print-block">
						<div class="results-header">
							<h3>Résultats</h3>

							<div class="results-actions">
								{#if !selectedCourse.terminee}
									<button
										class="finish-button"
										on:click={markFinished}
									>
										Marquer comme terminée
									</button>
								{:else}
									<button
										class="reopen-button"
										on:click={reopenCourse}
									>
										Rouvrir la course
									</button>
								{/if}
							</div>
						</div>

						<div class="podium-box">
							<h4>Podium</h4>
							{#if getPodium(selectedCourse).length > 0}
								<ol>
									{#each getPodium(selectedCourse) as participant}
										<li>{participant.bateau}</li>
									{/each}
								</ol>
							{:else}
								<p>
									Aucun classement disponible pour le moment.
								</p>
							{/if}
						</div>

						{#if resultMode}
							<div class="results-edit-box">
								<h4>Saisie / modification des résultats</h4>

								<table>
									<thead>
										<tr>
											<th>Bateau</th>
											<th>Résultat saisi</th>
											<th>Position</th>
										</tr>
									</thead>
									<tbody>
										{#each selectedCourse.resultats as participant}
											<tr>
												<td>{participant.bateau}</td>
												<td>
													<input
														bind:value={
															participant.resultat
														}
														placeholder={selectedCourse.type ===
														"OD"
															? "1, 2, 3 ou DNF"
															: "HH:MM:SS ou DNF"}
													/>
												</td>
												<td
													>{participant.position ??
														"-"}</td
												>
											</tr>
										{/each}
									</tbody>
								</table>

								<div class="create-actions">
									<button
										class="save-button"
										on:click={saveResults}
									>
										Enregistrer les résultats
									</button>
								</div>
							</div>
						{:else}
							<div class="results-view-box">
								<table>
									<thead>
										<tr>
											<th>Bateau</th>
											<th>Résultat</th>
											<th>Position</th>
										</tr>
									</thead>
									<tbody>
										{#each selectedCourse.resultats as participant}
											<tr>
												<td>{participant.bateau}</td>
												<td
													>{participant.resultat ||
														"-"}</td
												>
												<td
													>{participant.position ??
														"-"}</td
												>
											</tr>
										{/each}
									</tbody>
								</table>
								<br />
								<button
									class="create-button"
									on:click={() => window.print()}
								>
									Imprimer les résultats
								</button>
							</div>
						{/if}
					</div>
				{/if}
			</div>
		{:else}
			<p>Aucune course sélectionnée.</p>
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

	.field-info {
		color: #1e40af;
		background: #eff6ff;
		border: 1px solid #bfdbfe;
		border-radius: 6px;
		padding: 10px 12px;
		font-size: 0.9rem;
		margin: -6px 0 4px 0;
	}

	h1,
	h2,
	h3,
	h4 {
		margin-top: 0;
	}

	.left-header,
	.header-row,
	.results-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 20px;
		gap: 10px;
	}

	.header-actions,
	.results-actions,
	.create-actions {
		display: flex;
		gap: 12px;
		flex-wrap: wrap;
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

	.course-button {
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
		color: black;
	}

	.course-button:hover {
		transform: translateY(-2px);
		box-shadow: 0 6px 14px rgba(0, 0, 0, 0.08);
	}

	.course-button.selected {
		background: #eff6ff;
		border-color: #2563eb;
	}

	.course-top-row {
		display: flex;
		justify-content: space-between;
		align-items: center;
		gap: 8px;
	}

	.course-button span,
	.course-button small {
		font-size: 0.9rem;
		color: #666;
	}

	.status-badge {
		font-size: 0.75rem;
		padding: 4px 8px;
		border-radius: 999px;
		font-weight: bold;
	}

	.status-active {
		background: #e6f6ea;
		color: #1e7a38;
	}

	.status-finished {
		background: #ececec;
		color: #555;
	}

	.inline-badge {
		margin-left: 8px;
	}

	.summary-banner,
	.podium-box,
	.results-edit-box,
	.results-view-box {
		background: #fafafa;
		border: 1px solid #e3e3e3;
		border-radius: 8px;
		padding: 16px;
	}

	.summary-banner {
		display: flex;
		justify-content: space-between;
		align-items: center;
		gap: 12px;
		flex-wrap: wrap;
	}

	.course-lock-note {
		color: #666;
		font-size: 0.95rem;
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
		font-size: 0.85rem;
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

	.serie-info-box {
		background: #eff6ff;
		color: #1e40af;
		border: 1px solid #bfdbfe;
		padding: 12px 14px;
		border-radius: 8px;
		font-weight: 600;
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
	textarea:disabled,
	select:disabled {
		background: #f9fafb;
		color: #555;
	}

	.results-section {
		margin-top: 10px;
		display: flex;
		flex-direction: column;
		gap: 16px;
	}

	table {
		width: 100%;
		border-collapse: collapse;
		background: white;
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

	button {
		border: none;
		border-radius: 6px;
		cursor: pointer;
		padding: 10px 14px;
		transition: all 0.15s ease;
		color: white;
	}

	button:hover {
		filter: brightness(1.05);
	}

	button:active {
		transform: scale(0.97);
	}

	.create-button {
		background: #16a34a;
	}

	.edit-button {
		background: #f59e0b;
	}

	.save-button {
		background: #2563eb;
	}

	.cancel-button {
		background: #9ca3af;
	}

	.secondary-button {
		background: #64748b;
	}

	.finish-button {
		background: #16a34a;
	}

	.reopen-button {
		background: #f59e0b;
	}

	.delete-button {
		background: #dc2626;
	}

	.course-button {
		color: black;
	}

	.print-only {
		display: none;
	}
	@media print {
		/* cacher ce qui n'est pas utile */
		.left-panel,
		.header-actions,
		.results-actions,
		button,
		nav,
		header {
			display: none !important;
		}

		/* garder uniquement le panneau de droite */
		.right-panel {
			box-shadow: none;
			border: none;
			padding: 0;
		}

		/* nettoyer visuel */
		body {
			background: white;
		}

		/* tableau propre */
		table {
			width: 100%;
			border-collapse: collapse;
		}

		th,
		td {
			border: 1px solid black;
			padding: 8px;
		}

		/* éviter les coupures moches */
		tr {
			page-break-inside: avoid;
		}
		/* cacher toute la partie droite (menu + user) */
		:global(.right-side) {
			display: none !important;
		}

		/* garder uniquement le logo + titre bien alignés */
		.header {
			justify-content: flex-start;
		}

		/* optionnel : recentrer un peu */
		.logo-container {
			margin: 0 auto;
		}

		.summary-banner {
			display: none !important;
		}

		table {
			page-break-inside: avoid;
			break-inside: avoid;
		}

		.podium-box {
			page-break-inside: avoid;
			break-inside: avoid;
		}

		.print-block {
			break-inside: avoid;
			page-break-inside: avoid;
		}

		.results-header {
			break-after: avoid;
			page-break-after: avoid;
		}
	}
</style>
