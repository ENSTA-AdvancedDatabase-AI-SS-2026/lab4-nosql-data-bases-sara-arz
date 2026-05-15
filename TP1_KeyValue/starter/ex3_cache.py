"""
TP1 - Exercice 3 : Pattern Cache-Aside avec TTL
Use Case : Cache des pages produits ShopFast
"""
import redis
import json
import time
from typing import Optional

r = redis.Redis(host='localhost', port=6379, decode_responses=True)


def slow_db_get_product(product_id: int) -> Optional[dict]:
    """Simule une requête PostgreSQL lente (2 secondes)"""
    time.sleep(2)
    products = {
        1: {"id": 1, "name": "Samsung Galaxy A54", "price": 65000, "stock": 15},
        2: {"id": 2, "name": "Laptop HP 15-inch", "price": 120000, "stock": 8},
        3: {"id": 3, "name": "Casque JBL Bluetooth", "price": 12000, "stock": 50},
        4: {"id": 4, "name": "Clavier Mécanique", "price": 8000, "stock": 30},
    }
    return products.get(product_id)


def get_product_cached(r, product_id: int, ttl: int = 600) -> Optional[dict]:
    """
    Pattern Cache-Aside :
    1. Chercher dans Redis (clé: "product_cache:{product_id}")
    2. Si MISS → chercher dans slow_db → stocker dans Redis avec TTL
    3. Retourner le produit
    4. Afficher si c'est un HIT ou MISS avec la latence
    """
    start = time.time()
    cache_key = f"product_cache:{product_id}"

    # Étape 1 : Lire depuis le cache Redis
    cached = r.get(cache_key)
    elapsed_ms = (time.time() - start) * 1000

    if cached is not None:
        # CACHE HIT : données disponibles immédiatement
        print(f"  CACHE HIT  — {elapsed_ms:.2f}ms")
        return json.loads(cached)

    # CACHE MISS : aller chercher en base de données
    product = slow_db_get_product(product_id)
    elapsed_ms = (time.time() - start) * 1000

    if product is not None:
        # Stocker en cache avec TTL pour les prochaines requêtes
        r.setex(cache_key, ttl, json.dumps(product))

    print(f" CACHE MISS — {elapsed_ms:.2f}ms (DB simulée)")
    return product


def invalidate_product_cache(r, product_id: int):
    """Supprimer le cache d'un produit (après mise à jour en DB)"""
    # TODO
    deleted = r.delete(f"product_cache:{product_id}")
    if deleted:
        print(f" Cache invalidé pour produit #{product_id}")
    else:
        print(f"Aucun cache à invalider pour produit #{product_id}")




def benchmark_cache(r, product_id: int, iterations: int = 20):
    """
    Effectuer 'iterations' appels à get_product_cached
    Afficher :
    - Temps moyen cache HIT
    - Temps moyen cache MISS
    - Taux de cache hit (%)
    """
    # TODO
    hit_times = []
    miss_times = []

    # Assurer un état propre pour le benchmark
    r.delete(f"product_cache:{product_id}")

    for i in range(iterations):
        start = time.time()
        cache_key = f"product_cache:{product_id}"
        cached = r.get(cache_key)
        is_hit = cached is not None

        if not is_hit:
            product = slow_db_get_product(product_id)
            if product:
                r.setex(cache_key, 600, json.dumps(product))

        elapsed_ms = (time.time() - start) * 1000

        if is_hit:
            hit_times.append(elapsed_ms)
        else:
            miss_times.append(elapsed_ms)

    print(f"\n{'=' * 45}")
    print(f"  Benchmark — {iterations} itérations sur produit #{product_id}")
    print(f"{'=' * 45}")
    if miss_times:
        avg_miss = sum(miss_times) / len(miss_times)
        print(f"  MISS — Moy: {avg_miss:8.1f}ms | n={len(miss_times)}")
    if hit_times:
        avg_hit = sum(hit_times) / len(hit_times)
        print(f"  HIT  — Moy: {avg_hit:8.2f}ms | n={len(hit_times)}")
    if hit_times and miss_times:
        speedup = (sum(miss_times) / len(miss_times)) / (sum(hit_times) / len(hit_times))
        print(f"  Accélération : x{speedup:.0f}")
    hit_rate = len(hit_times) / iterations * 100
    print(f"  Taux de hit  : {hit_rate:.0f}%")
    print(f"{'=' * 45}")


if __name__ == "__main__":
    r.flushdb()
    
    print("=== Test Cache-Aside ===")
    print("\nPremier appel (MISS attendu):")
    p = get_product_cached(r, 1)
    print(f"   → {p}")
    
    print("\nDeuxième appel (HIT attendu):")
    p = get_product_cached(r, 1)
    print(f"   → {p}")

    print("\n=== Benchmark ===")
    benchmark_cache(r, 1, iterations=10)
