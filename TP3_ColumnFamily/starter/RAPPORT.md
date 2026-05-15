# RAPPORT TP3 — Cassandra IoT SmartGrid DZ

---

## 1. Justification des Partition Keys

### mesures_par_capteur — `(capteur_id, date_jour)`

Pour cette table j'ai choisi une partition key composite qui combine l'identifiant du capteur et un bucket par jour. Sans le bucket `date_jour`, chaque capteur accumulerait 1 440 lignes par jour dans une seule partition, soit 129 600 lignes après 90 jours. Cassandra charge la partition entière en mémoire lors d'une lecture, donc une partition non bornée provoque une pression mémoire sur le nœud propriétaire et des timeouts sur les requêtes de plage temporelle. Avec `(capteur_id, date_jour)` chaque partition est bornée à 1 440 lignes maximum, et les 10 000 capteurs sont répartis uniformément sur tous les nœuds grâce au hachage de la clé composite.

### alertes_par_wilaya — `(wilaya, date_jour)`

Utiliser `wilaya` seul comme partition key concentrerait toutes les alertes historiques d'Alger sur quelques nœuds. Cette hot partition serait sollicitée pour toutes les requêtes de monitoring et de dashboard. Le bucket `date_jour` borne chaque partition à une journée d'alertes par wilaya. Les 48 wilayas fois 365 jours produisent environ 17 500 partitions par an, toutes de taille raisonnable.

### agregats_horaires — `(wilaya)`

Cette table ne contient que 8 760 lignes par an et par wilaya, soit une par heure. Le risque de hot partition est négligeable. En revanche les requêtes du dashboard filtrent toujours par wilaya, donc une partition par wilaya permet de lire tous les agrégats d'une wilaya en un seul accès réseau. Le `CLUSTERING ORDER BY date_heure DESC` permet de récupérer les N dernières heures avec un simple `LIMIT N` sans aucun filtrage supplémentaire.

---

## 2. Pourquoi ALLOW FILTERING est dangereux en production

Sans `ALLOW FILTERING`, Cassandra garantit que chaque requête ne touche qu'un nombre de partitions proportionnel au résultat attendu. Avec `ALLOW FILTERING`, Cassandra scanne la totalité des partitions de la table et filtre les lignes en mémoire sur chaque nœud.

Le problème est que le temps de réponse dépend du volume total de la table et non de la taille du résultat. Une requête qui retourne 100 lignes sur 50 millions prend autant de temps que si elle retournait 50 millions. En période de forte ingestion comme les 10 000 mesures par minute de SmartGrid, la combinaison du scan complet et des compactions en cours provoque des `ReadTimeout`. Ces timeouts déclenchent des retries côté driver, qui relancent le scan, ce qui aggrave la surcharge de façon exponentielle.

En pratique, une requête comme `SELECT ... FROM mesures_par_capteur WHERE alerte = true ALLOW FILTERING` fonctionnerait en développement avec peu de données et tomberait en production. C'est exactement ce genre de comportement aléatoire qui est difficile à déboguer.

La règle que j'ai appliquée est la suivante : si une requête nécessite `ALLOW FILTERING` sur une table non bornée, c'est le signal qu'il faut créer une table dédiée dont la partition key correspond aux colonnes du filtre. C'est pourquoi `alertes_par_wilaya` existe : pour éviter de filtrer sur `alerte = true` dans `mesures_par_capteur`.

---

## 3. Comparaison TWCS, STCS et LCS

**TimeWindowCompactionStrategy** regroupe les SSTables dans des fenêtres temporelles. Une fenêtre fermée n'est compactée qu'une seule fois, et quand tous les TTL d'une fenêtre sont expirés la SSTable est supprimée entièrement sans réécriture. C'est la stratégie la plus adaptée aux séries temporelles avec TTL parce que la suppression des données expirées est quasi gratuite. J'ai utilisé TWCS avec une fenêtre d'un jour pour `mesures_par_capteur` et `alertes_par_wilaya`, alignée sur le bucket `date_jour` de la partition key. Après 90 jours les SSTables tombent entières sans déclencher de compaction coûteuse.

**SizeTieredCompactionStrategy** regroupe les SSTables de taille similaire. C'est la stratégie par défaut de Cassandra, adaptée aux workloads en écriture intensive sans TTL. Elle ne tire pas parti des TTL : les données expirées sont réécrites lors des compactions avant d'être supprimées. Elle produit aussi des pics I/O imprévisibles lors des grandes fusions. Pour SmartGrid où toutes les tables ont des TTL explicites, STCS n'est pas un bon choix.

**LeveledCompactionStrategy** organise les SSTables en niveaux de taille fixe. Au niveau L1 et au-delà, chaque clé n'apparaît que dans une seule SSTable, ce qui garantit 1 à 2 accès disque par lecture quelle que soit la taille de la table. C'est la meilleure stratégie pour les données relues fréquemment et mises à jour régulièrement. J'ai utilisé LCS pour `agregats_horaires` parce que cette table est interrogée intensément par les dashboards, son volume est faible (48 wilayas fois 8 760 heures par an), et elle reçoit des `INSERT` toutes les heures qui écrasent les valeurs précédentes. Le coût d'amplification en écriture de LCS est acceptable pour ce volume.

| Stratégie | Écriture | Lecture | TTL | Cas d'usage |
|-----------|----------|---------|-----|-------------|
| TWCS | bonne | correcte | excellent | Séries temporelles, IoT, logs |
| STCS | très bonne | correcte | mauvais | Write-heavy sans TTL |
| LCS | correcte | très bonne | correct | Agrégats, référentiels, UPSERT |
