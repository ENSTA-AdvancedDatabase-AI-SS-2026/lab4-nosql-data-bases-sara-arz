// TP4 - Exercice 4 : Requêtes Avancées
// Use Case : UniConnect DZ — Réseau Social Universitaire

// ─── 4.1 : Trouver un tuteur ──────────────────────────────────────────────────
// "Étudiant en Master (annee 4 ou 5) qui maîtrise Python
//  et a eu > 14/20 en BDD (INFO401)"

MATCH (tuteur:Etudiant)-[m:MAITRISE]->(comp:Competence {nom: "Python"})
MATCH (tuteur)-[s:SUIT]->(bdd:Cours {code: "INFO401"})
WHERE tuteur.annee >= 4
  AND s.note > 14
  AND (m.niveau = "Avancé" OR m.niveau = "Expert")
RETURN tuteur.prenom AS prenom,
       tuteur.nom AS nom,
       tuteur.universite AS universite,
       m.niveau AS niveau_python,
       s.note AS note_bdd
ORDER BY s.note DESC;


// ─── 4.2 : Réseau alumni dans une entreprise ─────────────────────────────────
// "Qui de mon réseau (jusqu'à 3 sauts depuis Ahmed) a fait un stage chez Sonatrach ?"

MATCH (moi:Etudiant {prenom: "Ahmed"})
MATCH p = (moi)-[:CONNAIT*1..3]-(alumni:Etudiant)-[:A_STAGE_CHEZ]->(ent:Entreprise {nom: "Sonatrach"})
RETURN DISTINCT alumni.prenom AS prenom,
       alumni.universite AS universite,
       length(p) - 1 AS distance_depuis_moi,  // -1 car la dernière relation est A_STAGE_CHEZ
       [n IN nodes(p)[0..-1] | n.prenom] AS chemin;


// ─── 4.3 : Détection de ponts (étudiants connecteurs) ────────────────────────
// Un "pont" est un étudiant qui connecte des groupes autrement déconnectés.
// Approximation sans GDS : étudiants avec des connexions dans plusieurs universités.

MATCH (e:Etudiant)-[:CONNAIT]-(voisin:Etudiant)
WITH e, collect(DISTINCT voisin.universite) AS univs_voisins
WHERE size(univs_voisins) >= 2  // Connecté à au moins 2 universités différentes
  AND e.universite <> univs_voisins[0]  // Et différent de la sienne

// Version GDS (si disponible) — betweenness centrality identifie les ponts réels :
// CALL gds.betweenness.stream('reseau_social')
// YIELD nodeId, score
// RETURN gds.util.asNode(nodeId).prenom AS pont, score
// ORDER BY score DESC LIMIT 10

RETURN e.prenom AS etudiant_pont,
       e.universite AS universite,
       size(univs_voisins) AS nb_univs_connectees,
       univs_voisins AS universites_reliees
ORDER BY nb_univs_connectees DESC;


// ─── 4.4 : Analyse temporelle — Croissance du réseau ─────────────────────────
// Nombre de nouvelles connexions créées par année

MATCH ()-[r:CONNAIT]->()
RETURN r.depuis AS annee,
       count(r) / 2 AS nouvelles_connexions  // /2 car relation bidirectionnelle
ORDER BY annee;

// Cumulatif : taille du réseau au fil des années
MATCH ()-[r:CONNAIT]->()
WITH r.depuis AS annee, count(r) / 2 AS connexions_annee
ORDER BY annee
WITH collect({annee: annee, n: connexions_annee}) AS data
UNWIND range(0, size(data) - 1) AS i
WITH data[i].annee AS annee,
     reduce(total = 0, j IN range(0, i) | total + data[j].n) AS total_cumulatif
RETURN annee, total_cumulatif AS connexions_totales;


// ─── 4.5 : Score de similarité de Jaccard ────────────────────────────────────
// "Étudiants les plus similaires à Ahmed"
// Jaccard(A, B) = |intersection| / |union|
// On combine cours, compétences et clubs.

MATCH (moi:Etudiant {prenom: "Ahmed"})

// Collecter les ensembles de moi
OPTIONAL MATCH (moi)-[:SUIT]->(c:Cours)
WITH moi, collect(c.code) AS mes_cours
OPTIONAL MATCH (moi)-[:MAITRISE]->(comp:Competence)
WITH moi, mes_cours, collect(comp.nom) AS mes_comps
OPTIONAL MATCH (moi)-[:MEMBRE_DE]->(club:Club)
WITH moi, mes_cours, mes_comps, collect(club.nom) AS mes_clubs

// Pour chaque autre étudiant
MATCH (autre:Etudiant)
WHERE autre <> moi

OPTIONAL MATCH (autre)-[:SUIT]->(c2:Cours)
WITH moi, mes_cours, mes_comps, mes_clubs, autre, collect(c2.code) AS ses_cours
OPTIONAL MATCH (autre)-[:MAITRISE]->(comp2:Competence)
WITH moi, mes_cours, mes_comps, mes_clubs, autre, ses_cours, collect(comp2.nom) AS ses_comps
OPTIONAL MATCH (autre)-[:MEMBRE_DE]->(club2:Club)
WITH moi, mes_cours, mes_comps, mes_clubs, autre, ses_cours, ses_comps,
     collect(club2.nom) AS ses_clubs

// Fusionner les ensembles (cours + compétences + clubs)
WITH autre,
     mes_cours + mes_comps + mes_clubs AS moi_set,
     ses_cours + ses_comps + ses_clubs AS autre_set

// Calculer intersection et union
WITH autre,
     [x IN moi_set WHERE x IN autre_set] AS intersection,
     apoc.coll.toSet(moi_set + autre_set) AS union_set

// Jaccard = |intersection| / |union|
WHERE size(union_set) > 0
WITH autre,
     round(toFloat(size(intersection)) / size(union_set) * 100) / 100 AS jaccard
WHERE jaccard > 0

RETURN autre.prenom AS etudiant,
       autre.universite AS universite,
       jaccard AS score_jaccard
ORDER BY jaccard DESC
LIMIT 10;

// ─── Bonus : PageRank sur les cours populaires ────────────────────────────────
// Projeter un graphe bipartite Étudiant → Cours pour PageRank

CALL gds.graph.project(
  'cours_network',
  ['Etudiant', 'Cours'],
  { SUIT: { orientation: 'NATURAL' } }
);

CALL gds.pageRank.stream('cours_network')
YIELD nodeId, score
WITH gds.util.asNode(nodeId) AS node, score
WHERE node:Cours
RETURN node.intitule AS cours,
       node.departement AS departement,
       round(score * 100) / 100 AS pagerank
ORDER BY pagerank DESC;

CALL gds.graph.drop('cours_network');
