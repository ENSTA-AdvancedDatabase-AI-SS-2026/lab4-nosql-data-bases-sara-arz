
use("medical_db");
// =====================================================
// 2.1 Patients diabétiques de plus de 50 ans à Alger
// =====================================================

db.patients.find({
  antecedents: "Diabète",
  "adresse.wilaya": "Alger",
  dateNaissance: {
    $lte: new Date(new Date().setFullYear(new Date().getFullYear() - 50))
  }
})

// =====================================================
// 2.2 Allergiques à la pénicilline avec au moins 3 consultations
// =====================================================

db.patients.find({
  allergies: "Pénicilline",
  $expr: {
    $gte: [{ $size: "$consultations" }, 3]
  }
})

// =====================================================
// 2.3 Projection : nom, prénom et dernière consultation
// =====================================================

db.patients.aggregate([
  {
    $project: {
      nom: 1,
      prenom: 1,
      derniereConsultation: {
        $arrayElemAt: ["$consultations", -1]
      }
    }
  }
])

// =====================================================
// 2.4 Patients sans antécédents avec tension > 140
// =====================================================

db.patients.aggregate([
  {
    $addFields: {
      derniereConsultation: {
        $arrayElemAt: ["$consultations", -1]
      }
    }
  },
  {
    $match: {
      antecedents: { $size: 0 },
      "derniereConsultation.tension.systolique": { $gt: 140 }
    }
  }
])

// =====================================================
// 2.5 Recherche textuelle sur les diagnostics
// =====================================================

// Création index text

db.patients.createIndex({
  "consultations.diagnostic": "text"
})

// Recherche

db.patients.find({
  $text: {
    $search: "hypertension diabète"
  }
})
