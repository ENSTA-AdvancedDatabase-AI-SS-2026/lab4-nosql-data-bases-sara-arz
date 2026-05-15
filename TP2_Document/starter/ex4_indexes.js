/**
 * TP2 - Exercice 4 : Index et Optimisation
 */

use("medical_db");

// ─── 4.1 : Créer les index appropriés ────────────────────────────────────────

// Index 1 : Requête fréquente — patients d'une wilaya avec un antécédent donné
// Ordre : wilaya en premier (cardinalité intermédiaire, filtré souvent),
// puis antecedents (tableau). Couvre la requête 2.1 du TP.
db.patients.createIndex(
  { "adresse.wilaya": 1, antecedents: 1 },
  { name: "idx_wilaya_antecedents" }
);

// Index 2 : Tri/recherche sur les dates de consultation (requête 3.3 — évolution mensuelle)
// Index sur le champ de tableau imbriqué : MongoDB crée un index multiclé automatiquement.
db.patients.createIndex(
  { "consultations.date": 1 },
  { name: "idx_consultation_date" }
);

// Index 3 : Recherche full-text sur les diagnostics (requête 2.5)
// Un seul index text par collection — on peut inclure plusieurs champs.
db.patients.createIndex(
  { "consultations.diagnostic": "text", "consultations.notes": "text" },
  { name: "idx_text_diagnostics" }
);

// Index 4 : Analyses par patient — optimise les $lookup patient→analyses
db.analyses.createIndex(
  { patient_id: 1, date: -1 },
  { name: "idx_analyses_patient_date" }
);

// Index 5 : Recherche par groupe sanguin + sexe (requête démographique)
db.patients.createIndex(
  { groupeSanguin: 1, sexe: 1 },
  { name: "idx_groupe_sanguin_sexe" }
);

print("Index créés :", db.patients.getIndexes().map(i => i.name));


// ─── 4.2 : Comparer avec explain() ────────────────────────────────────────────

const requeteTest = {
  "adresse.wilaya": "Alger",
  antecedents: "Diabète type 2"
};

print("\n=== AVANT index (simulé avec hint pour forcer COLLSCAN) ===");
const avantIndex = db.patients.find(requeteTest)
  .hint({ $natural: 1 })           // Force un scan de collection
  .explain("executionStats");

print("  planWinnerStage :", avantIndex.executionStats.executionStages.stage);
print("  nReturned       :", avantIndex.executionStats.nReturned);
print("  docsExaminés    :", avantIndex.executionStats.totalDocsExamined);
print("  temps (ms)      :", avantIndex.executionStats.executionTimeMillis);

print("\n=== APRÈS index (utilise idx_wilaya_antecedents) ===");
const apresIndex = db.patients.find(requeteTest)
  .hint({ "adresse.wilaya": 1, antecedents: 1 })  // Force l'index composé
  .explain("executionStats");

print("  planWinnerStage :", apresIndex.executionStats.executionStages.stage);
print("  nReturned       :", apresIndex.executionStats.nReturned);
print("  docsExaminés    :", apresIndex.executionStats.totalDocsExamined);
print("  temps (ms)      :", apresIndex.executionStats.executionTimeMillis);

// ─── 4.3 : Index composé pour la requête la plus complexe ────────────────────
// La requête 3.4 (patients à risque) filtre d'abord sur antecedents ($all),
// puis calcule l'âge. Un index sur antecedents + dateNaissance permet
// de filtrer ET de projeter sans accéder aux documents complets.
// Ordre des champs : antecedents en premier (filtre d'égalité $all),
// dateNaissance en second (utilisé pour calculer l'âge → filtre de plage).
db.patients.createIndex(
  { antecedents: 1, dateNaissance: 1 },
  { name: "idx_antecedents_dob" }
);

print("\nIndex composé antecedents+dateNaissance créé pour requête patients à risque");

// ─── 4.4 : Index TTL pour archivage ───────────────────────────────────────────
// Les analyses de plus de 5 ans (157 680 000 secondes) sont supprimées automatiquement.
// ATTENTION : Ce TTL est en secondes après la valeur du champ 'date'.
// En production, on utilise une stratégie d'archivage avant suppression.
db.analyses.createIndex(
  { date: 1 },
  {
    expireAfterSeconds: 157680000,  // 5 ans = 5 × 365.25 × 24 × 3600
    name: "idx_ttl_analyses_5ans"
  }
);

print("Index TTL créé : analyses supprimées automatiquement après 5 ans");
print("   (expireAfterSeconds = 157 680 000 secondes)");

// Résumé des index sur la collection analyses
print("\nIndex sur analyses :", db.analyses.getIndexes().map(i => i.name));