/**
 * TP2 - Exercice 1 : Modélisation MongoDB
 * Use Case : HealthCare DZ - Dossiers Médicaux
 */

use("medical_db");

// ─── 1.1 : Créer la collection avec validation ────────────────────────────────
db.createCollection("patients", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["cin", "nom", "prenom", "dateNaissance", "sexe", "adresse", "groupeSanguin"],
      properties: {
        cin: {
          bsonType: "string",
          minLength: 12,
          maxLength: 12,
          description: "CIN à 12 chiffres — obligatoire"
        },
        nom: { bsonType: "string", description: "Nom de famille — obligatoire" },
        prenom: { bsonType: "string", description: "Prénom — obligatoire" },
        dateNaissance: { bsonType: "date", description: "Date de naissance — obligatoire" },
        sexe: {
          bsonType: "string",
          enum: ["M", "F"],
          description: "Sexe : M ou F — obligatoire"
        },
        adresse: {
          bsonType: "object",
          required: ["wilaya"],
          properties: {
            wilaya: { bsonType: "string" },
            commune: { bsonType: "string" }
          }
        },
        groupeSanguin: {
          bsonType: "string",
          enum: ["A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-"],
          description: "Groupe sanguin — obligatoire"
        },
        antecedents: { bsonType: "array", items: { bsonType: "string" } },
        allergies: { bsonType: "array", items: { bsonType: "string" } },
        consultations: { bsonType: "array" }
      }
    }
  }
});

// ─── 1.2 : Insérer 20 patients avec données algériennes ──────────────────────
const patients = [
  {
    cin: "198001012300",
    nom: "Bensalem", prenom: "Ahmed",
    dateNaissance: new Date("1980-01-01"),
    sexe: "M",
    adresse: { wilaya: "Alger", commune: "Bab Ezzouar" },
    groupeSanguin: "O+",
    antecedents: ["Diabète type 2", "HTA"],
    allergies: ["Pénicilline"],
    consultations: [
      {
        id: UUID(),
        date: new Date("2024-01-15"),
        medecin: { nom: "Dr. Mansouri", specialite: "Cardiologie" },
        diagnostic: "Hypertension artérielle",
        tension: { systolique: 145, diastolique: 92 },
        medicaments: [{ nom: "Amlodipine", dosage: "5mg", duree: "30 jours" }],
        notes: "Surveillance tensionnelle recommandée"
      },
      {
        id: UUID(),
        date: new Date("2024-06-10"),
        medecin: { nom: "Dr. Mansouri", specialite: "Cardiologie" },
        diagnostic: "HTA contrôlée",
        tension: { systolique: 130, diastolique: 82 },
        medicaments: [{ nom: "Amlodipine", dosage: "5mg", duree: "60 jours" }],
        notes: "Amélioration notable"
      },
      {
        id: UUID(),
        date: new Date("2024-11-20"),
        medecin: { nom: "Dr. Benali", specialite: "Endocrinologie" },
        diagnostic: "Diabète type 2 déséquilibré",
        tension: { systolique: 138, diastolique: 88 },
        medicaments: [
          { nom: "Metformine", dosage: "1000mg", duree: "90 jours" },
          { nom: "Gliclazide", dosage: "80mg", duree: "90 jours" }
        ],
        notes: "Glycémie à jeun : 1.85 g/L. Régime renforcé."
      }
    ]
  },
  {
    cin: "199203154100",
    nom: "Ouali", prenom: "Fatima",
    dateNaissance: new Date("1992-03-15"),
    sexe: "F",
    adresse: { wilaya: "Alger", commune: "Hydra" },
    groupeSanguin: "A+",
    antecedents: ["Asthme"],
    allergies: ["Aspirine", "Ibuprofène"],
    consultations: [
      {
        id: UUID(),
        date: new Date("2024-02-20"),
        medecin: { nom: "Dr. Khelifi", specialite: "Pneumologie" },
        diagnostic: "Crise d'asthme modérée",
        tension: { systolique: 118, diastolique: 74 },
        medicaments: [
          { nom: "Ventoline", dosage: "100mcg", duree: "En cas de besoin" },
          { nom: "Becotide", dosage: "200mcg", duree: "60 jours" }
        ],
        notes: "Éviter les allergènes"
      },
      {
        id: UUID(),
        date: new Date("2024-09-05"),
        medecin: { nom: "Dr. Khelifi", specialite: "Pneumologie" },
        diagnostic: "Asthme stable",
        tension: { systolique: 115, diastolique: 72 },
        medicaments: [{ nom: "Becotide", dosage: "200mcg", duree: "90 jours" }],
        notes: "Bonne observance thérapeutique"
      }
    ]
  },
  {
    cin: "197506280900",
    nom: "Meziane", prenom: "Karim",
    dateNaissance: new Date("1975-06-28"),
    sexe: "M",
    adresse: { wilaya: "Oran", commune: "Bir El Djir" },
    groupeSanguin: "B+",
    antecedents: ["Diabète type 2", "Dyslipidémie"],
    allergies: [],
    consultations: [
      {
        id: UUID(),
        date: new Date("2024-03-10"),
        medecin: { nom: "Dr. Belarbi", specialite: "Médecine Générale" },
        diagnostic: "Contrôle diabétique",
        tension: { systolique: 128, diastolique: 80 },
        medicaments: [{ nom: "Metformine", dosage: "850mg", duree: "90 jours" }],
        notes: "HbA1c : 7.2%"
      },
      {
        id: UUID(),
        date: new Date("2024-07-18"),
        medecin: { nom: "Dr. Belarbi", specialite: "Médecine Générale" },
        diagnostic: "Dyslipidémie",
        tension: { systolique: 130, diastolique: 82 },
        medicaments: [
          { nom: "Atorvastatine", dosage: "20mg", duree: "180 jours" },
          { nom: "Metformine", dosage: "850mg", duree: "90 jours" }
        ],
        notes: "LDL : 1.65 g/L"
      }
    ]
  },
  {
    cin: "196812051500",
    nom: "Hamdi", prenom: "Yasmina",
    dateNaissance: new Date("1968-12-05"),
    sexe: "F",
    adresse: { wilaya: "Constantine", commune: "El Khroub" },
    groupeSanguin: "AB+",
    antecedents: ["HTA", "Insuffisance rénale chronique"],
    allergies: ["Pénicilline", "Céphalosporines"],
    consultations: [
      {
        id: UUID(),
        date: new Date("2024-01-08"),
        medecin: { nom: "Dr. Bouderbala", specialite: "Néphrologie" },
        diagnostic: "IRC stade 3",
        tension: { systolique: 150, diastolique: 96 },
        medicaments: [
          { nom: "Losartan", dosage: "50mg", duree: "90 jours" },
          { nom: "Furosémide", dosage: "40mg", duree: "30 jours" }
        ],
        notes: "DFG : 42 mL/min. Régime hyposodé strict."
      },
      {
        id: UUID(),
        date: new Date("2024-04-15"),
        medecin: { nom: "Dr. Bouderbala", specialite: "Néphrologie" },
        diagnostic: "IRC stade 3 — stable",
        tension: { systolique: 142, diastolique: 90 },
        medicaments: [{ nom: "Losartan", dosage: "100mg", duree: "90 jours" }],
        notes: "Créatinine stable à 1.8 mg/dL"
      },
      {
        id: UUID(),
        date: new Date("2024-10-22"),
        medecin: { nom: "Dr. Bouderbala", specialite: "Néphrologie" },
        diagnostic: "Suivi trimestriel",
        tension: { systolique: 138, diastolique: 88 },
        medicaments: [{ nom: "Losartan", dosage: "100mg", duree: "90 jours" }],
        notes: "Protéinurie légèrement élevée"
      }
    ]
  },
  {
    cin: "199809221800",
    nom: "Belkacem", prenom: "Rania",
    dateNaissance: new Date("1998-09-22"),
    sexe: "F",
    adresse: { wilaya: "Blida", commune: "Boufarik" },
    groupeSanguin: "O-",
    antecedents: [],
    allergies: [],
    consultations: [
      {
        id: UUID(),
        date: new Date("2024-05-14"),
        medecin: { nom: "Dr. Cherif", specialite: "Médecine Générale" },
        diagnostic: "Rhinopharyngite aiguë",
        tension: { systolique: 112, diastolique: 70 },
        medicaments: [
          { nom: "Paracétamol", dosage: "1000mg", duree: "5 jours" },
          { nom: "Rhinofluimucil", dosage: "spray", duree: "7 jours" }
        ],
        notes: "Guérison attendue en 7-10 jours"
      }
    ]
  },
  {
    cin: "195504130200",
    nom: "Derbal", prenom: "Mostefa",
    dateNaissance: new Date("1955-04-13"),
    sexe: "M",
    adresse: { wilaya: "Annaba", commune: "El Bouni" },
    groupeSanguin: "A-",
    antecedents: ["Diabète type 2", "HTA", "Cardiopathie ischémique"],
    allergies: ["Sulfamides"],
    consultations: [
      {
        id: UUID(),
        date: new Date("2023-12-10"),
        medecin: { nom: "Dr. Mansouri", specialite: "Cardiologie" },
        diagnostic: "Angine de poitrine stable",
        tension: { systolique: 148, diastolique: 94 },
        medicaments: [
          { nom: "Amlodipine", dosage: "10mg", duree: "90 jours" },
          { nom: "Aspirine", dosage: "100mg", duree: "À vie" },
          { nom: "Atorvastatine", dosage: "40mg", duree: "90 jours" }
        ],
        notes: "ECG : sous-décalage ST minime"
      },
      {
        id: UUID(),
        date: new Date("2024-03-15"),
        medecin: { nom: "Dr. Mansouri", specialite: "Cardiologie" },
        diagnostic: "Suivi cardiologique",
        tension: { systolique: 140, diastolique: 88 },
        medicaments: [
          { nom: "Amlodipine", dosage: "10mg", duree: "90 jours" },
          { nom: "Bisoprolol", dosage: "5mg", duree: "90 jours" }
        ],
        notes: "Echo: FE 50%"
      },
      {
        id: UUID(),
        date: new Date("2024-08-20"),
        medecin: { nom: "Dr. Benali", specialite: "Endocrinologie" },
        diagnostic: "Diabète type 2 mal équilibré",
        tension: { systolique: 145, diastolique: 92 },
        medicaments: [
          { nom: "Insuline glargine", dosage: "20UI/soir", duree: "90 jours" },
          { nom: "Metformine", dosage: "500mg", duree: "90 jours" }
        ],
        notes: "HbA1c : 9.1%. Passage à l'insuline."
      }
    ]
  },
  {
    cin: "199112087600",
    nom: "Amrani", prenom: "Leila",
    dateNaissance: new Date("1991-12-08"),
    sexe: "F",
    adresse: { wilaya: "Alger", commune: "Dar El Beida" },
    groupeSanguin: "B-",
    antecedents: ["Anémie ferriprive"],
    allergies: [],
    consultations: [
      {
        id: UUID(),
        date: new Date("2024-04-02"),
        medecin: { nom: "Dr. Kaci", specialite: "Hématologie" },
        diagnostic: "Anémie ferriprive modérée",
        tension: { systolique: 108, diastolique: 66 },
        medicaments: [{ nom: "Ferrograd", dosage: "325mg", duree: "90 jours" }],
        notes: "Hb : 9.2 g/dL. Supplémentation en fer."
      },
      {
        id: UUID(),
        date: new Date("2024-07-10"),
        medecin: { nom: "Dr. Kaci", specialite: "Hématologie" },
        diagnostic: "Anémie en voie d'amélioration",
        tension: { systolique: 112, diastolique: 70 },
        medicaments: [{ nom: "Ferrograd", dosage: "325mg", duree: "60 jours" }],
        notes: "Hb : 11.5 g/dL. Poursuite traitement."
      }
    ]
  },
  {
    cin: "196203251200",
    nom: "Boudia", prenom: "Hocine",
    dateNaissance: new Date("1962-03-25"),
    sexe: "M",
    adresse: { wilaya: "Oran", commune: "Es Senia" },
    groupeSanguin: "AB-",
    antecedents: ["HTA", "Goutte"],
    allergies: ["Allopurinol"],
    consultations: [
      {
        id: UUID(),
        date: new Date("2024-02-05"),
        medecin: { nom: "Dr. Belarbi", specialite: "Médecine Générale" },
        diagnostic: "Crise de goutte",
        tension: { systolique: 152, diastolique: 98 },
        medicaments: [
          { nom: "Colchicine", dosage: "1mg", duree: "10 jours" },
          { nom: "Losartan", dosage: "50mg", duree: "30 jours" }
        ],
        notes: "Acide urique : 85 mg/L. Régime hypo-purinique."
      },
      {
        id: UUID(),
        date: new Date("2024-06-18"),
        medecin: { nom: "Dr. Belarbi", specialite: "Médecine Générale" },
        diagnostic: "HTA — contrôle",
        tension: { systolique: 144, diastolique: 90 },
        medicaments: [{ nom: "Amlodipine", dosage: "5mg", duree: "90 jours" }],
        notes: "Poids stable"
      },
      {
        id: UUID(),
        date: new Date("2024-11-12"),
        medecin: { nom: "Dr. Belarbi", specialite: "Médecine Générale" },
        diagnostic: "Suivi HTA + goutte",
        tension: { systolique: 138, diastolique: 86 },
        medicaments: [{ nom: "Amlodipine", dosage: "10mg", duree: "90 jours" }],
        notes: "Acide urique redescendu à 62 mg/L"
      }
    ]
  },
  {
    cin: "200010303400",
    nom: "Haddar", prenom: "Anis",
    dateNaissance: new Date("2000-10-30"),
    sexe: "M",
    adresse: { wilaya: "Constantine", commune: "Hamma Bouziane" },
    groupeSanguin: "O+",
    antecedents: [],
    allergies: [],
    consultations: [
      {
        id: UUID(),
        date: new Date("2024-08-15"),
        medecin: { nom: "Dr. Bouderbala", specialite: "Médecine Générale" },
        diagnostic: "Gastro-entérite aiguë",
        tension: { systolique: 116, diastolique: 72 },
        medicaments: [
          { nom: "Smecta", dosage: "3g", duree: "5 jours" },
          { nom: "Paracétamol", dosage: "500mg", duree: "3 jours" }
        ],
        notes: "Réhydratation orale recommandée"
      }
    ]
  },
  {
    cin: "197808171600",
    nom: "Tebbal", prenom: "Nadia",
    dateNaissance: new Date("1978-08-17"),
    sexe: "F",
    adresse: { wilaya: "Blida", commune: "Larbaa" },
    groupeSanguin: "A+",
    antecedents: ["Hypothyroïdie"],
    allergies: [],
    consultations: [
      {
        id: UUID(),
        date: new Date("2024-01-25"),
        medecin: { nom: "Dr. Cherif", specialite: "Endocrinologie" },
        diagnostic: "Hypothyroïdie",
        tension: { systolique: 120, diastolique: 76 },
        medicaments: [{ nom: "Levothyrox", dosage: "75mcg", duree: "180 jours" }],
        notes: "TSH : 8.2 mUI/L"
      },
      {
        id: UUID(),
        date: new Date("2024-07-30"),
        medecin: { nom: "Dr. Cherif", specialite: "Endocrinologie" },
        diagnostic: "Hypothyroïdie équilibrée",
        tension: { systolique: 118, diastolique: 74 },
        medicaments: [{ nom: "Levothyrox", dosage: "75mcg", duree: "180 jours" }],
        notes: "TSH : 2.1 mUI/L. Bon équilibre."
      }
    ]
  },
  {
    cin: "198511224700",
    nom: "Sadaoui", prenom: "Rachid",
    dateNaissance: new Date("1985-11-22"),
    sexe: "M",
    adresse: { wilaya: "Alger", commune: "El Harrach" },
    groupeSanguin: "B+",
    antecedents: ["Ulcère gastrique"],
    allergies: ["Ibuprofène"],
    consultations: [
      {
        id: UUID(),
        date: new Date("2024-03-08"),
        medecin: { nom: "Dr. Khelifi", specialite: "Gastro-entérologie" },
        diagnostic: "Ulcère duodénal",
        tension: { systolique: 124, diastolique: 78 },
        medicaments: [
          { nom: "Oméprazole", dosage: "20mg", duree: "60 jours" },
          { nom: "Amoxicilline", dosage: "1g", duree: "14 jours" },
          { nom: "Clarithromycine", dosage: "500mg", duree: "14 jours" }
        ],
        notes: "Triplethérapie anti-H. pylori"
      },
      {
        id: UUID(),
        date: new Date("2024-06-20"),
        medecin: { nom: "Dr. Khelifi", specialite: "Gastro-entérologie" },
        diagnostic: "Ulcère en cicatrisation",
        tension: { systolique: 122, diastolique: 76 },
        medicaments: [{ nom: "Oméprazole", dosage: "20mg", duree: "30 jours" }],
        notes: "Contrôle endoscopique recommandé"
      }
    ]
  },
  {
    cin: "196907141000",
    nom: "Bouchama", prenom: "Zohra",
    dateNaissance: new Date("1969-07-14"),
    sexe: "F",
    adresse: { wilaya: "Annaba", commune: "Seraidi" },
    groupeSanguin: "O+",
    antecedents: ["Diabète type 2", "HTA", "Obésité"],
    allergies: ["Pénicilline"],
    consultations: [
      {
        id: UUID(),
        date: new Date("2024-02-12"),
        medecin: { nom: "Dr. Mansouri", specialite: "Cardiologie" },
        diagnostic: "HTA sévère",
        tension: { systolique: 165, diastolique: 102 },
        medicaments: [
          { nom: "Amlodipine", dosage: "10mg", duree: "90 jours" },
          { nom: "Ramipril", dosage: "5mg", duree: "90 jours" }
        ],
        notes: "IMC : 34. Conseils nutritionnels urgents."
      },
      {
        id: UUID(),
        date: new Date("2024-05-20"),
        medecin: { nom: "Dr. Benali", specialite: "Endocrinologie" },
        diagnostic: "Diabète type 2 + HTA",
        tension: { systolique: 155, diastolique: 96 },
        medicaments: [
          { nom: "Metformine", dosage: "1000mg", duree: "90 jours" },
          { nom: "Amlodipine", dosage: "10mg", duree: "90 jours" }
        ],
        notes: "HbA1c : 8.5%"
      },
      {
        id: UUID(),
        date: new Date("2024-10-05"),
        medecin: { nom: "Dr. Benali", specialite: "Endocrinologie" },
        diagnostic: "Contrôle trimestriel",
        tension: { systolique: 148, diastolique: 92 },
        medicaments: [
          { nom: "Metformine", dosage: "1000mg", duree: "90 jours" },
          { nom: "Sitagliptine", dosage: "100mg", duree: "90 jours" }
        ],
        notes: "Glycémie partiellement contrôlée"
      }
    ]
  },
  {
    cin: "199407259900",
    nom: "Benali", prenom: "Sofiane",
    dateNaissance: new Date("1994-07-25"),
    sexe: "M",
    adresse: { wilaya: "Oran", commune: "Arzew" },
    groupeSanguin: "A+",
    antecedents: [],
    allergies: [],
    consultations: [
      {
        id: UUID(),
        date: new Date("2024-11-03"),
        medecin: { nom: "Dr. Belarbi", specialite: "Médecine Générale" },
        diagnostic: "Lombalgie aiguë",
        tension: { systolique: 120, diastolique: 75 },
        medicaments: [
          { nom: "Diclofénac", dosage: "50mg", duree: "7 jours" },
          { nom: "Myolastan", dosage: "50mg", duree: "5 jours" }
        ],
        notes: "Repos relatif + kinésithérapie"
      }
    ]
  },
  {
    cin: "197302083300",
    nom: "Chekroun", prenom: "Malika",
    dateNaissance: new Date("1973-02-08"),
    sexe: "F",
    adresse: { wilaya: "Alger", commune: "Bab Ezzouar" },
    groupeSanguin: "B-",
    antecedents: ["HTA"],
    allergies: [],
    consultations: [
      {
        id: UUID(),
        date: new Date("2024-01-30"),
        medecin: { nom: "Dr. Mansouri", specialite: "Cardiologie" },
        diagnostic: "HTA stade 1",
        tension: { systolique: 148, diastolique: 92 },
        medicaments: [{ nom: "Amlodipine", dosage: "5mg", duree: "90 jours" }],
        notes: "Activité physique recommandée"
      },
      {
        id: UUID(),
        date: new Date("2024-05-05"),
        medecin: { nom: "Dr. Mansouri", specialite: "Cardiologie" },
        diagnostic: "HTA contrôlée",
        tension: { systolique: 136, diastolique: 84 },
        medicaments: [{ nom: "Amlodipine", dosage: "5mg", duree: "90 jours" }],
        notes: "Bon résultat"
      }
    ]
  },
  {
    cin: "196601272600",
    nom: "Morsli", prenom: "Belkacem",
    dateNaissance: new Date("1966-01-27"),
    sexe: "M",
    adresse: { wilaya: "Blida", commune: "Bougara" },
    groupeSanguin: "O+",
    antecedents: ["Diabète type 2", "HTA", "Rétinopathie diabétique"],
    allergies: [],
    consultations: [
      {
        id: UUID(),
        date: new Date("2024-02-28"),
        medecin: { nom: "Dr. Benali", specialite: "Endocrinologie" },
        diagnostic: "Diabète type 2 compliqué",
        tension: { systolique: 155, diastolique: 95 },
        medicaments: [
          { nom: "Insuline NPH", dosage: "30UI/soir", duree: "90 jours" },
          { nom: "Amlodipine", dosage: "10mg", duree: "90 jours" }
        ],
        notes: "HbA1c : 10.2%. Fond d'œil : rétinopathie non proliférante."
      },
      {
        id: UUID(),
        date: new Date("2024-08-10"),
        medecin: { nom: "Dr. Mansouri", specialite: "Cardiologie" },
        diagnostic: "HTA + cardiopathie ischémique",
        tension: { systolique: 150, diastolique: 94 },
        medicaments: [
          { nom: "Aspirine", dosage: "75mg", duree: "À vie" },
          { nom: "Bisoprolol", dosage: "2.5mg", duree: "90 jours" }
        ],
        notes: "Coronarographie prévue"
      },
      {
        id: UUID(),
        date: new Date("2024-11-25"),
        medecin: { nom: "Dr. Benali", specialite: "Endocrinologie" },
        diagnostic: "Suivi diabétique",
        tension: { systolique: 142, diastolique: 88 },
        medicaments: [
          { nom: "Insuline NPH", dosage: "40UI/soir", duree: "90 jours" }
        ],
        notes: "HbA1c : 8.8%. Légère amélioration."
      }
    ]
  },
  {
    cin: "198804196800",
    nom: "Ferroudj", prenom: "Imane",
    dateNaissance: new Date("1988-04-19"),
    sexe: "F",
    adresse: { wilaya: "Constantine", commune: "Ain Smara" },
    groupeSanguin: "AB+",
    antecedents: ["Migraine"],
    allergies: ["Codéine"],
    consultations: [
      {
        id: UUID(),
        date: new Date("2024-06-12"),
        medecin: { nom: "Dr. Kaci", specialite: "Neurologie" },
        diagnostic: "Migraine sans aura",
        tension: { systolique: 114, diastolique: 70 },
        medicaments: [
          { nom: "Sumatriptan", dosage: "50mg", duree: "En cas de crise" },
          { nom: "Propranolol", dosage: "40mg", duree: "90 jours" }
        ],
        notes: "Traitement de fond initié"
      },
      {
        id: UUID(),
        date: new Date("2024-10-18"),
        medecin: { nom: "Dr. Kaci", specialite: "Neurologie" },
        diagnostic: "Migraine partiellement contrôlée",
        tension: { systolique: 116, diastolique: 72 },
        medicaments: [{ nom: "Propranolol", dosage: "80mg", duree: "90 jours" }],
        notes: "Réduction des crises de 50%"
      }
    ]
  },
  {
    cin: "196004099400",
    nom: "Hadjadj", prenom: "Omar",
    dateNaissance: new Date("1960-04-09"),
    sexe: "M",
    adresse: { wilaya: "Annaba", commune: "El Hadjar" },
    groupeSanguin: "A-",
    antecedents: ["Diabète type 2", "HTA", "Insuffisance cardiaque"],
    allergies: ["Pénicilline", "Tétracyclines"],
    consultations: [
      {
        id: UUID(),
        date: new Date("2024-01-05"),
        medecin: { nom: "Dr. Mansouri", specialite: "Cardiologie" },
        diagnostic: "Insuffisance cardiaque décompensée",
        tension: { systolique: 160, diastolique: 100 },
        medicaments: [
          { nom: "Furosémide", dosage: "80mg", duree: "30 jours" },
          { nom: "Énalapril", dosage: "10mg", duree: "90 jours" },
          { nom: "Bisoprolol", dosage: "5mg", duree: "90 jours" }
        ],
        notes: "FE : 35%. Hospitalisation courte recommandée."
      },
      {
        id: UUID(),
        date: new Date("2024-04-22"),
        medecin: { nom: "Dr. Mansouri", specialite: "Cardiologie" },
        diagnostic: "IC stabilisée",
        tension: { systolique: 138, diastolique: 86 },
        medicaments: [
          { nom: "Furosémide", dosage: "40mg", duree: "90 jours" },
          { nom: "Énalapril", dosage: "10mg", duree: "90 jours" }
        ],
        notes: "FE : 40%. Amélioration."
      },
      {
        id: UUID(),
        date: new Date("2024-09-15"),
        medecin: { nom: "Dr. Benali", specialite: "Endocrinologie" },
        diagnostic: "Diabète type 2",
        tension: { systolique: 140, diastolique: 88 },
        medicaments: [
          { nom: "Insuline glargine", dosage: "24UI/soir", duree: "90 jours" }
        ],
        notes: "HbA1c : 8.0%"
      }
    ]
  },
  {
    cin: "199605217200",
    nom: "Khaldi", prenom: "Souad",
    dateNaissance: new Date("1996-05-21"),
    sexe: "F",
    adresse: { wilaya: "Alger", commune: "Hydra" },
    groupeSanguin: "O+",
    antecedents: ["Anémie ferriprive"],
    allergies: [],
    consultations: [
      {
        id: UUID(),
        date: new Date("2024-09-10"),
        medecin: { nom: "Dr. Kaci", specialite: "Hématologie" },
        diagnostic: "Anémie ferriprive légère",
        tension: { systolique: 110, diastolique: 68 },
        medicaments: [{ nom: "Tardyferon", dosage: "80mg", duree: "90 jours" }],
        notes: "Hb : 10.5 g/dL"
      }
    ]
  },
  {
    cin: "197110313800",
    nom: "Larbi", prenom: "Mustapha",
    dateNaissance: new Date("1971-10-31"),
    sexe: "M",
    adresse: { wilaya: "Oran", commune: "Bir El Djir" },
    groupeSanguin: "B+",
    antecedents: ["HTA", "Dyslipidémie"],
    allergies: [],
    consultations: [
      {
        id: UUID(),
        date: new Date("2024-02-18"),
        medecin: { nom: "Dr. Belarbi", specialite: "Médecine Générale" },
        diagnostic: "HTA + dyslipidémie",
        tension: { systolique: 150, diastolique: 95 },
        medicaments: [
          { nom: "Ramipril", dosage: "5mg", duree: "90 jours" },
          { nom: "Rosuvastatine", dosage: "10mg", duree: "180 jours" }
        ],
        notes: "LDL : 1.72 g/L. Contrôle dans 3 mois."
      },
      {
        id: UUID(),
        date: new Date("2024-07-05"),
        medecin: { nom: "Dr. Belarbi", specialite: "Médecine Générale" },
        diagnostic: "HTA contrôlée",
        tension: { systolique: 134, diastolique: 82 },
        medicaments: [
          { nom: "Ramipril", dosage: "5mg", duree: "90 jours" },
          { nom: "Rosuvastatine", dosage: "20mg", duree: "180 jours" }
        ],
        notes: "LDL : 1.21 g/L. Bon résultat."
      }
    ]
  },
  {
    cin: "200205068500",
    nom: "Touati", prenom: "Lylia",
    dateNaissance: new Date("2002-05-06"),
    sexe: "F",
    adresse: { wilaya: "Blida", commune: "Bougara" },
    groupeSanguin: "A+",
    antecedents: [],
    allergies: ["Latex"],
    consultations: [
      {
        id: UUID(),
        date: new Date("2024-04-28"),
        medecin: { nom: "Dr. Cherif", specialite: "Médecine Générale" },
        diagnostic: "Dermatite de contact",
        tension: { systolique: 108, diastolique: 66 },
        medicaments: [
          { nom: "Hydrocortisone crème", dosage: "1%", duree: "14 jours" },
          { nom: "Cétirizine", dosage: "10mg", duree: "10 jours" }
        ],
        notes: "Allergie au latex confirmée. Éviction stricte."
      },
      {
        id: UUID(),
        date: new Date("2024-08-15"),
        medecin: { nom: "Dr. Cherif", specialite: "Médecine Générale" },
        diagnostic: "Dermatite contrôlée",
        tension: { systolique: 110, diastolique: 68 },
        medicaments: [{ nom: "Loratadine", dosage: "10mg", duree: "30 jours" }],
        notes: "Port de gants en nitrile recommandé"
      }
    ]
  }
];

db.patients.insertMany(patients);

// ─── 1.3 : Collection analyses (référencée) ───────────────────────────────────
// Récupérer les _id des patients insérés
const patientBensalem = db.patients.findOne({ cin: "198001012300" });
const patientOuali = db.patients.findOne({ cin: "199203154100" });
const patientMeziane = db.patients.findOne({ cin: "197506280900" });
const patientHamdi = db.patients.findOne({ cin: "196812051500" });
const patientDerbal = db.patients.findOne({ cin: "195504130200" });
const patientBouchama = db.patients.findOne({ cin: "196907141000" });
const patientMorsli = db.patients.findOne({ cin: "196601272600" });
const patientHadjadj = db.patients.findOne({ cin: "196004099400" });

const analyses = [
  // Patient Bensalem — Diabète + HTA
  {
    patient_id: patientBensalem._id,
    date: new Date("2024-01-20"),
    type: "Glycémie",
    resultats: { glycemie_a_jeun_gL: 1.85, HbA1c_pct: 8.2, unite: "g/L" },
    laboratoire: "Labo Central Alger",
    valide: true
  },
  {
    patient_id: patientBensalem._id,
    date: new Date("2024-01-20"),
    type: "Lipidogramme",
    resultats: { cholesterol_total: 2.10, LDL: 1.35, HDL: 0.45, triglycerides: 1.55 },
    laboratoire: "Labo Central Alger",
    valide: true
  },
  {
    patient_id: patientBensalem._id,
    date: new Date("2024-11-25"),
    type: "Glycémie",
    resultats: { glycemie_a_jeun_gL: 1.72, HbA1c_pct: 7.8 },
    laboratoire: "Labo Central Alger",
    valide: true
  },
  // Patient Ouali — Asthme
  {
    patient_id: patientOuali._id,
    date: new Date("2024-02-22"),
    type: "NFS",
    resultats: { globules_blancs: 7200, eosinophiles_pct: 8, hemoglobine: 13.2 },
    laboratoire: "Labo Hydra",
    valide: true
  },
  // Patient Meziane — Diabète + Dyslipidémie
  {
    patient_id: patientMeziane._id,
    date: new Date("2024-03-12"),
    type: "Glycémie",
    resultats: { glycemie_a_jeun_gL: 1.45, HbA1c_pct: 7.2 },
    laboratoire: "Labo Oran Est",
    valide: true
  },
  {
    patient_id: patientMeziane._id,
    date: new Date("2024-03-12"),
    type: "Lipidogramme",
    resultats: { cholesterol_total: 2.35, LDL: 1.65, HDL: 0.38, triglycerides: 1.80 },
    laboratoire: "Labo Oran Est",
    valide: true
  },
  // Patient Hamdi — IRC
  {
    patient_id: patientHamdi._id,
    date: new Date("2024-01-10"),
    type: "Créatinine",
    resultats: { creatinine_mgdL: 1.8, DFG_mLmin: 42, uree_gL: 0.65 },
    laboratoire: "Labo Constantine Centre",
    valide: true
  },
  {
    patient_id: patientHamdi._id,
    date: new Date("2024-04-18"),
    type: "Créatinine",
    resultats: { creatinine_mgdL: 1.82, DFG_mLmin: 40, uree_gL: 0.68 },
    laboratoire: "Labo Constantine Centre",
    valide: true
  },
  // Patient Derbal — Diabète + HTA + Cardiopathie
  {
    patient_id: patientDerbal._id,
    date: new Date("2023-12-12"),
    type: "ECG",
    resultats: { rythme: "Sinusal", frequence_bpm: 72, anomalie: "Sous-décalage ST V5-V6" },
    laboratoire: "Service Cardiologie Annaba",
    valide: true
  },
  {
    patient_id: patientDerbal._id,
    date: new Date("2024-08-22"),
    type: "Glycémie",
    resultats: { glycemie_a_jeun_gL: 2.10, HbA1c_pct: 9.1 },
    laboratoire: "Labo El Bouni",
    valide: true
  },
  // Patient Bouchama — Diabète + HTA + Obésité
  {
    patient_id: patientBouchama._id,
    date: new Date("2024-02-15"),
    type: "Glycémie",
    resultats: { glycemie_a_jeun_gL: 2.20, HbA1c_pct: 8.5 },
    laboratoire: "Labo Annaba Nord",
    valide: true
  },
  {
    patient_id: patientBouchama._id,
    date: new Date("2024-05-22"),
    type: "NFS",
    resultats: { hemoglobine: 12.8, globules_blancs: 8100, plaquettes: 285000 },
    laboratoire: "Labo Annaba Nord",
    valide: true
  },
  // Patient Morsli — Diabète + HTA + Rétinopathie
  {
    patient_id: patientMorsli._id,
    date: new Date("2024-03-02"),
    type: "Glycémie",
    resultats: { glycemie_a_jeun_gL: 2.65, HbA1c_pct: 10.2 },
    laboratoire: "Labo Blida Centre",
    valide: true
  },
  {
    patient_id: patientMorsli._id,
    date: new Date("2024-03-02"),
    type: "Lipidogramme",
    resultats: { cholesterol_total: 2.55, LDL: 1.80, HDL: 0.32, triglycerides: 2.15 },
    laboratoire: "Labo Blida Centre",
    valide: true
  },
  // Patient Hadjadj — IC + Diabète
  {
    patient_id: patientHadjadj._id,
    date: new Date("2024-01-08"),
    type: "ECG",
    resultats: { rythme: "Sinusal", frequence_bpm: 88, anomalie: "HVG, trouble repolarisation" },
    laboratoire: "Service Cardiologie Annaba",
    valide: true
  },
  {
    patient_id: patientHadjadj._id,
    date: new Date("2024-09-18"),
    type: "Glycémie",
    resultats: { glycemie_a_jeun_gL: 1.92, HbA1c_pct: 8.0 },
    laboratoire: "Labo El Bouni",
    valide: true
  }
];

db.analyses.insertMany(analyses);

print("✅ Modélisation terminée.");
print("   Patients insérés:", db.patients.countDocuments());
print("   Analyses insérées:", db.analyses.countDocuments());