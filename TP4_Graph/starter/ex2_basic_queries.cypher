// TP4 - Exercice 2 : Requêtes de Base Cypher
// Use Case : UniConnect DZ — Réseau Social Universitaire

// ─── 2.1 : Trouver tous les amis d'Ahmed (1 saut) ────────────────────────────
MATCH (moi:Etudiant {prenom: "Ahmed"})-[:CONNAIT]-(ami:Etudiant)
RETURN ami.prenom AS prenom,
       ami.nom AS nom,
       ami.universite AS universite,
       ami.filiere AS filiere;


// ─── 2.2 : Amis d'amis d'Ahmed qui ne sont pas encore ses amis ───────────────
MATCH (moi:Etudiant {prenom: "Ahmed"})-[:CONNAIT]-(ami:Etudiant)-[:CONNAIT]-(suggestion:Etudiant)
WHERE suggestion <> moi
  AND NOT (moi)-[:CONNAIT]-(suggestion)
RETURN DISTINCT suggestion.prenom AS prenom,
       suggestion.universite AS universite,
       suggestion.filiere AS filiere
LIMIT 10;


// ─── 2.3 : Étudiants qui suivent le même cours que Fatima sans la connaître ──
MATCH (fatima:Etudiant {prenom: "Fatima"})-[:SUIT]->(cours:Cours)<-[:SUIT]-(autre:Etudiant)
WHERE autre <> fatima
  AND NOT (fatima)-[:CONNAIT]-(autre)
RETURN DISTINCT autre.prenom AS prenom,
       autre.universite AS universite,
       cours.intitule AS cours_en_commun;


// ─── 2.4 : Clubs les plus populaires (par nombre de membres) ─────────────────
MATCH (e:Etudiant)-[:MEMBRE_DE]->(club:Club)
RETURN club.nom AS club,
       club.universite AS universite,
       club.domaine AS domaine,
       count(e) AS nb_membres
ORDER BY nb_membres DESC
LIMIT 10;


// ─── 2.5 : Profil complet d'un étudiant ──────────────────────────────────────
// Amis, cours suivis (avec notes), compétences maîtrisées, clubs

MATCH (e:Etudiant {prenom: "Ahmed"})

// Amis
OPTIONAL MATCH (e)-[:CONNAIT]-(ami:Etudiant)

// Cours
OPTIONAL MATCH (e)-[s:SUIT]->(cours:Cours)

// Compétences
OPTIONAL MATCH (e)-[m:MAITRISE]->(comp:Competence)

// Clubs
OPTIONAL MATCH (e)-[mb:MEMBRE_DE]->(club:Club)

RETURN e.prenom + " " + e.nom AS etudiant,
       e.universite AS universite,
       e.filiere AS filiere,
       collect(DISTINCT ami.prenom) AS amis,
       collect(DISTINCT cours.intitule + " (" + toString(s.note) + "/20)") AS cours,
       collect(DISTINCT comp.nom + " [" + m.niveau + "]") AS competences,
       collect(DISTINCT club.nom + " (" + mb.role + ")") AS clubs;
