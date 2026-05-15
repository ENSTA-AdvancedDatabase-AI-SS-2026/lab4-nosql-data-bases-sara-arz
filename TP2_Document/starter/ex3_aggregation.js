/**
 * TP2 - Exercice 3 : Pipelines d'Agrégation
 * Use Case : Statistiques médicales HealthCare DZ
 */

use("medical_db");

// ─── 3.1 : Distribution des diagnostics par wilaya ────────────────────────────
print("=== 3.1 : Top diagnostics par wilaya ===");

const diagParWilaya = db.patients.aggregate([
  // Dérouler le tableau des consultations (1 doc par consultation)
  { $unwind: "$consultations" },
  // Grouper par wilaya + diagnostic, compter les occurrences
  {
    $group: {
      _id: {
        wilaya: "$adresse.wilaya",
        diagnostic: "$consultations.diagnostic"
      },
      count: { $sum: 1 }
    }
  },
  // Reformater le résultat
  {
    $project: {
      _id: 0,
      wilaya: "$_id.wilaya",
      diagnostic: "$_id.diagnostic",
      count: 1
    }
  },
  // Trier par nombre d'occurrences décroissant
  { $sort: { count: -1 } },
  { $limit: 20 }
]).toArray();

printjson(diagParWilaya);


// ─── 3.2 : Médicament le plus prescrit par spécialité ─────────────────────────
print("\n=== 3.2 : Top médicaments par spécialité ===");

const medsParSpecialite = db.patients.aggregate([
  // Dérouler les consultations
  { $unwind: "$consultations" },
  // Dérouler les médicaments de chaque consultation
  { $unwind: "$consultations.medicaments" },
  // Grouper par spécialité + médicament
  {
    $group: {
      _id: {
        specialite: "$consultations.medecin.specialite",
        medicament: "$consultations.medicaments.nom"
      },
      nb_prescriptions: { $sum: 1 }
    }
  },
  // Trier pour pouvoir garder le top par spécialité
  { $sort: { "_id.specialite": 1, nb_prescriptions: -1 } },
  // Grouper par spécialité pour garder le médicament le plus prescrit
  {
    $group: {
      _id: "$_id.specialite",
      top_medicament: { $first: "$_id.medicament" },
      nb_prescriptions: { $first: "$nb_prescriptions" }
    }
  },
  {
    $project: {
      _id: 0,
      specialite: "$_id",
      top_medicament: 1,
      nb_prescriptions: 1
    }
  },
  { $sort: { nb_prescriptions: -1 } }
]).toArray();

printjson(medsParSpecialite);


// ─── 3.3 : Évolution mensuelle des consultations ──────────────────────────────
print("\n=== 3.3 : Consultations par mois (12 derniers mois) ===");

const evolutionMensuelle = db.patients.aggregate([
  { $unwind: "$consultations" },
  // Filtrer sur les 12 derniers mois
  {
    $match: {
      "consultations.date": {
        $gte: new Date(new Date().setFullYear(new Date().getFullYear() - 1))
      }
    }
  },
  // Grouper par année + mois
  {
    $group: {
      _id: {
        annee: { $year: "$consultations.date" },
        mois: { $month: "$consultations.date" }
      },
      nb_consultations: { $sum: 1 }
    }
  },
  // Trier chronologiquement
  { $sort: { "_id.annee": 1, "_id.mois": 1 } },
  // Formater la date en "YYYY-MM"
  {
    $project: {
      _id: 0,
      periode: {
        $concat: [
          { $toString: "$_id.annee" },
          "-",
          { $cond: [
            { $lt: ["$_id.mois", 10] },
            { $concat: ["0", { $toString: "$_id.mois" }] },
            { $toString: "$_id.mois" }
          ]}
        ]
      },
      nb_consultations: 1
    }
  }
]).toArray();

printjson(evolutionMensuelle);


// ─── 3.4 : Patients à risque multiple ────────────────────────────────────────
print("\n=== 3.4 : Profil patients à risque élevé (Diabète + HTA + âge > 60) ===");

const today = new Date();
const patientsRisque = db.patients.aggregate([
  {
    $match: {
      antecedents: { $all: ["Diabète type 2", "HTA"] }
    }
  },
  // Calculer l'âge
  {
    $addFields: {
      age: {
        $floor: {
          $divide: [
            { $subtract: [today, "$dateNaissance"] },
            1000 * 60 * 60 * 24 * 365.25
          ]
        }
      },
      nb_consultations: { $size: "$consultations" }
    }
  },
  // Filtrer âge > 60
  { $match: { age: { $gt: 60 } } },
  // Calculer les statistiques globales
  {
    $group: {
      _id: null,
      nb_patients: { $sum: 1 },
      age_moyen: { $avg: "$age" },
      consultations_moyennes: { $avg: "$nb_consultations" },
      patients: { $push: { nom: "$nom", prenom: "$prenom", age: "$age", nb_consultations: "$nb_consultations" } }
    }
  },
  {
    $project: {
      _id: 0,
      nb_patients: 1,
      age_moyen: { $round: ["$age_moyen", 1] },
      consultations_moyennes: { $round: ["$consultations_moyennes", 1] },
      patients: 1
    }
  }
]).toArray();

printjson(patientsRisque);


// ─── 3.5 : Rapport médecins ───────────────────────────────────────────────────
print("\n=== 3.5 : Top 5 médecins & taux de ré-consultation ===");

const rapportMedecins = db.patients.aggregate([
  { $unwind: "$consultations" },
  // Grouper par médecin : compter les patients uniques et les consultations totales
  {
    $group: {
      _id: "$consultations.medecin.nom",
      specialite: { $first: "$consultations.medecin.specialite" },
      total_consultations: { $sum: 1 },
      // Collecter les IDs patients uniques
      patients_uniques: { $addToSet: "$_id" }
    }
  },
  // Calculer le taux de ré-consultation
  {
    $addFields: {
      nb_patients_uniques: { $size: "$patients_uniques" },
      taux_reconsultation_pct: {
        $multiply: [
          {
            $divide: [
              { $subtract: ["$total_consultations", { $size: "$patients_uniques" }] },
              { $size: "$patients_uniques" }
            ]
          },
          100
        ]
      }
    }
  },
  {
    $project: {
      _id: 0,
      medecin: "$_id",
      specialite: 1,
      total_consultations: 1,
      nb_patients_uniques: 1,
      taux_reconsultation_pct: { $round: ["$taux_reconsultation_pct", 1] }
    }
  },
  { $sort: { total_consultations: -1 } },
  { $limit: 5 }
]).toArray();

printjson(rapportMedecins);