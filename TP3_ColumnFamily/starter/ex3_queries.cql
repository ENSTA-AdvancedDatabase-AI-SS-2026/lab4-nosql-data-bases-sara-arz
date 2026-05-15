-- TP3 - Exercice 3 : Requêtes CQL
-- Use Case : SmartGrid DZ - Interrogation des séries temporelles

USE smartgrid;

-- ─── 3.1 Mesures d'un capteur sur les dernières 6 heures ─────────────────────
-- On connaît capteur_id → on calcule date_jour (aujourd'hui)
-- et on filtre sur timestamp >= (maintenant - 6h).
-- Pas besoin d'ALLOW FILTERING car on touche une seule partition.

SELECT timestamp, tension_v, courant_a, puissance_kw, alerte
FROM mesures_par_capteur
WHERE capteur_id = 550e8400-e29b-41d4-a716-446655440000  -- remplacer par l'UUID réel
  AND date_jour  = '2025-01-15'                           -- date du jour
  AND timestamp >= '2025-01-15 08:00:00+0000'             -- T1 = maintenant - 6h
  AND timestamp <= '2025-01-15 14:00:00+0000';            -- T2 = maintenant


-- ─── 3.2 Dernière mesure de chaque capteur d'une wilaya ──────────────────────
-- Astuce : CLUSTERING ORDER BY timestamp DESC + LIMIT 1 par capteur.
-- On ne peut pas faire un GROUP BY multi-capteurs en une seule requête CQL ;
-- on itère côté applicatif sur chaque capteur_id connu.
-- Ici : exemple pour un capteur donné.

SELECT capteur_id, timestamp, tension_v, puissance_kw, alerte
FROM mesures_par_capteur
WHERE capteur_id = 550e8400-e29b-41d4-a716-446655440000
  AND date_jour  = '2025-01-15'
LIMIT 1;

-- Note : en production, la liste des capteur_id par wilaya est stockée
-- dans une table dédiée type "capteurs_par_wilaya" qu'on requête en premier,
-- puis on fait N requêtes parallèles (une par capteur) avec LIMIT 1.


-- ─── 3.3 Capteurs en alerte dans la wilaya "Alger" aujourd'hui ───────────────
-- On utilise la table alertes_par_wilaya, prévue pour cette requête.
-- La partition (wilaya, date_jour) est la clé naturelle.

-- 3.3a Liste des alertes du jour
SELECT timestamp, capteur_id, code_alerte, gravite, description
FROM alertes_par_wilaya
WHERE wilaya    = 'Alger'
  AND date_jour = '2025-01-15'
ORDER BY timestamp DESC;

-- 3.3b Nombre d'alertes (côté applicatif ou avec COUNT)
SELECT COUNT(*)
FROM alertes_par_wilaya
WHERE wilaya    = 'Alger'
  AND date_jour = '2025-01-15';

-- 3.3c Uniquement les alertes critiques (gravite = 3)
-- gravite n'est pas une clustering key → ALLOW FILTERING sur une partition
-- bornée est tolérable ici (≤ 10 000 lignes/partition).
SELECT timestamp, capteur_id, code_alerte, gravite
FROM alertes_par_wilaya
WHERE wilaya    = 'Alger'
  AND date_jour = '2025-01-15'
  AND gravite   = 3
ALLOW FILTERING;


-- ─── 3.4 Consommation totale par heure sur une journée (dashboard) ────────────
-- On utilise la table agregats_horaires.
-- Partition = wilaya → toutes les heures d'une wilaya dans la même partition.
-- On filtre sur date_heure pour isoler une journée (24 heures).

SELECT date_heure, nb_capteurs, puissance_moy_kw, puissance_max_kw,
       puissance_min_kw, nb_alertes
FROM agregats_horaires
WHERE wilaya    = 'Alger'
  AND date_heure >= '2025-01-15 00:00:00+0000'
  AND date_heure <  '2025-01-16 00:00:00+0000'
ORDER BY date_heure DESC;


-- ─── 3.5 Détection d'anomalie : tension hors plage dans les 30 dernières min ──
-- On utilise alertes_par_wilaya qui stocke déjà les dépassements.
-- Les 30 dernières minutes = timestamp >= maintenant - 30 min.

SELECT wilaya, capteur_id, timestamp, code_alerte, description
FROM alertes_par_wilaya
WHERE wilaya    = 'Alger'
  AND date_jour = '2025-01-15'
  AND timestamp >= '2025-01-15 13:30:00+0000'
  AND code_alerte IN ('SOUS_TENSION', 'SUR_TENSION')
ALLOW FILTERING;
-- ALLOW FILTERING est acceptable ici : partition unique et bornée (wilaya+date),
-- le filtre porte sur les dernières 30 minutes soit ~300 lignes max.

-- Alternative propre sans ALLOW FILTERING :
-- Créer une table anomalies_par_wilaya avec (wilaya, date_jour, code_alerte)
-- comme partition key et timestamp comme clustering key.


-- ─── 3.6 Top 10 capteurs les plus actifs cette semaine ───────────────────────
-- Cassandra ne fait pas d'agrégation cross-partition efficacement.
-- La bonne pratique : maintenir un compteur dans une table dédiée
-- mise à jour à chaque ingestion.
--
-- Table dédiée (à créer dans ex1 bonus) :
--   CREATE TABLE activite_capteur_semaine (
--     semaine  TEXT,       -- ex: '2025-W03'
--     nb_mesures COUNTER,
--     capteur_id UUID,
--     PRIMARY KEY ((semaine), nb_mesures, capteur_id)
--   ) WITH CLUSTERING ORDER BY (nb_mesures DESC);
--
-- Requête résultante :
SELECT capteur_id, nb_mesures
FROM activite_capteur_semaine
WHERE semaine = '2025-W03'
LIMIT 10;

-- Sans table dédiée (déconseillé en prod, acceptable pour le TP) :
-- On scanne la table mesures_par_capteur par date et on compte côté applicatif.


-- ─── 3.7 ALLOW FILTERING : pourquoi éviter ? ─────────────────────────────────

-- ❌ Requête DANGEREUSE en production
-- Cette requête scanne TOUTES les partitions de la table pour trouver
-- les capteurs avec alerte=true. Avec 10 000 capteurs × 90 jours,
-- Cassandra lit des centaines de millions de lignes sur tous les nœuds.
-- Le coordinateur attend toutes les réponses → latence imprévisible,
-- surcharge CPU/IO, risque de timeout voire d'OOM sur les nœuds.

SELECT capteur_id, timestamp, tension_v
FROM mesures_par_capteur
WHERE alerte = true
ALLOW FILTERING;  -- ← parcourt l'intégralité de la table !

-- ✅ Requête CORRECTE avec la table dédiée alertes_par_wilaya
-- On touche une seule partition (wilaya + date) → O(k) lignes, pas O(N).
-- La table a été modélisée précisément pour répondre à cette question.

SELECT capteur_id, timestamp, code_alerte
FROM alertes_par_wilaya
WHERE wilaya    = 'Alger'
  AND date_jour = '2025-01-15';

-- Règle : si une requête nécessite ALLOW FILTERING sur une table non bornée,
-- c'est le signal qu'il faut créer une nouvelle table dédiée à cette requête.
