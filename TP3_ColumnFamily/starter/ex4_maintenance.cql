-- TP3 - Exercice 4 : Compaction et Maintenance
-- Use Case : SmartGrid DZ

USE smartgrid;

-- ─── 4.1 Choix de la stratégie de compaction ─────────────────────────────────
--
-- TimeWindowCompactionStrategy (TWCS) → mesures_par_capteur, alertes_par_wilaya
--   Les données IoT arrivent en ordre chronologique et expirent via TTL.
--   TWCS regroupe les SSTables dans des fenêtres temporelles (ex: 1 jour).
--   Quand une fenêtre est fermée (plus aucune écriture) et que tous les TTL
--   sont expirés, la SSTable entière est supprimée en un seul "drop" sans
--   réécriture → compaction quasi gratuite, espace libéré immédiatement.
--   Avantage majeur : évite de lire/réécrire des données déjà expirées.
--
-- SizeTieredCompactionStrategy (STCS) → à éviter ici
--   Regroupe les SSTables de taille similaire. Produit de l'amplification
--   en lecture/écriture, ne tire pas parti des TTL, génère des pics I/O
--   importants lors des compactions. Adapté aux charges write-heavy sans TTL.
--
-- LeveledCompactionStrategy (LCS) → agregats_horaires
--   Maintient des SSTables de taille fixe organisées en niveaux.
--   Garantit que chaque clé n'apparaît que dans une seule SSTable par niveau
--   → lectures très rapides (1-2 I/O). Idéal pour les données peu nombreuses,
--   souvent relues (dashboard) et mises à jour (UPDATE des agrégats).
--   Coût : amplification d'écriture plus élevée, acceptable pour les agrégats
--   car le volume est faible (48 wilayas × 8 760 heures/an).


-- ─── 4.2 Configurer TWCS pour mesures_par_capteur ────────────────────────────
--
-- Choix des paramètres :
--   compaction_window_unit = DAYS
--   compaction_window_size = 1
--   → Une SSTable par jour par nœud.
--     Après 90 jours (TTL), la SSTable tombe entière sans compaction coûteuse.
--     Aligné sur le bucket date_jour de la partition key → une fenêtre TWCS
--     coïncide exactement avec une journée de données.

ALTER TABLE mesures_par_capteur
WITH compaction = {
  'class':                   'TimeWindowCompactionStrategy',
  'compaction_window_unit':  'DAYS',
  'compaction_window_size':  1,
  'max_threshold':           32,      -- max SSTables fusionnées en une passe
  'min_threshold':           4        -- min SSTables avant de déclencher
};

-- Même logique pour alertes_par_wilaya (TTL 1 an, bucket quotidien)
ALTER TABLE alertes_par_wilaya
WITH compaction = {
  'class':                   'TimeWindowCompactionStrategy',
  'compaction_window_unit':  'DAYS',
  'compaction_window_size':  1,
  'max_threshold':           32,
  'min_threshold':           4
};

-- LCS pour les agrégats (petits volumes, beaucoup de lectures dashboard)
ALTER TABLE agregats_horaires
WITH compaction = {
  'class':          'LeveledCompactionStrategy',
  'sstable_size_in_mb': 160    -- taille cible par SSTable au niveau L1+
};


-- ─── 4.3 Lignes qui expirent dans les 7 prochains jours ──────────────────────
--
-- TTL(colonne) renvoie le TTL restant en secondes pour une colonne donnée.
-- 7 jours = 604 800 secondes.
-- On filtre les lignes dont le TTL résiduel est <= 604 800 s.
-- Note : ALLOW FILTERING sur une partition bornée (capteur_id + date_jour)
-- est tolérable ; en production on exécute ceci par wilaya/date spécifique.

SELECT capteur_id, date_jour, timestamp,
       TTL(tension_v) AS ttl_restant_s
FROM mesures_par_capteur
WHERE capteur_id = 550e8400-e29b-41d4-a716-446655440000
  AND date_jour  = '2025-01-15'
  AND TTL(tension_v) <= 604800
ALLOW FILTERING;

-- Pour avoir une estimation globale côté ops (via nodetool ou scripts) :
-- nodetool cfstats smartgrid.mesures_par_capteur
-- → affiche "SSTable count", "Space used", "Droppable tombstones"


-- ─── 4.4 Détecter et corriger une "hot partition" ────────────────────────────
--
-- DÉTECTION
-- Une hot partition se manifeste par :
--   1. Un nœud avec CPU/I/O nettement plus élevé que les autres
--      → nodetool tpstats / nodetool netstats
--   2. Une SSTable disproportionnée dans nodetool cfstats
--   3. Des latences de lecture élevées sur des requêtes ciblant une partition
--      → Cassandra system.local ou outils de monitoring (Prometheus + Grafana)
--   4. Un avertissement "large partition" dans system.log :
--      "Writing large partition … (x MiB)"

-- Commandes de diagnostic :
--   nodetool cfstats smartgrid.mesures_par_capteur
--   nodetool getsstables smartgrid mesures_par_capteur <partition_key>
--   SELECT * FROM system.size_estimates
--     WHERE keyspace_name='smartgrid' AND table_name='mesures_par_capteur';

--
-- CAUSES dans notre schéma
--   • capteur_id sans bucket date → 1 capteur actif depuis 90 jours
--     = 90 × 1 440 = 129 600 lignes dans une seule partition → WIDE PARTITION.
--   • Wilaya seul comme partition key → Alger concentre toutes ses alertes.
--
-- CORRECTIONS appliquées dans ex1_schema.cql
--   ✅ mesures_par_capteur  → (capteur_id, date_jour) : bucket par jour
--   ✅ alertes_par_wilaya   → (wilaya, date_jour)     : bucket par jour
--
-- CORRECTION générique si une hot partition subsiste malgré le bucketing :
--   1. Ajouter un "salt" (hash % N) à la partition key pour répartir sur N
--      sous-partitions. Ex : (capteur_id, date_jour, shard INT)
--      où shard = hash(capteur_id) % 4.
--   2. Les lectures doivent alors interroger les N shards et fusionner les
--      résultats côté applicatif (scatter-gather).
--   3. Privilégier N petit (4 à 8) pour ne pas multiplier les requêtes.

-- Exemple de schéma avec sharding manuel (bonus) :
CREATE TABLE IF NOT EXISTS mesures_par_capteur_sharded (
  capteur_id   UUID,
  date_jour    DATE,
  shard        TINYINT,   -- 0 à 3 : hash(capteur_id) % 4
  timestamp    TIMESTAMP,
  puissance_kw FLOAT,
  alerte       BOOLEAN,
  PRIMARY KEY ((capteur_id, date_jour, shard), timestamp)
) WITH CLUSTERING ORDER BY (timestamp DESC)
  AND default_time_to_live = 7776000;
-- Requête : lancer 4 SELECT (shard 0..3) en parallèle et fusionner.
