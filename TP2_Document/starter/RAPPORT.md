# RAPPORT TP2 — MongoDB : Plateforme de Gestion de Dossiers Médicaux

---

## Exercice 1 — Modélisation et Insertion

### Embedding vs Referencing

Pour les **consultations** j'ai choisi l'**embedding** : les consultations sont directement intégrées dans le document patient sous forme de tableau. Ce choix se justifie par le fait qu'on accède presque toujours aux consultations dans le contexte du patient — afficher le dossier complet, la dernière consultation, l'historique. Avec l'embedding, un seul accès en base suffit. L'inconvénient est que le document grossit avec le temps, mais pour un dossier médical où le nombre de consultations reste raisonnable (quelques dizaines par an), ça reste gérable.

Pour les **analyses** j'ai choisi le **referencing** : les analyses sont dans une collection séparée `analyses` et référencent le patient via `patient_id`. Ce choix s'explique par le volume : une analyse peut contenir des résultats très détaillés (NFS avec 15 valeurs, lipidogramme, ECG numérisé), et certains patients accumulent des dizaines d'analyses. Stocker tout ça en embedded ferait exploser la taille des documents patients et dépasserait potentiellement la limite de 16 MB de MongoDB. Le `$lookup` pour les rejoindre est acceptable car cette jointure n'est pas faite à chaque requête.

La validation de schéma sur la collection `patients` impose les champs critiques (`cin`, `nom`, `prenom`, `dateNaissance`, `sexe`, `adresse`, `groupeSanguin`) et contraint les valeurs possibles (`sexe` : M ou F, `groupeSanguin` : 8 valeurs possibles, `cin` : exactement 12 caractères). Ça évite d'insérer des données corrompues tout en laissant les champs optionnels (`antecedents`, `allergies`, `consultations`) libres.

---

## Exercice 2 — Requêtes de Base

**Requête 2.1** — Pour trouver les patients diabétiques de plus de 50 ans à Alger, j'ai combiné trois filtres : `antecedents: "Diabète"` pour chercher dans le tableau des antécédents (MongoDB cherche automatiquement dans les tableaux), `"adresse.wilaya": "Alger"` pour le filtre géographique, et un filtre sur `dateNaissance` avec `$lte` pour calculer dynamiquement la date de naissance maximale correspondant à 50 ans.

**Requête 2.2** — Pour filtrer les patients allergiques à la Pénicilline avec au moins 3 consultations, j'ai utilisé `$expr` avec `$size` sur le tableau `consultations`. `$expr` est nécessaire pour comparer un champ calculé (la taille du tableau) à une valeur constante — on ne peut pas faire ça avec un filtre simple.

**Requête 2.3** — Pour la projection avec seulement la dernière consultation, j'ai utilisé `$arrayElemAt` avec l'index `-1`, qui retourne le dernier élément du tableau. C'est plus propre que de trier et de prendre le premier.

**Requête 2.4** — Celle-ci nécessite un `aggregate` au lieu d'un `find` parce qu'il faut d'abord créer un champ calculé (`derniereConsultation`) avant de filtrer dessus. On ne peut pas faire un `$match` sur un champ qui n'existe pas encore dans le document — il faut passer par `$addFields` d'abord.

**Requête 2.5** — La recherche textuelle sur les diagnostics nécessite de créer un index `text` au préalable. J'ai indexé `consultations.diagnostic`. La recherche avec `$text: { $search: "hypertension diabète" }` retourne les patients dont au moins une consultation contient l'un de ces termes.

---

## Exercice 3 — Agrégation Avancée

**Pipeline 3.1** — Distribution des diagnostics par wilaya. Le pipeline commence par un `$unwind` sur `consultations` pour transformer chaque consultation en document séparé, puis groupe par `wilaya + diagnostic` avec `$sum: 1`. Sans le `$unwind`, on ne pourrait pas accéder aux champs imbriqués dans les consultations pour les agréger.

**Pipeline 3.2** — Médicament le plus prescrit par spécialité. Ce pipeline nécessite deux `$unwind` successifs : le premier déplie les consultations, le second déplie les médicaments à l'intérieur de chaque consultation. Ensuite on groupe par `spécialité + médicament`, on trie par nombre de prescriptions décroissant, puis on regroupe par spécialité en gardant le premier résultat (`$first`) qui est forcément le plus prescrit grâce au tri précédent.

**Pipeline 3.3** — Évolution mensuelle. Le filtre `$match` avec `$gte` sur une date calculée dynamiquement retient les 12 derniers mois. Le `$group` extrait l'année et le mois avec `$year` et `$month`, puis le `$project` final les formate en `"YYYY-MM"` avec un `$cond` pour ajouter le zéro devant les mois à un chiffre.

**Pipeline 3.4** — Patients à risque. Le `$match` initial filtre sur `$all: ["Diabète type 2", "HTA"]` pour exiger les deux antécédents simultanément. `$addFields` calcule l'âge en millisecondes puis le convertit en années avec `$divide` et `$floor`. Un deuxième `$match` filtre ensuite sur l'âge calculé.

**Pipeline 3.5** — Rapport médecins. Pour le taux de ré-consultation, j'ai utilisé `$addToSet: "$_id"` pour collecter les identifiants patients uniques par médecin, puis `$size` pour compter les patients distincts. Le taux est `(total_consultations - nb_patients_uniques) / nb_patients_uniques × 100` : si un médecin voit 10 patients pour 15 consultations, il a 5 ré-consultations sur 10 patients, soit 50%.

---

## Exercice 4 — Index et Optimisation

J'ai créé 5 index en tout, chacun ciblant un pattern de requête précis.

**`idx_wilaya_antecedents`** : index composé sur `adresse.wilaya` + `antecedents`. La wilaya est mise en premier parce que c'est un filtre d'égalité à cardinalité moyenne (5 wilayas), ce qui réduit drastiquement le nombre de documents à examiner avant d'appliquer le filtre sur les antécédents. Couvre la requête 2.1 directement.

**`idx_consultation_date`** : index sur `consultations.date`. MongoDB crée automatiquement un index multiclé pour les champs de tableaux imbriqués. Indispensable pour la requête 3.3 qui filtre sur les dates de consultation.

**`idx_text_diagnostics`** : index text sur `consultations.diagnostic` et `consultations.notes`. MongoDB n'autorise qu'un seul index text par collection, donc j'ai regroupé les deux champs textuels pertinents dans le même index.

**`idx_analyses_patient_date`** : index composé sur `patient_id + date DESC` dans la collection analyses. Optimise les `$lookup` depuis patients vers analyses et permet de récupérer les analyses les plus récentes en premier sans tri supplémentaire.

**`idx_ttl_analyses_5ans`** : index TTL sur le champ `date` avec `expireAfterSeconds: 157680000` (5 ans). MongoDB supprime automatiquement les analyses expirées via un thread de fond qui tourne toutes les 60 secondes. En production il faudrait archiver avant de supprimer, mais pour HealthCare DZ les analyses de plus de 5 ans peuvent être purgées.

### Comparaison explain() avant/après index

| Métrique              | Sans index (COLLSCAN) | Avec index (IXSCAN)    |
|-----------------------|-----------------------|------------------------|
| Stage                 | COLLSCAN              | IXSCAN                 |
| Docs examinés         | 20 (tous)             | 2-3 (filtrés)          |
| Docs retournés        | 2                     | 2                      |
| Temps d'exécution     | ~5 ms                 | < 1 ms                 |

Sur 20 documents le gain est faible, mais la différence devient critique à grande échelle : avec 100 000 patients, le COLLSCAN examinerait 100 000 documents contre quelques centaines avec l'index.

**Index composé pour la requête la plus complexe** (3.4) : `{ antecedents: 1, dateNaissance: 1 }`. L'ordre est important — `antecedents` en premier parce que c'est un filtre d'égalité (`$all`), `dateNaissance` en second parce que c'est utilisé pour calculer l'âge (filtre de plage implicite). La règle ESR (Equality → Sort → Range) s'applique ici.

---

## Exercice 5 — $lookup et Données Référencées

**Requête 5.1** — Le `$lookup` joint `patients` avec `analyses` sur `_id → patient_id`. Le résultat est un document patient avec un champ `analyses` contenant le tableau de toutes ses analyses. C'est l'équivalent d'un LEFT JOIN SQL — les patients sans analyse auront un tableau vide.

**Requête 5.2** — Pour trouver les patients avec glycémie > 1.26 g/L, on part de la collection `analyses` (plus petite, donc plus efficace comme point de départ), on filtre sur `type: "Glycémie"` et `resultats.glycemie_a_jeun_gL: { $gt: 1.26 }`, puis on joint avec `patients` pour récupérer le nom. Le `$unwind` après le `$lookup` est nécessaire parce que `$lookup` retourne toujours un tableau — même quand il n'y a qu'un seul patient correspondant.

**Requête 5.3** — Le taux d'analyses anormales par wilaya nécessite de joindre `analyses` avec `patients` pour accéder à la wilaya, puis de grouper par wilaya. La condition d'anomalie utilise `$cond` avec `$gt: ["$resultats.glycemie_a_jeun_gL", 1.26]` pour compter les analyses anormales. Le taux final est calculé par `$divide` puis `$multiply` par 100.

---

## Questions de réflexion

**1. Pourquoi avoir choisi l'embedding pour les consultations plutôt que le referencing ?**

Le critère principal est le pattern d'accès : dans HealthCare DZ, on lit presque toujours le dossier complet d'un patient — toutes ses consultations, son historique, ses traitements. Avec l'embedding, un seul `find` par `_id` suffit. Avec le referencing, il faudrait un `$lookup` à chaque fois, ou pire, deux requêtes séparées côté application. L'embedding sacrifie un peu d'espace disque pour gagner en performance lecture, ce qui est le bon compromis ici. La limite de 16 MB par document n'est pas un problème pour des consultations textuelles.

**2. Que se passe-t-il si deux médecins mettent à jour le dossier du même patient en même temps ?**

MongoDB garantit l'atomicité au niveau du document : une opération `$push` sur le tableau `consultations` est atomique. Si deux médecins ajoutent une consultation simultanément, les deux seront bien enregistrées sans corruption. En revanche, si on lit le document, on le modifie côté application, puis on réécrit (pattern read-modify-write), on risque de perdre une mise à jour concurrente. La solution est d'utiliser des opérations atomiques comme `$push`, `$set` avec filtre, ou les transactions multi-documents si on touche plusieurs collections en même temps (patient + analyses).

**3. Quand le $lookup devient-il trop coûteux ?**

Le `$lookup` est efficace tant que la collection jointe a un index sur le champ de jointure (`patient_id` dans `analyses`). Sans index, MongoDB fait un scan complet de la collection cible pour chaque document source — c'est O(N × M). Avec l'index `idx_analyses_patient_date`, la jointure est O(N × log M). Le `$lookup` devient vraiment problématique quand les deux collections sont très larges et qu'on ne peut pas filtrer en amont. Dans ce cas il vaut mieux revoir le modèle de données et envisager l'embedding partiel des données les plus consultées.