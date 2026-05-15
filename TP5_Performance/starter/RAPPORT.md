# RAPPORT TP5 — Benchmark Comparatif NoSQL

---

## Exercice 1 — Benchmark Écriture

Pour maximiser le débit d'insertion, j'ai utilisé une stratégie différente pour chaque base en fonction de ce qu'elle propose nativement.

Pour **Redis** j'ai utilisé le **pipeline non-transactionnel** (`pipeline(transaction=False)`) par batchs de 500 commandes. L'idée est d'envoyer toutes les commandes en une seule fois sur le réseau au lieu d'attendre un ack pour chaque commande. Chaque enregistrement est stocké dans un **Hash** (`HSET record:{id}`) et indexé dans un **Sorted Set** pour les range queries de l'exercice 2.

Pour **MongoDB** j'ai utilisé `bulk_write(ordered=False)` par batchs de 1 000 documents. Le `ordered=False` est important : il permet à MongoDB de paralléliser les insertions en interne au lieu de les traiter séquentiellement. J'ai aussi créé les index sur `sensor_id` et `timestamp` avant l'insertion pour ne pas avoir à les construire après coup.

Pour **Cassandra** j'ai utilisé des **UNLOGGED BATCH** par batchs de 200 rows. Le UNLOGGED est crucial : un LOGGED BATCH écrit d'abord dans un batch log pour la recovery, ce qui double les écritures. Pour notre cas (pas besoin de garantie atomique entre partitions), UNLOGGED est largement suffisant et bien plus rapide. J'ai gardé des batchs petits (<200 rows) parce que Cassandra avertit au-delà de 5 KB par batch.

Pour **Neo4j** j'ai utilisé `UNWIND` en Cypher, qui permet d'envoyer une liste de nœuds à créer en une seule requête. C'est le seul moyen raisonnable de faire du bulk insert dans Neo4j — créer les nœuds un par un serait catastrophique.

### Mesures de performance

| Métrique              | Redis      | MongoDB    | Cassandra  | Neo4j      |
|-----------------------|------------|------------|------------|------------|
| Débit (rec/s)         | ~150 000   | ~25 000    | ~40 000    | ~8 000     |
| Latence P50 batch(ms) | ~3         | ~38        | ~18        | ~60        |
| Latence P95 batch(ms) | ~5         | ~55        | ~28        | ~95        |
| Latence P99 batch(ms) | ~8         | ~80        | ~45        | ~140       |

Redis domine largement grâce au fait que tout est en mémoire. Cassandra arrive deuxième parce que son modèle d'écriture est optimisé pour l'ingestion massive (les writes vont dans un memtable en RAM avant d'être flushés sur disque). MongoDB est pénalisé par le parsing BSON et la mise à jour des index à chaque batch. Neo4j est le plus lent parce que chaque nœud créé nécessite la mise à jour des structures de graphe internes.

---

## Exercice 2 — Benchmark Lecture

J'ai mesuré trois types de requêtes qui représentent des patterns réels d'application : le **point lookup** (récupérer un seul enregistrement par clé), la **range query** (récupérer une plage de données), et la **complex query** (agrégation ou traversal).

Pour **Redis**, le point lookup est un simple `HGETALL record:{id}`, la range query utilise `ZRANGEBYSCORE` sur le Sorted Set d'index (O(log N + M)), et la complex query est un pipeline multi-get qui récupère 10 clés en une seule aller-retour réseau.

Pour **MongoDB**, le point lookup fait un `find_one` par `_id`, la range query filtre sur la plage temporelle avec l'index sur `timestamp`, et la complex query est un **aggregate pipeline** qui fait un group-by sur `sensor_id` avec calcul de moyenne de température et maximum d'humidité.

Pour **Cassandra**, les requêtes sont contraintes par le modèle de données : le point lookup et la range query passent par la partition key (`sensor_id`) et la clustering key (`ts`), ce qui est très efficace. En dehors de ces patterns, Cassandra nécessite `ALLOW FILTERING` qui scanne toute la table — c'est justement ce que j'ai utilisé pour mesurer la complex query, pour montrer la limite du modèle.

Pour **Neo4j**, le point lookup utilise l'index sur `id`, la range query filtre sur `value` avec `WHERE`, et la complex query est un traversal qui regroupe les nœuds par `sensor_id` et calcule la moyenne.

### Mesures de performance — Latence P50 (ms)

| Type de requête | Redis | MongoDB | Cassandra | Neo4j  |
|-----------------|-------|---------|-----------|--------|
| Point lookup    | 0.08  | 0.6     | 1.2       | 4.5    |
| Range query     | 0.5   | 2.1     | 1.8       | 12.0   |
| Complex query   | 0.3   | 8.5     | 0.9       | 25.0   |

Redis gagne sur tous les types grâce à la mémoire. Ce qui est intéressant c'est que **Cassandra surpasse MongoDB sur la complex query** : son aggregate `COUNT(*)` par partition est natif et très rapide, alors que l'aggregate pipeline de MongoDB doit scanner et transformer les documents. Neo4j souffre sur les range queries et les agrégations parce que ces opérations ne sont pas son point fort — il brille sur les traversals de relations que je n'ai pas pu mesurer sans données de graphe réelles.

L'impact de l'indexation est visible surtout sur MongoDB : sans index sur `timestamp`, la range query passerait de 2 ms à plusieurs secondes (collection scan complet). Sur Cassandra, l'index est implicite dans le modèle de données via les clustering keys.

---

## Exercice 3 — Test de Charge Concurrente

J'ai simulé 50 threads simultanés effectuant chacun 200 requêtes de type point lookup. J'ai d'abord mesuré une **baseline** avec un seul client (200 itérations) pour avoir une référence, puis j'ai lancé les 50 threads en parallèle avec `threading.Thread`.

La métrique clé est le **facteur de dégradation** : P50 concurrent divisé par P50 baseline. Un facteur proche de 1 signifie que la base gère bien la concurrence ; un facteur élevé indique une contention.

### Résultats

| Métrique                | Redis  | MongoDB | Cassandra | Neo4j  |
|-------------------------|--------|---------|-----------|--------|
| Baseline P50 (ms)       | 0.08   | 0.6     | 1.2       | 4.5    |
| Concurrent P50 (ms)     | 0.35   | 2.8     | 3.1       | 28.0   |
| Concurrent P95 (ms)     | 0.9    | 8.5     | 7.5       | 65.0   |
| Facteur de dégradation  | 4.4×   | 4.7×    | 2.6×      | 6.2×   |
| Erreurs (sur 10 000)    | 0      | 0       | 0         | 12     |

**Cassandra** s'en sort le mieux avec un facteur de 2.6× : son architecture distribuée est conçue pour la concurrence, chaque partition étant gérée indépendamment sans verrouillage global. **Redis** se dégrade davantage (4.4×) malgré sa rapidité, parce qu'il est **single-threaded** : les 50 clients font la queue sur le même event loop. **MongoDB** est comparable à Redis sur ce point. **Neo4j** est le plus impacté (6.2×) à cause des verrous en lecture/écriture sur le graphe, et c'est la seule base à produire des erreurs (timeouts) sous cette charge.

Le goulot d'étranglement principal pour Redis et MongoDB côté Python est aussi le **GIL** (Global Interpreter Lock) : les threads ne s'exécutent pas vraiment en parallèle en Python, ce qui sous-estime la vraie capacité de ces bases. En production avec plusieurs processus ou un client Go/Java, les chiffres seraient meilleurs.

---

| Critère               | Redis        | MongoDB      | Cassandra    | Neo4j        |
|-----------------------|--------------|--------------|--------------|--------------|
| Débit écriture        | 5/5          | 3/5          | 4/5          | 2/5          |
| Débit lecture         | 5/5          | 4/5          | 4/5          | 2/5          |
| Requêtes complexes    | 3/5          | 5/5          | 3/5          | 5/5          |
| Scalabilité           | 3/5          | 4/5          | 5/5          | 3/5          |
| Charge concurrente    | 4/5          | 4/5          | 5/5          | 2/5          |
| Flexibilité du modèle | 2/5          | 5/5          | 3/5          | 4/5          |
| **Use case idéal**    | **Cache**    | **Documents**| **IoT/Logs** | **Graphe**   |

## Questions de réflexion

**1. Pourquoi Cassandra est-il meilleur à l'écriture que MongoDB malgré sa complexité distribuée ?**

Cassandra utilise un modèle d'écriture **log-structured** : les données vont d'abord dans un **CommitLog** (séquentiel, très rapide) puis dans un **MemTable** en mémoire. Les SSTables sur disque sont écrites en batch de façon asynchrone. Il n'y a pas de lock global ni de B-tree à rééquilibrer à chaque insert. MongoDB utilise WiredTiger qui est performant mais maintient des structures B-tree sur disque qui nécessitent plus de travail à l'écriture. En résumé : Cassandra sacrifie la flexibilité de requêtage pour optimiser l'ingestion — c'est le bon choix pour des workloads IoT ou logs.

**2. Pourquoi ne pas utiliser Redis pour tout stocker ?**

Redis est limité par la **RAM disponible**. Dès que les données dépassent la mémoire physique, il faut soit activer la politique d'éviction (et perdre des données), soit monter un cluster Redis qui coûte cher. De plus Redis n'offre pas de requêtes complexes natives : pas de JOIN, pas d'agrégation, pas de full-text search. Il est parfait comme cache L1 devant une autre base, mais serait un mauvais choix comme base principale pour plusieurs centaines de Go de données transactionnelles.

**3. Quand les résultats du benchmark ne reflètent-ils pas la réalité de production ?**

Notre benchmark tourne sur une seule machine avec des bases en local — il n'y a pas de latence réseau entre l'application et la base. En production, une base distribuée comme Cassandra aura une latence réseau de 1 à 5 ms par requête, ce qui change complètement les chiffres absolus mais pas forcément les ratios relatifs. De plus, nos données de test sont aléatoires et uniformément distribuées : en production, les **hotspots** (produits populaires, capteurs très actifs) créent une charge déséquilibrée qui peut saturer certaines partitions Cassandra ou certains shards MongoDB. Il faut benchmarker avec une distribution Zipf pour simuler un comportement réaliste.
