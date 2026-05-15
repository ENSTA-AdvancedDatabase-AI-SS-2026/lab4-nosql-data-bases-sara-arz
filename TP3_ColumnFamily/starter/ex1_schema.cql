-- TP3 - Exercice 1 : Schéma Cassandra
-- Use Case : SmartGrid DZ - IoT Électrique

-- ─── 1.1 : Créer le Keyspace ──────────────────────────────────────────────────
-- En production (3 nœuds réels) → replication_factor: 3
-- Pour le TP local (1 seul nœud Docker) → replication_factor: 1

CREATE KEYSPACE IF NOT EXISTS smartgrid
WITH replication = {
  'class': 'NetworkTopologyStrategy',
  'datacenter1': 1          -- ← mettre 3 en production
}
AND durable_writes = true;

USE smartgrid;

-- ─── 1.2 : Table mesures_par_capteur ──────────────────────────────────────────
-- Requête cible : "Mesures du capteur X entre T1 et T2"
--
-- Choix de la PRIMARY KEY :
--   Partition Key : (capteur_id, date_jour)
--     → Bucketing par jour : chaque partition = 1 capteur × 1 jour
--       soit au maximum 1 440 lignes (1 mesure/min × 1 440 min/jour).
--       Sans le bucket date, la partition d'un capteur actif depuis des mois
--       deviendrait une "wide partition" illimitée → hot partition.
--     → 10 000 capteurs × N jours = partitions réparties sur tous les nœuds.
--   Clustering Key : timestamp DESC
--     → Stockage des mesures les plus récentes en tête de partition.
--       Un "SELECT … LIMIT 1" sans borne temporelle renvoie immédiatement
--       la dernière mesure sans scanner toute la partition.

CREATE TABLE IF NOT EXISTS mesures_par_capteur (
  capteur_id   UUID,
  date_jour    DATE,         -- bucket quotidien anti-hot-partition
  timestamp    TIMESTAMP,
  wilaya       TEXT,
  commune      TEXT,
  tension_v    FLOAT,
  courant_a    FLOAT,
  puissance_kw FLOAT,
  frequence_hz FLOAT,
  temperature  FLOAT,
  alerte       BOOLEAN,
  code_alerte  TEXT,
  PRIMARY KEY ((capteur_id, date_jour), timestamp)
) WITH CLUSTERING ORDER BY (timestamp DESC)
  AND default_time_to_live = 7776000  -- 90 jours = 90 × 86 400 s
  AND comment = 'Mesures brutes par capteur, buckétisées par jour';


-- ─── 1.3 : Table alertes_par_wilaya ───────────────────────────────────────────
-- Requête cible : "Alertes de la wilaya X le jour Y"
--
-- Choix de la PRIMARY KEY :
--   Partition Key : (wilaya, date_jour)
--     → On requête toujours par wilaya + jour : la combinaison est la clé
--       naturelle. Avec 48 wilayas × 365 jours = ~17 520 partitions/an,
--       toutes de taille raisonnable (au plus 10 000 alertes/jour par wilaya).
--     → Évite la hot partition "wilaya seul" : Alger aurait des millions
--       de lignes non bornées sur une seule partition.
--   Clustering Keys : timestamp DESC, capteur_id
--     → timestamp DESC : alertes les plus récentes accessibles en premier.
--     → capteur_id : unicité de la ligne (deux capteurs peuvent déclencher
--       une alerte à la même milliseconde) et permet un filtrage secondaire
--       efficace par capteur_id dans la partition.

CREATE TABLE IF NOT EXISTS alertes_par_wilaya (
  wilaya       TEXT,
  date_jour    DATE,
  timestamp    TIMESTAMP,
  capteur_id   UUID,
  code_alerte  TEXT,
  description  TEXT,
  gravite      INT,          -- 1=info, 2=warning, 3=critique
  resolue      BOOLEAN,
  PRIMARY KEY ((wilaya, date_jour), timestamp, capteur_id)
) WITH CLUSTERING ORDER BY (timestamp DESC, capteur_id ASC)
  AND default_time_to_live = 31536000  -- 1 an = 365 × 86 400 s
  AND comment = 'Alertes par wilaya et par jour, ordre antéchronologique';


-- ─── 1.4 : Table agregats_horaires ────────────────────────────────────────────
-- Requête cible : "Consommation moyenne par heure pour le dashboard wilaya"
--
-- Choix de la PRIMARY KEY :
--   Partition Key : (wilaya)
--     → Le dashboard filtre toujours par wilaya. Avec 48 wilayas et des
--       requêtes limitées à quelques jours/semaines, la partition reste
--       petite (48 wilayas × 8 760 heures/an = ~420 000 lignes/an max).
--     → Une Partition Key plus large (wilaya, mois) créerait trop de
--       partitions et compliquerait les requêtes de type "dernières 24h".
--   Clustering Key : date_heure DESC
--     → Le dashboard lit toujours les agrégats les plus récents en premier.
--       Avec LIMIT N on obtient les N dernières heures sans ALLOW FILTERING.

CREATE TABLE IF NOT EXISTS agregats_horaires (
  wilaya            TEXT,
  date_heure        TIMESTAMP,   -- tronqué à l'heure exacte (ex : 14:00:00)
  nb_capteurs       INT,
  puissance_moy_kw  FLOAT,
  puissance_max_kw  FLOAT,
  puissance_min_kw  FLOAT,
  nb_alertes        INT,
  PRIMARY KEY ((wilaya), date_heure)
) WITH CLUSTERING ORDER BY (date_heure DESC)
  AND default_time_to_live = 157680000  -- 5 ans = 5 × 365 × 86 400 s
  AND comment = 'Agrégats horaires pré-calculés par wilaya pour les dashboards';


-- ─── Vérification ─────────────────────────────────────────────────────────────
DESCRIBE TABLES;

-- Pour inspecter une table en détail :
-- DESCRIBE TABLE mesures_par_capteur;
-- DESCRIBE TABLE alertes_par_wilaya;
-- DESCRIBE TABLE agregats_horaires;
