use ("medical_db");

// =====================================================
// 5.1 Dossier complet patient + analyses
// =====================================================

db.patients.aggregate([
  {
    $lookup: {
      from: "analyses",
      localField: "_id",
      foreignField: "patient_id",
      as: "analyses"
    }
  }
])

// =====================================================
// 5.2 Patients avec glycémie > 1.26 g/L
// =====================================================

db.analyses.aggregate([
  {
    $match: {
      type: "Glycémie",
      "resultats.glycemie": {
        $gt: 1.26
      }
    }
  },
  {
    $lookup: {
      from: "patients",
      localField: "patient_id",
      foreignField: "_id",
      as: "patient"
    }
  },
  {
    $unwind: "$patient"
  },
  {
    $project: {
      _id: 0,
      nom: "$patient.nom",
      prenom: "$patient.prenom",
      glycemie: "$resultats.glycemie"
    }
  }
])

// =====================================================
// 5.3 Taux d'analyses anormales par wilaya
// =====================================================

db.analyses.aggregate([
  {
    $lookup: {
      from: "patients",
      localField: "patient_id",
      foreignField: "_id",
      as: "patient"
    }
  },
  {
    $unwind: "$patient"
  },
  {
    $group: {
      _id: "$patient.adresse.wilaya",
      totalAnalyses: {
        $sum: 1
      },
      analysesAnormales: {
        $sum: {
          $cond: [
            {
              $gt: ["$resultats.glycemie", 1.26]
            },
            1,
            0
          ]
        }
      }
    }
  },
  {
    $project: {
      wilaya: "$_id",
      tauxAnormal: {
        $multiply: [
          {
            $divide: ["$analysesAnormales", "$totalAnalyses"]
          },
          100
        ]
      }
    }
  }
])