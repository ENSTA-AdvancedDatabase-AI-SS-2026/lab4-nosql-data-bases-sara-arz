# Grille d'Évaluation — Chapitre 4 NoSQL

## Barème Global : 100 points

| TP | Thème | Points |
|----|-------|--------|
| TP1 | Redis - Cache E-commerce | 20 |
| TP2 | MongoDB - Dossiers Médicaux | 25 |
| TP3 | Cassandra - IoT SmartGrid | 25 |
| TP4 | Neo4j - Réseau Social | 20 |
| TP5 | Benchmark Comparatif | 10 |
| **TOTAL** | | **100** |

---

## Critères Transversaux (appliqués à chaque TP)

### Code Quality (20% du TP)
- [ ] Code lisible avec commentaires pertinents
- [ ] Gestion des erreurs (connexion, données manquantes)
- [ ] Pas de code mort ou de TODO non traités
- [ ] Respect des conventions de nommage

### Modélisation (40% du TP)
- [ ] Choix justifiés (embedding vs referencing, partition key, etc.)
- [ ] Schéma adapté aux requêtes cibles
- [ ] Évitement des anti-patterns (hot partitions, ALLOW FILTERING, etc.)

### Requêtes (30% du TP)
- [ ] Résultats corrects
- [ ] Efficacité (usage des index, pas de full scan)
- [ ] Utilisation des fonctionnalités spécifiques au type NoSQL

### Rapport (10% du TP)
- [ ] Justifications claires
- [ ] Comparaisons avec données mesurées
- [ ] Réponses aux questions de réflexion

---

## TP1 — Redis (20 pts)

| Exercice | Critères | Max |
|----------|----------|-----|
| Ex1 - Structures | Clés correctes, Hash/List/Set bien utilisés | 4 |
| Ex2 - Sessions | TTL correct, sliding expiration fonctionnelle | 4 |
| Ex3 - Cache-Aside | Pattern correct, mesure latence | 5 |
| Ex4 - Leaderboard | Sorted Set, rang 1-based, classement correct | 4 |
| Ex5 - Pipeline | Batch correct, transaction MULTI/EXEC | 3 |

**Bonus (+2)** : Rate-limiting avec Redis (INCR + EXPIRE par clé user:IP)

---

## TP2 — MongoDB (25 pts)

| Exercice | Critères | Max |
|----------|----------|-----|
| Ex1 - Modélisation | Validator JSON Schema, 20 patients réalistes | 5 |
| Ex2 - Requêtes | 5 requêtes correctes avec projection | 5 |
| Ex3 - Agrégation | 5 pipelines corrects et optimisés | 8 |
| Ex4 - Index | Index appropriés + explain() documenté | 4 |
| Ex5 - $lookup | Join correct entre patients et analyses | 3 |

**Bonus (+3)** : Transaction multi-documents avec session

---

## TP3 — Cassandra (25 pts)

| Exercice | Critères | Max |
|----------|----------|-----|
| Ex1 - Schéma | Partition/Clustering keys corrects, TTL | 6 |
| Ex2 - Ingestion | 50K mesures insérées, débit mesuré | 5 |
| Ex3 - Requêtes | 7 requêtes CQL correctes | 7 |
| Ex4 - Compaction | TWCS configuré, maintenance justifiée | 4 |
| Rapport | Justification hot partition + ALLOW FILTERING | 3 |

**Bonus (+3)** : Materialized View pour une requête secondaire

---

## TP4 — Neo4j (20 pts)

| Exercice | Critères | Max |
|----------|----------|-----|
| Ex1 - Graphe | 50 nœuds, relations correctes, graphe connexe | 4 |
| Ex2 - Requêtes | 5 requêtes Cypher correctes | 4 |
| Ex3 - Algorithmes | shortestPath, GDS Louvain, recommandation | 6 |
| Ex4 - Avancé | 5 requêtes avancées (alumni, score Jaccard) | 6 |

**Bonus (+3)** : PageRank sur les cours les plus "importants"

---

## TP5 — Benchmark (10 pts)

| Exercice | Critères | Max |
|----------|----------|-----|
| Ex1 - Write bench | 3 bases benchmarkées avec débit réel | 3 |
| Ex2 - Read bench | Point/Range/Complex query comparés | 3 |
| Ex3 - Concurrent | Test charge 50 clients implémenté | 2 |
| Ex4 - Rapport | Tableau de décision argumenté | 2 |

---

## Pénalités

| Infraction | Pénalité |
|-----------|---------|
| Retard (par jour) | -5% |
| Code non fonctionnel sans RAPPORT.md explicatif | -50% de l'exercice |
| Plagiat avéré | 0 au TP + signalement |
| TODO non traités sans justification | -1 pt par TODO |
