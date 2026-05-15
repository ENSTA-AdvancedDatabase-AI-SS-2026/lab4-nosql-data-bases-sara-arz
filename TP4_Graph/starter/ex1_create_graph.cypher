// TP4 - Exercice 1 : Création du graphe UniConnect DZ
// Effacer la base pour partir propre
MATCH (n) DETACH DELETE n;

// ─── 1.1 : Contraintes d'unicité ─────────────────────────────────────────────
CREATE CONSTRAINT etudiant_id IF NOT EXISTS FOR (e:Etudiant) REQUIRE e.id IS UNIQUE;
CREATE CONSTRAINT cours_code IF NOT EXISTS FOR (c:Cours) REQUIRE c.code IS UNIQUE;
CREATE CONSTRAINT competence_nom IF NOT EXISTS FOR (c:Competence) REQUIRE c.nom IS UNIQUE;
CREATE CONSTRAINT club_nom IF NOT EXISTS FOR (c:Club) REQUIRE c.nom IS UNIQUE;
CREATE CONSTRAINT entreprise_nom IF NOT EXISTS FOR (e:Entreprise) REQUIRE e.nom IS UNIQUE;

// ─── 1.2 : Créer les compétences ──────────────────────────────────────────────
UNWIND [
  {nom: "Python", categorie: "Programmation"},
  {nom: "Java", categorie: "Programmation"},
  {nom: "C++", categorie: "Programmation"},
  {nom: "SQL", categorie: "Bases de Données"},
  {nom: "NoSQL", categorie: "Bases de Données"},
  {nom: "Machine Learning", categorie: "IA"},
  {nom: "Deep Learning", categorie: "IA"},
  {nom: "Traitement du Signal", categorie: "Electronique"},
  {nom: "React", categorie: "Web"},
  {nom: "Docker", categorie: "DevOps"},
  {nom: "Linux", categorie: "Systèmes"},
  {nom: "Réseaux", categorie: "Infrastructure"},
  {nom: "Cybersécurité", categorie: "Sécurité"},
  {nom: "Matlab", categorie: "Scientifique"},
  {nom: "LaTeX", categorie: "Outils"}
] AS comp
MERGE (:Competence {nom: comp.nom, categorie: comp.categorie});

// ─── 1.3 : Créer les cours ────────────────────────────────────────────────────
UNWIND [
  {code: "INFO401", intitule: "Bases de Données Avancées", credits: 6, dept: "Informatique"},
  {code: "INFO402", intitule: "Intelligence Artificielle", credits: 6, dept: "Informatique"},
  {code: "INFO403", intitule: "Développement Web", credits: 4, dept: "Informatique"},
  {code: "INFO404", intitule: "Systèmes Distribués", credits: 5, dept: "Informatique"},
  {code: "INFO405", intitule: "Cloud Computing", credits: 4, dept: "Informatique"},
  {code: "INFO301", intitule: "Algorithmique Avancée", credits: 5, dept: "Informatique"},
  {code: "MATH401", intitule: "Algèbre Linéaire Appliquée", credits: 4, dept: "Mathématiques"},
  {code: "ELEC401", intitule: "Traitement du Signal", credits: 5, dept: "Electronique"},
  {code: "TELEC401", intitule: "Protocoles Réseaux", credits: 5, dept: "Télécoms"},
  {code: "SEC401", intitule: "Sécurité Informatique", credits: 4, dept: "Informatique"}
] AS cours
MERGE (:Cours {code: cours.code, intitule: cours.intitule,
               credits: cours.credits, departement: cours.dept});

// ─── Relation Cours → Compétences requises ────────────────────────────────────
MATCH (c:Cours {code: "INFO401"}), (s:Competence {nom: "SQL"})   MERGE (c)-[:REQUIERT]->(s);
MATCH (c:Cours {code: "INFO401"}), (s:Competence {nom: "NoSQL"}) MERGE (c)-[:REQUIERT]->(s);
MATCH (c:Cours {code: "INFO402"}), (s:Competence {nom: "Python"}) MERGE (c)-[:REQUIERT]->(s);
MATCH (c:Cours {code: "INFO402"}), (s:Competence {nom: "Machine Learning"}) MERGE (c)-[:REQUIERT]->(s);
MATCH (c:Cours {code: "INFO402"}), (s:Competence {nom: "Deep Learning"}) MERGE (c)-[:REQUIERT]->(s);
MATCH (c:Cours {code: "INFO403"}), (s:Competence {nom: "React"}) MERGE (c)-[:REQUIERT]->(s);
MATCH (c:Cours {code: "INFO404"}), (s:Competence {nom: "Docker"}) MERGE (c)-[:REQUIERT]->(s);
MATCH (c:Cours {code: "INFO404"}), (s:Competence {nom: "Linux"}) MERGE (c)-[:REQUIERT]->(s);
MATCH (c:Cours {code: "TELEC401"}), (s:Competence {nom: "Réseaux"}) MERGE (c)-[:REQUIERT]->(s);
MATCH (c:Cours {code: "SEC401"}), (s:Competence {nom: "Cybersécurité"}) MERGE (c)-[:REQUIERT]->(s);
MATCH (c:Cours {code: "SEC401"}), (s:Competence {nom: "Linux"}) MERGE (c)-[:REQUIERT]->(s);

// ─── 1.4 : Créer les clubs ────────────────────────────────────────────────────
UNWIND [
  {nom: "Club IA USTHB", universite: "USTHB", domaine: "Intelligence Artificielle"},
  {nom: "Club Cyber USTHB", universite: "USTHB", domaine: "Cybersécurité"},
  {nom: "Club Dev UMBB", universite: "UMBB", domaine: "Développement Web"},
  {nom: "Club Robotique USTO", universite: "USTO", domaine: "Robotique"},
  {nom: "Club Open Source UMC", universite: "UMC", domaine: "Logiciel Libre"},
  {nom: "Club Telecom UBMA", universite: "UBMA", domaine: "Télécommunications"},
  {nom: "Club Math UMBB", universite: "UMBB", domaine: "Mathématiques Appliquées"},
  {nom: "Club Startup USTHB", universite: "USTHB", domaine: "Entrepreneuriat"}
] AS club
MERGE (:Club {nom: club.nom, universite: club.universite, domaine: club.domaine});

// ─── Entreprises ──────────────────────────────────────────────────────────────
UNWIND [
  {nom: "Sonatrach", secteur: "Énergie", ville: "Alger"},
  {nom: "Algérie Télécom", secteur: "Télécoms", ville: "Alger"},
  {nom: "Djezzy", secteur: "Télécoms", ville: "Alger"},
  {nom: "ICOSNET", secteur: "Cybersécurité", ville: "Alger"},
  {nom: "Condor Electronics", secteur: "Électronique", ville: "Bordj Bou Arréridj"},
  {nom: "Cevital", secteur: "Agroalimentaire", ville: "Bejaia"}
] AS ent
MERGE (:Entreprise {nom: ent.nom, secteur: ent.secteur, ville: ent.ville});

// ─── 1.5 : Créer les 50 étudiants ────────────────────────────────────────────
UNWIND [
  {id:"E001",prenom:"Ahmed",nom:"Bensalem",universite:"USTHB",filiere:"Informatique",annee:3,ville:"Alger"},
  {id:"E002",prenom:"Fatima",nom:"Ouali",universite:"USTHB",filiere:"Informatique",annee:3,ville:"Alger"},
  {id:"E003",prenom:"Karim",nom:"Meziane",universite:"UMBB",filiere:"Informatique",annee:2,ville:"Boumerdes"},
  {id:"E004",prenom:"Yasmina",nom:"Hamdi",universite:"USTO",filiere:"Informatique",annee:4,ville:"Oran"},
  {id:"E005",prenom:"Rania",nom:"Belkacem",universite:"UMC",filiere:"GL",annee:3,ville:"Constantine"},
  {id:"E006",prenom:"Mehdi",nom:"Derbal",universite:"USTHB",filiere:"Electronique",annee:2,ville:"Alger"},
  {id:"E007",prenom:"Sara",nom:"Amrani",universite:"UBMA",filiere:"Telecoms",annee:3,ville:"Annaba"},
  {id:"E008",prenom:"Youcef",nom:"Cherif",universite:"UMBB",filiere:"Mathematiques",annee:4,ville:"Boumerdes"},
  {id:"E009",prenom:"Lina",nom:"Boudia",universite:"USTHB",filiere:"Informatique",annee:1,ville:"Alger"},
  {id:"E010",prenom:"Anis",nom:"Haddar",universite:"USTO",filiere:"GL",annee:3,ville:"Oran"},
  {id:"E011",prenom:"Nour",nom:"Khelifi",universite:"USTHB",filiere:"Informatique",annee:4,ville:"Alger"},
  {id:"E012",prenom:"Amine",nom:"Tebbal",universite:"UMBB",filiere:"GL",annee:2,ville:"Boumerdes"},
  {id:"E013",prenom:"Dalia",nom:"Sadaoui",universite:"UMC",filiere:"Informatique",annee:3,ville:"Constantine"},
  {id:"E014",prenom:"Ilyes",nom:"Bouchama",universite:"USTO",filiere:"Electronique",annee:4,ville:"Oran"},
  {id:"E015",prenom:"Meriem",nom:"Ferroudj",universite:"UBMA",filiere:"Telecoms",annee:2,ville:"Annaba"},
  {id:"E016",prenom:"Rachid",nom:"Hadjadj",universite:"USTHB",filiere:"Informatique",annee:2,ville:"Alger"},
  {id:"E017",prenom:"Souad",nom:"Morsli",universite:"UMBB",filiere:"Mathematiques",annee:3,ville:"Boumerdes"},
  {id:"E018",prenom:"Billal",nom:"Benali",universite:"UMC",filiere:"Telecoms",annee:1,ville:"Constantine"},
  {id:"E019",prenom:"Houda",nom:"Chekroun",universite:"USTHB",filiere:"Informatique",annee:4,ville:"Alger"},
  {id:"E020",prenom:"Sofiane",nom:"Larbi",universite:"USTO",filiere:"GL",annee:2,ville:"Oran"},
  {id:"E021",prenom:"Assia",nom:"Touati",universite:"UBMA",filiere:"Informatique",annee:3,ville:"Annaba"},
  {id:"E022",prenom:"Ziad",nom:"Mansouri",universite:"USTHB",filiere:"Electronique",annee:3,ville:"Alger"},
  {id:"E023",prenom:"Nesrine",nom:"Boukhalfa",universite:"UMBB",filiere:"Informatique",annee:2,ville:"Boumerdes"},
  {id:"E024",prenom:"Walid",nom:"Guerrouf",universite:"UMC",filiere:"Informatique",annee:4,ville:"Constantine"},
  {id:"E025",prenom:"Imane",nom:"Salhi",universite:"USTO",filiere:"Telecoms",annee:3,ville:"Oran"},
  {id:"E026",prenom:"Ryad",nom:"Benkheira",universite:"USTHB",filiere:"GL",annee:1,ville:"Alger"},
  {id:"E027",prenom:"Chaima",nom:"Ould Said",universite:"UBMA",filiere:"Informatique",annee:4,ville:"Annaba"},
  {id:"E028",prenom:"Hichem",nom:"Zerrouki",universite:"UMBB",filiere:"Electronique",annee:2,ville:"Boumerdes"},
  {id:"E029",prenom:"Samira",nom:"Djebbar",universite:"UMC",filiere:"GL",annee:3,ville:"Constantine"},
  {id:"E030",prenom:"Oussama",nom:"Khaldi",universite:"USTO",filiere:"Informatique",annee:2,ville:"Oran"},
  {id:"E031",prenom:"Lynda",nom:"Aouadi",universite:"USTHB",filiere:"Mathematiques",annee:3,ville:"Alger"},
  {id:"E032",prenom:"Redouane",nom:"Benamara",universite:"UMBB",filiere:"Informatique",annee:4,ville:"Boumerdes"},
  {id:"E033",prenom:"Wafa",nom:"Tahir",universite:"UMC",filiere:"Electronique",annee:1,ville:"Constantine"},
  {id:"E034",prenom:"Marwane",nom:"Benbrahim",universite:"USTO",filiere:"Informatique",annee:3,ville:"Oran"},
  {id:"E035",prenom:"Fatma",nom:"Azzedine",universite:"UBMA",filiere:"GL",annee:2,ville:"Annaba"},
  {id:"E036",prenom:"Mehdi",nom:"Ferhat",universite:"USTHB",filiere:"Telecoms",annee:4,ville:"Alger"},
  {id:"E037",prenom:"Nawel",nom:"Arabi",universite:"UMBB",filiere:"GL",annee:3,ville:"Boumerdes"},
  {id:"E038",prenom:"Adem",nom:"Boughezala",universite:"UMC",filiere:"Informatique",annee:2,ville:"Constantine"},
  {id:"E039",prenom:"Siham",nom:"Mesbah",universite:"USTO",filiere:"Mathematiques",annee:4,ville:"Oran"},
  {id:"E040",prenom:"Nassim",nom:"Laib",universite:"UBMA",filiere:"Informatique",annee:1,ville:"Annaba"},
  {id:"E041",prenom:"Rym",nom:"Brahimi",universite:"USTHB",filiere:"GL",annee:3,ville:"Alger"},
  {id:"E042",prenom:"Fares",nom:"Moumene",universite:"UMBB",filiere:"Informatique",annee:2,ville:"Boumerdes"},
  {id:"E043",prenom:"Yasmine",nom:"Otmane",universite:"UMC",filiere:"Telecoms",annee:4,ville:"Constantine"},
  {id:"E044",prenom:"Lotfi",nom:"Bendjebbar",universite:"USTO",filiere:"Informatique",annee:3,ville:"Oran"},
  {id:"E045",prenom:"Amina",nom:"Guechi",universite:"UBMA",filiere:"Electronique",annee:2,ville:"Annaba"},
  {id:"E046",prenom:"Salim",nom:"Mihoubi",universite:"USTHB",filiere:"Informatique",annee:4,ville:"Alger"},
  {id:"E047",prenom:"Karima",nom:"Yousfi",universite:"UMBB",filiere:"Informatique",annee:1,ville:"Boumerdes"},
  {id:"E048",prenom:"Mohamed",nom:"Senouci",universite:"UMC",filiere:"GL",annee:3,ville:"Constantine"},
  {id:"E049",prenom:"Lylia",nom:"Rahmani",universite:"USTO",filiere:"Informatique",annee:2,ville:"Oran"},
  {id:"E050",prenom:"Ayoub",nom:"Benhadj",universite:"UBMA",filiere:"Informatique",annee:4,ville:"Annaba"}
] AS data
MERGE (e:Etudiant {id: data.id})
SET e += data;

// ─── 1.6 : Relations CONNAIT ──────────────────────────────────────────────────
// Réseau connexe : chaque étudiant a au moins une connexion
UNWIND [
  {a:"E001",b:"E002",depuis:2022,contexte:"Classe"},
  {a:"E001",b:"E009",depuis:2023,contexte:"Projet"},
  {a:"E001",b:"E016",depuis:2022,contexte:"Club"},
  {a:"E001",b:"E019",depuis:2021,contexte:"Classe"},
  {a:"E002",b:"E009",depuis:2023,contexte:"Classe"},
  {a:"E002",b:"E006",depuis:2022,contexte:"Événement"},
  {a:"E003",b:"E008",depuis:2022,contexte:"Classe"},
  {a:"E003",b:"E012",depuis:2023,contexte:"Club"},
  {a:"E003",b:"E023",depuis:2022,contexte:"Classe"},
  {a:"E004",b:"E010",depuis:2021,contexte:"Classe"},
  {a:"E004",b:"E014",depuis:2022,contexte:"Projet"},
  {a:"E004",b:"E025",depuis:2023,contexte:"Événement"},
  {a:"E005",b:"E013",depuis:2022,contexte:"Classe"},
  {a:"E005",b:"E029",depuis:2023,contexte:"Club"},
  {a:"E005",b:"E024",depuis:2021,contexte:"Classe"},
  {a:"E006",b:"E022",depuis:2022,contexte:"Classe"},
  {a:"E006",b:"E028",depuis:2023,contexte:"Hackathon"},
  {a:"E007",b:"E015",depuis:2021,contexte:"Classe"},
  {a:"E007",b:"E021",depuis:2022,contexte:"Club"},
  {a:"E008",b:"E017",depuis:2022,contexte:"Classe"},
  {a:"E008",b:"E031",depuis:2023,contexte:"Séminaire"},
  {a:"E009",b:"E026",depuis:2023,contexte:"Projet"},
  {a:"E010",b:"E020",depuis:2022,contexte:"Classe"},
  {a:"E010",b:"E030",depuis:2023,contexte:"Projet"},
  {a:"E011",b:"E001",depuis:2020,contexte:"Classe"},
  {a:"E011",b:"E019",depuis:2021,contexte:"Club"},
  {a:"E012",b:"E037",depuis:2023,contexte:"Classe"},
  {a:"E013",b:"E038",depuis:2022,contexte:"Classe"},
  {a:"E014",b:"E033",depuis:2022,contexte:"Classe"},
  {a:"E015",b:"E035",depuis:2022,contexte:"Classe"},
  {a:"E016",b:"E041",depuis:2023,contexte:"Club"},
  {a:"E017",b:"E039",depuis:2022,contexte:"Classe"},
  {a:"E018",b:"E043",depuis:2022,contexte:"Classe"},
  {a:"E019",b:"E046",depuis:2020,contexte:"Classe"},
  {a:"E020",b:"E034",depuis:2022,contexte:"Classe"},
  {a:"E020",b:"E044",depuis:2023,contexte:"Projet"},
  {a:"E021",b:"E027",depuis:2021,contexte:"Classe"},
  {a:"E022",b:"E006",depuis:2023,contexte:"Projet"},
  {a:"E023",b:"E042",depuis:2023,contexte:"Classe"},
  {a:"E024",b:"E048",depuis:2022,contexte:"Club"},
  {a:"E025",b:"E049",depuis:2022,contexte:"Classe"},
  {a:"E026",b:"E036",depuis:2023,contexte:"Club"},
  {a:"E027",b:"E040",depuis:2022,contexte:"Classe"},
  {a:"E028",b:"E045",depuis:2023,contexte:"Classe"},
  {a:"E029",b:"E048",depuis:2022,contexte:"Classe"},
  {a:"E030",b:"E049",depuis:2023,contexte:"Projet"},
  {a:"E031",b:"E017",depuis:2023,contexte:"Club"},
  {a:"E032",b:"E003",depuis:2021,contexte:"Classe"},
  {a:"E033",b:"E018",depuis:2023,contexte:"Événement"},
  {a:"E034",b:"E044",depuis:2022,contexte:"Classe"},
  {a:"E035",b:"E050",depuis:2022,contexte:"Projet"},
  {a:"E036",b:"E002",depuis:2023,contexte:"Hackathon"},
  {a:"E037",b:"E047",depuis:2022,contexte:"Classe"},
  {a:"E038",b:"E005",depuis:2023,contexte:"Club"},
  {a:"E039",b:"E008",depuis:2021,contexte:"Séminaire"},
  {a:"E040",b:"E050",depuis:2023,contexte:"Classe"},
  {a:"E041",b:"E016",depuis:2022,contexte:"Projet"},
  {a:"E042",b:"E047",depuis:2023,contexte:"Classe"},
  {a:"E043",b:"E048",depuis:2021,contexte:"Classe"},
  {a:"E044",b:"E004",depuis:2022,contexte:"Événement"},
  {a:"E045",b:"E007",depuis:2023,contexte:"Club"},
  {a:"E046",b:"E011",depuis:2021,contexte:"Classe"},
  {a:"E047",b:"E023",depuis:2022,contexte:"Projet"},
  {a:"E048",b:"E043",depuis:2022,contexte:"Classe"},
  {a:"E049",b:"E025",depuis:2022,contexte:"Classe"},
  {a:"E050",b:"E027",depuis:2021,contexte:"Club"}
] AS rel
MATCH (a:Etudiant {id: rel.a}), (b:Etudiant {id: rel.b})
MERGE (a)-[:CONNAIT {depuis: rel.depuis, contexte: rel.contexte}]->(b)
MERGE (b)-[:CONNAIT {depuis: rel.depuis, contexte: rel.contexte}]->(a);

// ─── 1.7 : Relations SUIT (étudiant → cours) avec notes ──────────────────────
UNWIND [
  {e:"E001",c:"INFO401",sem:"S5",note:15.5},{e:"E001",c:"INFO402",sem:"S5",note:14.0},
  {e:"E001",c:"SEC401",sem:"S5",note:16.0},
  {e:"E002",c:"INFO401",sem:"S5",note:17.0},{e:"E002",c:"INFO403",sem:"S5",note:13.5},
  {e:"E003",c:"INFO401",sem:"S3",note:12.0},{e:"E003",c:"INFO301",sem:"S3",note:14.5},
  {e:"E004",c:"INFO401",sem:"S7",note:18.5},{e:"E004",c:"INFO402",sem:"S7",note:16.0},
  {e:"E004",c:"INFO404",sem:"S7",note:15.0},
  {e:"E005",c:"INFO401",sem:"S5",note:14.0},{e:"E005",c:"INFO403",sem:"S5",note:15.5},
  {e:"E006",c:"ELEC401",sem:"S3",note:13.0},{e:"E006",c:"MATH401",sem:"S3",note:15.0},
  {e:"E007",c:"TELEC401",sem:"S5",note:16.5},{e:"E007",c:"SEC401",sem:"S5",note:14.0},
  {e:"E008",c:"MATH401",sem:"S7",note:17.5},{e:"E008",c:"INFO301",sem:"S7",note:16.0},
  {e:"E009",c:"INFO301",sem:"S1",note:13.0},{e:"E009",c:"INFO401",sem:"S1",note:11.5},
  {e:"E010",c:"INFO401",sem:"S5",note:14.5},{e:"E010",c:"INFO403",sem:"S5",note:15.0},
  {e:"E011",c:"INFO402",sem:"S7",note:18.0},{e:"E011",c:"INFO404",sem:"S7",note:17.0},
  {e:"E011",c:"INFO405",sem:"S7",note:16.5},
  {e:"E019",c:"INFO402",sem:"S7",note:19.0},{e:"E019",c:"INFO404",sem:"S7",note:17.5},
  {e:"E019",c:"INFO405",sem:"S7",note:18.0},
  {e:"E022",c:"ELEC401",sem:"S5",note:15.0},{e:"E022",c:"MATH401",sem:"S5",note:14.5},
  {e:"E031",c:"MATH401",sem:"S5",note:18.5},{e:"E031",c:"INFO301",sem:"S5",note:17.0},
  {e:"E036",c:"TELEC401",sem:"S7",note:16.0},{e:"E036",c:"SEC401",sem:"S7",note:15.5},
  {e:"E046",c:"INFO402",sem:"S7",note:17.0},{e:"E046",c:"INFO401",sem:"S7",note:16.5},
  {e:"E046",c:"INFO404",sem:"S7",note:15.0}
] AS rel
MATCH (e:Etudiant {id: rel.e}), (c:Cours {code: rel.c})
MERGE (e)-[:SUIT {semestre: rel.sem, note: rel.note}]->(c);

// ─── 1.8 : Relations MAITRISE ─────────────────────────────────────────────────
UNWIND [
  {e:"E001",s:"Python",niveau:"Intermédiaire"},{e:"E001",s:"SQL",niveau:"Avancé"},
  {e:"E001",s:"Linux",niveau:"Intermédiaire"},{e:"E001",s:"NoSQL",niveau:"Débutant"},
  {e:"E002",s:"Python",niveau:"Avancé"},{e:"E002",s:"SQL",niveau:"Avancé"},
  {e:"E002",s:"React",niveau:"Intermédiaire"},
  {e:"E003",s:"Java",niveau:"Intermédiaire"},{e:"E003",s:"SQL",niveau:"Intermédiaire"},
  {e:"E004",s:"Python",niveau:"Expert"},{e:"E004",s:"Machine Learning",niveau:"Avancé"},
  {e:"E004",s:"SQL",niveau:"Avancé"},{e:"E004",s:"NoSQL",niveau:"Avancé"},
  {e:"E005",s:"Python",niveau:"Intermédiaire"},{e:"E005",s:"React",niveau:"Avancé"},
  {e:"E006",s:"C++",niveau:"Avancé"},{e:"E006",s:"Matlab",niveau:"Intermédiaire"},
  {e:"E007",s:"Réseaux",niveau:"Avancé"},{e:"E007",s:"Linux",niveau:"Intermédiaire"},
  {e:"E007",s:"Cybersécurité",niveau:"Intermédiaire"},
  {e:"E008",s:"Matlab",niveau:"Expert"},{e:"E008",s:"Python",niveau:"Avancé"},
  {e:"E011",s:"Python",niveau:"Expert"},{e:"E011",s:"Machine Learning",niveau:"Expert"},
  {e:"E011",s:"Deep Learning",niveau:"Avancé"},{e:"E011",s:"Docker",niveau:"Intermédiaire"},
  {e:"E019",s:"Python",niveau:"Expert"},{e:"E019",s:"Machine Learning",niveau:"Expert"},
  {e:"E019",s:"Deep Learning",niveau:"Expert"},{e:"E019",s:"SQL",niveau:"Avancé"},
  {e:"E036",s:"Réseaux",niveau:"Expert"},{e:"E036",s:"Cybersécurité",niveau:"Avancé"},
  {e:"E046",s:"Python",niveau:"Avancé"},{e:"E046",s:"NoSQL",niveau:"Intermédiaire"},
  {e:"E046",s:"Docker",niveau:"Avancé"},{e:"E046",s:"Linux",niveau:"Avancé"}
] AS rel
MATCH (e:Etudiant {id: rel.e}), (s:Competence {nom: rel.s})
MERGE (e)-[:MAITRISE {niveau: rel.niveau}]->(s);

// ─── 1.9 : Relations MEMBRE_DE ────────────────────────────────────────────────
UNWIND [
  {e:"E001",c:"Club IA USTHB",role:"Membre"},{e:"E001",c:"Club Cyber USTHB",role:"Membre"},
  {e:"E002",c:"Club IA USTHB",role:"Présidente"},{e:"E009",c:"Club IA USTHB",role:"Membre"},
  {e:"E011",c:"Club IA USTHB",role:"Vice-Président"},{e:"E019",c:"Club IA USTHB",role:"Membre"},
  {e:"E016",c:"Club Cyber USTHB",role:"Président"},{e:"E046",c:"Club Cyber USTHB",role:"Membre"},
  {e:"E003",c:"Club Dev UMBB",role:"Membre"},{e:"E012",c:"Club Dev UMBB",role:"Président"},
  {e:"E023",c:"Club Dev UMBB",role:"Membre"},{e:"E032",c:"Club Dev UMBB",role:"Membre"},
  {e:"E004",c:"Club Robotique USTO",role:"Présidente"},{e:"E014",c:"Club Robotique USTO",role:"Membre"},
  {e:"E005",c:"Club Open Source UMC",role:"Membre"},{e:"E024",c:"Club Open Source UMC",role:"Président"},
  {e:"E007",c:"Club Telecom UBMA",role:"Présidente"},{e:"E015",c:"Club Telecom UBMA",role:"Membre"},
  {e:"E008",c:"Club Math UMBB",role:"Président"},{e:"E017",c:"Club Math UMBB",role:"Membre"},
  {e:"E026",c:"Club Startup USTHB",role:"Membre"},{e:"E036",c:"Club Startup USTHB",role:"Président"}
] AS rel
MATCH (e:Etudiant {id: rel.e}), (c:Club {nom: rel.c})
MERGE (e)-[:MEMBRE_DE {role: rel.role}]->(c);

// ─── 1.10 : Relations A_STAGE_CHEZ ───────────────────────────────────────────
UNWIND [
  {e:"E011",ent:"ICOSNET",annee:2024,duree:2},
  {e:"E007",ent:"ICOSNET",annee:2024,duree:1},
  {e:"E004",ent:"Djezzy",annee:2023,duree:3},
  {e:"E019",ent:"Sonatrach",annee:2024,duree:2},
  {e:"E036",ent:"Algérie Télécom",annee:2023,duree:3},
  {e:"E046",ent:"ICOSNET",annee:2024,duree:2},
  {e:"E024",ent:"Cevital",annee:2023,duree:2},
  {e:"E005",ent:"Condor Electronics",annee:2024,duree:1}
] AS rel
MATCH (e:Etudiant {id: rel.e}), (ent:Entreprise {nom: rel.ent})
MERGE (e)-[:A_STAGE_CHEZ {annee: rel.annee, duree_mois: rel.duree}]->(ent);

// ─── 1.11 : Import depuis CSV ─────────────────────────────────────────────────
// (Complète les étudiants déjà dans le CSV fourni — MERGE évite les doublons)
LOAD CSV WITH HEADERS FROM 'file:///students.csv' AS row
MERGE (e:Etudiant { id: row.id })
SET e.prenom = row.prenom,
    e.nom = row.nom,
    e.universite = row.universite,
    e.filiere = row.filiere,
    e.annee = toInteger(row.annee),
    e.ville = row.ville;

// ─── Vérification ─────────────────────────────────────────────────────────────
MATCH (n) RETURN labels(n)[0] AS type, count(n) AS total ORDER BY total DESC;
MATCH ()-[r]->() RETURN type(r) AS relation, count(r) AS total ORDER BY total DESC;
