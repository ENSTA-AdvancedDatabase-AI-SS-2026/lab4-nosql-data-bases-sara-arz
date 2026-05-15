"""
TP1 - Exercice 5 : Pipeline & Transactions Redis
Use Case : Traitement en lot et passage de commande atomique
"""
import redis
import time
import json
from typing import Optional

r = redis.Redis(host='localhost', port=6379, decode_responses=True)


# ─────────────────────────────────────────────
# PARTIE A : Pipeline — Bulk Insert
# ─────────────────────────────────────────────

def bulk_insert_products(r, products: list[dict]) -> dict:
    """
    Insérer une liste de produits en une seule passe réseau via pipeline.
    Mesure et compare le temps pipeline vs séquentiel.
    Retourne {"pipeline_ms": float, "sequential_ms": float, "speedup": float}
    """
    # ── Méthode 1 : Sans pipeline (N aller-retours réseau)
    start = time.time()
    for product in products:
        pid = product["id"]
        r.hset(f"product:{pid}", mapping={k: v for k, v in product.items() if k != "id"})
    sequential_ms = (time.time() - start) * 1000

    # Nettoyer avant le test pipeline
    for product in products:
        r.delete(f"product:{product['id']}")

    # ── Méthode 2 : Avec pipeline (1 seul aller-retour réseau)
    start = time.time()
    pipe = r.pipeline()
    for product in products:
        pid = product["id"]
        pipe.hset(f"product:{pid}", mapping={k: v for k, v in product.items() if k != "id"})
    pipe.execute()  # Envoie toutes les commandes en une fois
    pipeline_ms = (time.time() - start) * 1000

    speedup = sequential_ms / pipeline_ms if pipeline_ms > 0 else 0

    print(f"  Sequential : {sequential_ms:.1f}ms")
    print(f"  Pipeline   : {pipeline_ms:.1f}ms")
    print(f"  Accélération : x{speedup:.1f}")

    return {"pipeline_ms": pipeline_ms, "sequential_ms": sequential_ms, "speedup": speedup}


def bulk_update_prices(r, updates: list[tuple]) -> int:
    """
    Mettre à jour les prix de plusieurs produits via pipeline.
    updates : liste de (product_id, new_price)
    Retourne le nombre de produits mis à jour.
    """
    pipe = r.pipeline()
    for product_id, new_price in updates:
        pipe.hset(f"product:{product_id}", "price", str(new_price))
    results = pipe.execute()
    return sum(1 for r in results if r == 0)  # HSET retourne 0 si champ mis à jour


# ─────────────────────────────────────────────
# PARTIE B : Transactions MULTI/EXEC
# ─────────────────────────────────────────────

def place_order(r, user_id: int, product_id: int, quantity: int) -> dict:
    """
    Passer une commande de façon atomique avec MULTI/EXEC.
    Opérations dans la transaction :
    1. Vérifier que le stock est suffisant (HGET)
    2. Décrémenter le stock (HINCRBY -quantity)
    3. Enregistrer la vente dans le leaderboard (ZINCRBY)
    4. Vider le panier de l'utilisateur (HDEL)
    5. Créer l'enregistrement de commande (HSET)

    Utilise WATCH pour détecter les modifications concurrentes du stock.
    Retourne {"success": bool, "order_id": str | None, "message": str}
    """
    import uuid
    order_key = f"order:{uuid.uuid4()}"
    stock_key = f"product:{product_id}"
    leaderboard_key = "leaderboard:sales"

    # WATCH : surveiller la clé stock pour détecter les modifications concurrentes
    with r.pipeline() as pipe:
        try:
            pipe.watch(stock_key)

            # Lire le stock AVANT de démarrer la transaction
            stock_raw = pipe.hget(stock_key, "stock")
            if stock_raw is None:
                pipe.reset()
                return {"success": False, "order_id": None, "message": "Produit introuvable"}

            stock = int(stock_raw)
            if stock < quantity:
                pipe.reset()
                return {
                    "success": False,
                    "order_id": None,
                    "message": f"Stock insuffisant (disponible: {stock}, demandé: {quantity})"
                }

            # Démarrer la transaction atomique
            pipe.multi()

            # 1. Décrémenter le stock
            pipe.hincrby(stock_key, "stock", -quantity)

            # 2. Enregistrer la vente dans le classement
            pipe.zincrby(leaderboard_key, quantity, str(product_id))

            # 3. Vider le panier
            pipe.delete(f"cart:{user_id}")

            # 4. Créer l'enregistrement de commande
            pipe.hset(order_key, mapping={
                "user_id": str(user_id),
                "product_id": str(product_id),
                "quantity": str(quantity),
                "timestamp": str(time.time()),
                "status": "confirmed"
            })

            # Exécuter toutes les commandes atomiquement
            pipe.execute()

            return {
                "success": True,
                "order_id": order_key,
                "message": f"Commande confirmée : {quantity}x produit #{product_id}"
            }

        except redis.WatchError:
            # Le stock a été modifié entre le WATCH et le MULTI → annuler
            return {
                "success": False,
                "order_id": None,
                "message": "Conflit concurrent détecté, veuillez réessayer"
            }


def get_order(r, order_id: str) -> Optional[dict]:
    """Récupérer les détails d'une commande"""
    data = r.hgetall(order_id)
    return data if data else None


# ─────────────────────────────────────────────
# Bonus : Rate Limiting (INCR + EXPIRE)
# ─────────────────────────────────────────────

def check_rate_limit(r, user_id: int, ip: str, max_requests: int = 10, window_seconds: int = 60) -> dict:
    """
    Limiter les requêtes par combinaison user:IP.
    Utilise INCR + EXPIRE pour un compteur glissant par fenêtre de temps.
    Retourne {"allowed": bool, "remaining": int, "reset_in": int}
    """
    key = f"rate:{user_id}:{ip}"

    # Pipeline pour INCR + TTL en une seule transaction
    pipe = r.pipeline()
    pipe.incr(key)
    pipe.ttl(key)
    count, ttl = pipe.execute()

    # Fixer le TTL uniquement à la première requête de la fenêtre
    if ttl == -1:  # Clé sans expiration (première fois)
        r.expire(key, window_seconds)
        ttl = window_seconds

    allowed = count <= max_requests
    remaining = max(0, max_requests - count)

    if not allowed:
        print(f"  🚫 Rate limit dépassé pour user:{user_id}@{ip} ({count}/{max_requests})")
    else:
        print(f"  ✅ Requête autorisée pour user:{user_id}@{ip} ({count}/{max_requests})")

    return {
        "allowed": allowed,
        "current_count": count,
        "remaining": remaining,
        "reset_in": ttl
    }


if __name__ == "__main__":
    r.flushdb()

    print("=" * 50)
    print("PARTIE A — Bulk Insert avec Pipeline")
    print("=" * 50)

    # Générer 100 produits de test
    products = [
        {"id": i, "name": f"Produit {i}", "price": str(i * 1000), "stock": "50", "category": "electronics"}
        for i in range(1, 101)
    ]

    print(f"\nInsertion de {len(products)} produits...")
    stats = bulk_insert_products(r, products)

    print("\n" + "=" * 50)
    print("PARTIE B — Transaction MULTI/EXEC")
    print("=" * 50)

    # Ajouter un produit avec stock limité
    r.hset("product:1", mapping={"name": "Samsung A54", "price": "65000", "stock": "3"})

    print("\n✅ Commande 1 (stock: 3, demande: 2) :")
    result = place_order(r, user_id=42, product_id=1, quantity=2)
    print(f"   {result}")
    print(f"   Stock restant: {r.hget('product:1', 'stock')}")

    print("\n❌ Commande 2 (stock insuffisant, demande: 5) :")
    result = place_order(r, user_id=43, product_id=1, quantity=5)
    print(f"   {result}")

    print("\n" + "=" * 50)
    print("BONUS — Rate Limiting")
    print("=" * 50)
    r.flushdb()
    print("\nSimulation de 12 requêtes (limite: 10/min) :")
    for i in range(12):
        check_rate_limit(r, user_id=1, ip="192.168.1.1", max_requests=10, window_seconds=60)
