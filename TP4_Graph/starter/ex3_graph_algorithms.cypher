// TP4 - Exercice 3 : Algorithmes de Graphe avec GDS
// Prérequis : Plugin Graph Data Science installé (inclus dans docker-compose)

// ─── 3.1 : Plus court chemin ──────────────────────────────────────────────────
// "Comment Ahmed peut-il rencontrer Yasmina ?"
MATCH p = shortestPath(
  (a:Etudiant {prenom: "Ahmed"})-[:CONNAIT*..10]-(b:Etudiant {prenom: "Yasmina"})
)
RETURN [n IN nodes(p) | n.prenom + " (" + n.universite + ")"] AS chemin,
       length(p) AS nb_intermediaires;


// ─── 3.2 : Centralité de degré ────────────────────────────────────────────────
// Créer la projection du graphe en mémoire (nécessaire pour GDS)
CALL gds.graph.project(
  'reseau_social',
  'Etudiant',
  {
    CONNAIT: { orientation: 'UNDIRECTED' }
  }
);

// Top 10 étudiants les plus connectés (centralité de degré)
CALL gds.degree.stream('reseau_social')
YIELD nodeId, score
RETURN gds.util.asNode(nodeId).prenom AS prenom,
       gds.util.asNode(nodeId).nom AS nom,
       gds.util.asNode(nodeId).universite AS universite,
       toInteger(score) AS nb_connexions
ORDER BY score DESC
LIMIT 10;


// ─── 3.3 : Détection de communautés (Louvain) ────────────────────────────────
// L'algorithme de Louvain détecte des communautés par optimisation de la
// modularité : il regroupe les nœuds qui ont plus de liens entre eux
// qu'attendu par hasard.
CALL gds.louvain.stream('reseau_social')
YIELD nodeId, communityId
WITH communityId,
     collect(gds.util.asNode(nodeId).prenom) AS membres,
     collect(gds.util.asNode(nodeId).universite) AS universites
RETURN communityId,
       size(membres) AS taille_communaute,
       membres[0..5] AS exemple_membres,
       // Université dominante dans la communauté
       universites[0] AS univ_exemple
ORDER BY taille_communaute DESC;


// ─── 3.4 : Recommandation de contacts ────────────────────────────────────────
// "Qui Ahmed devrait-il connaître ?"
// Score = amis en commun × 3 + cours en commun × 2 + même filière × 1
MATCH (moi:Etudiant {prenom: "Ahmed"})
MATCH (suggestion:Etudiant)
WHERE suggestion <> moi
  AND NOT (moi)-[:CONNAIT]-(suggestion)  // Pas déjà connectés

// Compter les amis en commun
OPTIONAL MATCH (moi)-[:CONNAIT]-(ami_commun:Etudiant)-[:CONNAIT]-(suggestion)
WITH moi, suggestion, count(DISTINCT ami_commun) AS amis_communs

// Compter les cours en commun
OPTIONAL MATCH (moi)-[:SUIT]->(cours:Cours)<-[:SUIT]-(suggestion)
WITH moi, suggestion, amis_communs, count(DISTINCT cours) AS cours_communs

// Calculer le score et vérifier la même filière
WITH suggestion,
     amis_communs,
     cours_communs,
     CASE WHEN moi.filiere = suggestion.filiere THEN 1 ELSE 0 END AS meme_filiere,
     (amis_communs * 3 + cours_communs * 2 + CASE WHEN moi.filiere = suggestion.filiere THEN 1 ELSE 0 END) AS score
WHERE score > 0  // Ne garder que les suggestions pertinentes

RETURN suggestion.prenom AS suggestion,
       suggestion.universite AS universite,
       amis_communs,
       cours_communs,
       meme_filiere,
       score
ORDER BY score DESC
LIMIT 5;


// ─── 3.5 : Chemin de compétences ─────────────────────────────────────────────
// "Quels cours mènent à Machine Learning ?"
// Via les relations COURS → REQUIERT → Compétence
MATCH path = (debut:Cours)-[:REQUIERT*1..3]->(but:Competence {nom: "Machine Learning"})
RETURN [n IN nodes(path) |
  CASE WHEN n:Cours THEN n.intitule ELSE n.nom END
] AS parcours_apprentissage,
       length(path) AS nb_etapes
ORDER BY nb_etapes;

// Version alternative : trouver les étudiants qui maîtrisent ML
// et les cours qu'ils ont suivis comme chemin d'apprentissage
MATCH (e:Etudiant)-[:MAITRISE]->(comp:Competence {nom: "Machine Learning"})
MATCH (e)-[s:SUIT]->(cours:Cours)
RETURN e.prenom AS etudiant,
       collect(cours.intitule + " (" + toString(s.note) + "/20)") AS cours_suivis,
       "Machine Learning" AS competence_acquise
ORDER BY e.prenom;


// ─── Nettoyage de la projection en mémoire ───────────────────────────────────
CALL gds.graph.drop('reseau_social');
