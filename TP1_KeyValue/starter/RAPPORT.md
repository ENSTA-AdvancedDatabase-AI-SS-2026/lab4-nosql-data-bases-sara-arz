# RAPPORT TP1 — Redis Cache E-commerce ShopFast

---

## Exercice 1 — Structures de données

Pour stocker les produits j'ai utilisé un **Hash** (`product:{id}`) parce que ça permet d'accéder à un champ précis sans charger tout l'objet. Pour le panier j'ai aussi utilisé un Hash avec `HINCRBY` qui incrémente la quantité de façon atomique. Pour l'historique de navigation j'ai utilisé une **List** avec `LPUSH + LTRIM` pour garder seulement les 10 derniers produits vus. Pour les catégories j'ai utilisé un **Set** parce que `SINTER` permet de trouver les produits en commun entre plusieurs catégories facilement.

---

## Exercice 2 — Sessions utilisateur

J'ai utilisé `SETEX` pour créer la session avec un TTL de 30 minutes dès le départ. Pour le sliding expiration, j'appelle `EXPIRE` à chaque requête pour remettre le compteur à 30 minutes. Le token est un UUID4 pour qu'il soit imprévisible. J'ai aussi gardé un Set `user_sessions:{user_id}` pour pouvoir retrouver et supprimer toutes les sessions d'un utilisateur d'un coup.

---

## Exercice 3 — Cache-Aside

Le pattern fonctionne comme ça :
1. On cherche dans Redis
2. Si HIT → on retourne directement
3. Si MISS → on va en DB, on stocke dans Redis avec TTL, on retourne

J'ai utilisé `json.dumps/loads` pour stocker le dict en String Redis. Pour l'invalidation j'ai choisi de supprimer la clé (`DELETE`) plutôt que de réécrire dedans pour éviter les problèmes si deux requêtes arrivent en même temps.

### Mesures de performance

| Scénario | Latence |
|----------|---------|
| Cache MISS (accès DB simulé) | ~2000 ms |
| Cache HIT (Redis) | < 1 ms |
| Accélération | ~2000× |

En production avec une vraie DB, l'accélération serait plutôt entre 50× et 100×.

---

## Exercice 4 — Leaderboard

J'ai utilisé un **Sorted Set** avec `ZINCRBY` pour incrémenter les ventes. `ZREVRANK` retourne un rang 0-based donc j'ajoute toujours 1 pour avoir un rang lisible (1 = meilleur). Pour le classement par catégorie j'ai utilisé `ZINTERSTORE` avec un poids 0 sur le Set de catégorie pour garder uniquement les scores de ventes.

---

## Exercice 5 — Pipeline & Transactions

Pour le bulk insert j'ai comparé l'insertion séquentielle (un aller-retour réseau par commande) vs pipeline (tout envoyé en une fois). Le pipeline est nettement plus rapide quand il y a beaucoup de produits à insérer.

Pour le passage de commande j'ai utilisé `MULTI/EXEC` avec `WATCH` sur le stock. Si le stock est modifié entre le moment où on le lit et le moment où on décrémente, la transaction est annulée et on retourne une erreur. Ça évite de vendre un produit en rupture de stock.


---

## Questions de réflexion

**1. Que se passe-t-il si Redis redémarre ?**

Toutes les données en mémoire sont perdues si la persistance est désactivée. Avec la config du `redis.conf` fourni (RDB + AOF), les données sont sauvegardées sur disque et rechargées au redémarrage. Dans tous les cas l'application doit être capable de fonctionner sans cache : si Redis est down, on va directement en DB avec une latence plus élevée, mais ça marche quand même.

**2. Comment gérer la cohérence cache/DB en cas d'accès concurrent ?**

La stratégie que j'ai choisie est le write-invalidate : quand un produit est mis à jour en DB, on supprime la clé dans Redis. Le prochain lecteur ira chercher la nouvelle valeur en DB et la mettra en cache. C'est plus simple que le write-through et ça évite les race conditions où deux processus écrivent des valeurs différentes dans le cache. Pour les opérations critiques comme le stock, j'utilise `WATCH/MULTI/EXEC` pour détecter les modifications concurrentes.

**3. Quand un TTL trop court est-il problématique ?**

Si le TTL est très court et que beaucoup d'utilisateurs accèdent au même produit, tout le monde va expérimenter un MISS en même temps et envoyer des centaines de requêtes à la DB simultanément. C'est le "cache stampede". Par exemple un TTL de 1 seconde sur une page produit pendant les soldes pourrait saturer la DB. Il faut trouver un compromis entre fraîcheur des données et charge sur la DB. Pour ShopFast je mettrais 5 minutes pour les prix et 1 heure pour les descriptions.
