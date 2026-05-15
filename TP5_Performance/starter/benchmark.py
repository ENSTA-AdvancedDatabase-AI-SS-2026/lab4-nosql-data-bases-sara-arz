"""
TP5 - Benchmark Comparatif NoSQL
Mesurer les performances de Redis, MongoDB, Cassandra, Neo4j
"""
import time
import statistics
import json
import random
import string
import threading
import psutil
import os
from datetime import datetime, timedelta
from typing import Callable, List, Tuple

import redis
from pymongo import MongoClient, InsertOne
from cassandra.cluster import Cluster
from cassandra.query import BatchStatement, BatchType
from neo4j import GraphDatabase

# ─── Utilitaires de mesure ────────────────────────────────────────────────────

def measure_latency(fn: Callable, iterations: int = 1000) -> dict:
    """
    Exécuter fn iterations fois et retourner les statistiques de latence
    """
    latencies = []
    for _ in range(iterations):
        start = time.perf_counter()
        fn()
        latencies.append((time.perf_counter() - start) * 1000)  # en ms

    latencies.sort()
    return {
        "mean_ms":       statistics.mean(latencies),
        "p50_ms":        latencies[int(0.50 * len(latencies))],
        "p95_ms":        latencies[int(0.95 * len(latencies))],
        "p99_ms":        latencies[int(0.99 * len(latencies))],
        "max_ms":        max(latencies),
        "throughput_rps": 1000 / statistics.mean(latencies),
    }


def measure_resource_usage(fn: Callable) -> dict:
    """Mesurer CPU et mémoire pendant l'exécution de fn"""
    process = psutil.Process(os.getpid())
    mem_before = process.memory_info().rss / 1024 / 1024  # MB
    cpu_before = psutil.cpu_percent(interval=None)

    start = time.perf_counter()
    fn()
    elapsed = time.perf_counter() - start

    mem_after = process.memory_info().rss / 1024 / 1024
    cpu_after = psutil.cpu_percent(interval=None)

    return {
        "elapsed_s":    elapsed,
        "mem_delta_mb": mem_after - mem_before,
        "cpu_pct":      (cpu_before + cpu_after) / 2,
    }


def print_results(name: str, results: dict):
    print(f"\n{'='*50}")
    print(f" {name}")
    print(f"{'='*50}")
    for k, v in results.items():
        print(f"  {k:25s}: {v:.2f}")


def random_string(length: int = 32) -> str:
    return "".join(random.choices(string.ascii_lowercase, k=length))


def random_record(i: int) -> dict:
    """Génère un enregistrement réaliste (event IoT-like)"""
    return {
        "id":          i,
        "sensor_id":   f"sensor_{random.randint(1, 1000)}",
        "timestamp":   (datetime(2024, 1, 1) + timedelta(seconds=i)).isoformat(),
        "temperature": round(random.uniform(-10, 45), 2),
        "humidity":    round(random.uniform(0, 100), 2),
        "value":       random.randint(0, 10_000),
        "tags":        [random_string(8) for _ in range(3)],
    }


# ─── Ex1 : Benchmark Écriture ─────────────────────────────────────────────────

def benchmark_write_redis(n: int = 100_000) -> dict:
    """
    Insérer n enregistrements dans Redis avec pipeline et mesurer le débit.
    Stockage : hash (données structurées) + sorted set (index temporel).
    """
    r = redis.Redis(host='localhost', port=6379, decode_responses=True)
    r.flushdb()

    latencies = []
    batch_size = 500

    start_total = time.perf_counter()
    for batch_start in range(0, n, batch_size):
        t0 = time.perf_counter()
        pipe = r.pipeline(transaction=False)   # pipeline non-transactionnel → max débit

        for i in range(batch_start, min(batch_start + batch_size, n)):
            rec = random_record(i)
            pipe.hset(f"record:{i}", mapping={
                "sensor_id":   rec["sensor_id"],
                "timestamp":   rec["timestamp"],
                "temperature": rec["temperature"],
                "humidity":    rec["humidity"],
                "value":       rec["value"],
            })
            # Index trié par valeur pour les range queries (Ex2)
            pipe.zadd("records:by_value", {f"record:{i}": rec["value"]})

        pipe.execute()
        latencies.append((time.perf_counter() - t0) * 1000)

    total = time.perf_counter() - start_total
    latencies.sort()

    return {
        "total_records":      n,
        "total_s":            total,
        "throughput_rps":     n / total,
        "batch_p50_ms":       latencies[len(latencies) // 2],
        "batch_p95_ms":       latencies[int(0.95 * len(latencies))],
        "batch_p99_ms":       latencies[int(0.99 * len(latencies))],
    }


def benchmark_write_mongodb(n: int = 100_000) -> dict:
    """
    Insérer n documents dans MongoDB avec bulk_write (unordered) et mesurer le débit.
    """
    client = MongoClient("mongodb://admin:admin123@localhost:27017/")
    db = client["benchmark"]
    col = db["records"]
    col.drop()
    col.create_index("sensor_id")
    col.create_index("timestamp")

    latencies = []
    batch_size = 1000

    start_total = time.perf_counter()
    for batch_start in range(0, n, batch_size):
        t0 = time.perf_counter()
        ops = [
            InsertOne(random_record(i))
            for i in range(batch_start, min(batch_start + batch_size, n))
        ]
        col.bulk_write(ops, ordered=False)   # ordered=False → parallélisme interne
        latencies.append((time.perf_counter() - t0) * 1000)

    total = time.perf_counter() - start_total
    latencies.sort()

    client.close()
    return {
        "total_records":  n,
        "total_s":        total,
        "throughput_rps": n / total,
        "batch_p50_ms":   latencies[len(latencies) // 2],
        "batch_p95_ms":   latencies[int(0.95 * len(latencies))],
        "batch_p99_ms":   latencies[int(0.99 * len(latencies))],
    }


def benchmark_write_cassandra(n: int = 100_000) -> dict:
    """
    Insérer n rows dans Cassandra avec UNLOGGED BATCH et mesurer le débit.
    """
    cluster = Cluster(['localhost'])
    session = cluster.connect()

    # Préparer le keyspace et la table
    session.execute("""
        CREATE KEYSPACE IF NOT EXISTS benchmark
        WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1}
    """)
    session.set_keyspace("benchmark")
    session.execute("DROP TABLE IF EXISTS records")
    session.execute("""
        CREATE TABLE records (
            sensor_id   TEXT,
            ts          TIMESTAMP,
            id          INT,
            temperature DOUBLE,
            humidity    DOUBLE,
            value       INT,
            PRIMARY KEY (sensor_id, ts)
        ) WITH CLUSTERING ORDER BY (ts DESC)
    """)

    insert_stmt = session.prepare("""
        INSERT INTO records (sensor_id, ts, id, temperature, humidity, value)
        VALUES (?, ?, ?, ?, ?, ?)
    """)

    latencies = []
    batch_size = 200   # Cassandra recommande des petits batchs (<5 KB chacun)
    base_dt = datetime(2024, 1, 1)

    start_total = time.perf_counter()
    for batch_start in range(0, n, batch_size):
        t0 = time.perf_counter()
        batch = BatchStatement(batch_type=BatchType.UNLOGGED)  # UNLOGGED = max performance

        for i in range(batch_start, min(batch_start + batch_size, n)):
            rec = random_record(i)
            batch.add(insert_stmt, (
                rec["sensor_id"],
                base_dt + timedelta(seconds=i),
                i,
                rec["temperature"],
                rec["humidity"],
                rec["value"],
            ))

        session.execute(batch)
        latencies.append((time.perf_counter() - t0) * 1000)

    total = time.perf_counter() - start_total
    latencies.sort()

    cluster.shutdown()
    return {
        "total_records":  n,
        "total_s":        total,
        "throughput_rps": n / total,
        "batch_p50_ms":   latencies[len(latencies) // 2],
        "batch_p95_ms":   latencies[int(0.95 * len(latencies))],
        "batch_p99_ms":   latencies[int(0.99 * len(latencies))],
    }


def benchmark_write_neo4j(n: int = 100_000) -> dict:
    """
    Insérer n nœuds dans Neo4j via UNWIND (batch Cypher) et mesurer le débit.
    """
    driver = GraphDatabase.driver("bolt://localhost:7687", auth=("neo4j", "neo4j123"))

    with driver.session() as session:
        session.run("MATCH (n:Record) DETACH DELETE n")
        session.run("CREATE INDEX record_id IF NOT EXISTS FOR (r:Record) ON (r.id)")

    latencies = []
    batch_size = 500

    start_total = time.perf_counter()
    for batch_start in range(0, n, batch_size):
        t0 = time.perf_counter()
        records = [random_record(i) for i in range(batch_start, min(batch_start + batch_size, n))]

        with driver.session() as session:
            session.run("""
                UNWIND $rows AS row
                CREATE (:Record {
                    id:          row.id,
                    sensor_id:   row.sensor_id,
                    timestamp:   row.timestamp,
                    temperature: row.temperature,
                    humidity:    row.humidity,
                    value:       row.value
                })
            """, rows=records)

        latencies.append((time.perf_counter() - t0) * 1000)

    total = time.perf_counter() - start_total
    latencies.sort()

    driver.close()
    return {
        "total_records":  n,
        "total_s":        total,
        "throughput_rps": n / total,
        "batch_p50_ms":   latencies[len(latencies) // 2],
        "batch_p95_ms":   latencies[int(0.95 * len(latencies))],
        "batch_p99_ms":   latencies[int(0.99 * len(latencies))],
    }


# ─── Ex2 : Benchmark Lecture ─────────────────────────────────────────────────

def benchmark_read_redis(iterations: int = 10_000) -> dict:
    """
    3 types de requêtes :
      - Point lookup  : HGETALL record:<id>
      - Range query   : ZRANGEBYSCORE par valeur
      - Complex query : pipeline multi-get (10 clés en une fois)
    """
    r = redis.Redis(host='localhost', port=6379, decode_responses=True)
    max_id = r.zcard("records:by_value") - 1
    if max_id < 0:
        print("  ⚠  Redis vide — lancez d'abord le benchmark écriture")
        return {}

    # 1. Point lookup
    def point_lookup():
        r.hgetall(f"record:{random.randint(0, max_id)}")

    # 2. Range query (ZRANGEBYSCORE sur valeur numérique)
    def range_query():
        lo = random.randint(0, 9_000)
        r.zrangebyscore("records:by_value", lo, lo + 1_000, start=0, num=100)

    # 3. Complex : pipeline multi-get (10 clés simultanées)
    def complex_query():
        ids = random.sample(range(0, max_id + 1), k=10)
        pipe = r.pipeline(transaction=False)
        for i in ids:
            pipe.hgetall(f"record:{i}")
        pipe.execute()

    return {
        "point_lookup":  measure_latency(point_lookup, iterations),
        "range_query":   measure_latency(range_query, iterations),
        "complex_query": measure_latency(complex_query, iterations),
    }


def benchmark_read_mongodb(iterations: int = 10_000) -> dict:
    """
    3 types de requêtes :
      - Point lookup  : find_one par _id
      - Range query   : find sur plage temporelle
      - Complex query : aggregate pipeline (groupe + avg par sensor_id)
    """
    client = MongoClient("mongodb://admin:admin123@localhost:27017/")
    col = client["benchmark"]["records"]

    # Récupérer des ids existants pour le point lookup
    sample_ids = [doc["_id"] for doc in col.aggregate([{"$sample": {"size": 500}}])]

    # 1. Point lookup
    def point_lookup():
        col.find_one({"_id": random.choice(sample_ids)})

    # 2. Range query (plage temporelle de 1h)
    def range_query():
        base = datetime(2024, 1, 1) + timedelta(hours=random.randint(0, 8759))
        col.find({
            "timestamp": {
                "$gte": base.isoformat(),
                "$lt":  (base + timedelta(hours=1)).isoformat(),
            }
        }).limit(100).to_list(100)

    # 3. Complex : agrégation — température moyenne par capteur (sur 200 docs)
    def complex_query():
        list(col.aggregate([
            {"$sample": {"size": 200}},
            {"$group": {
                "_id":          "$sensor_id",
                "avg_temp":     {"$avg": "$temperature"},
                "max_humidity": {"$max": "$humidity"},
                "count":        {"$sum": 1},
            }},
            {"$sort": {"avg_temp": -1}},
            {"$limit": 10},
        ]))

    results = {
        "point_lookup":  measure_latency(point_lookup, iterations),
        "range_query":   measure_latency(range_query, iterations),
        "complex_query": measure_latency(complex_query, min(iterations, 500)),  # agrégation plus lente
    }
    client.close()
    return results


def benchmark_read_cassandra(iterations: int = 10_000) -> dict:
    """
    3 types de requêtes :
      - Point lookup  : SELECT par partition key (sensor_id + ts)
      - Range query   : SELECT sur plage temporelle pour un capteur
      - Complex query : SELECT avec ALLOW FILTERING (non recommandé en prod, mais utile pour benchmark)
    """
    cluster = Cluster(['localhost'])
    session = cluster.connect("benchmark")

    sensors = [f"sensor_{i}" for i in range(1, 1001)]
    base_dt = datetime(2024, 1, 1)

    pt_stmt = session.prepare(
        "SELECT * FROM records WHERE sensor_id = ? AND ts = ? LIMIT 1"
    )
    range_stmt = session.prepare(
        "SELECT * FROM records WHERE sensor_id = ? AND ts >= ? AND ts <= ? LIMIT 100"
    )

    def point_lookup():
        ts = base_dt + timedelta(seconds=random.randint(0, 99_999))
        session.execute(pt_stmt, (random.choice(sensors), ts))

    def range_query():
        ts_start = base_dt + timedelta(seconds=random.randint(0, 90_000))
        ts_end   = ts_start + timedelta(seconds=3_600)
        session.execute(range_stmt, (random.choice(sensors), ts_start, ts_end))

    def complex_query():
        # Compter les enregistrements d'un capteur
        session.execute(
            "SELECT COUNT(*) FROM records WHERE sensor_id = ?",
            (random.choice(sensors),)
        )

    results = {
        "point_lookup":  measure_latency(point_lookup, iterations),
        "range_query":   measure_latency(range_query, iterations),
        "complex_query": measure_latency(complex_query, iterations),
    }
    cluster.shutdown()
    return results


def benchmark_read_neo4j(iterations: int = 1_000) -> dict:
    """
    3 types de requêtes :
      - Point lookup  : MATCH par id (index)
      - Range query   : MATCH avec filtre sur value
      - Complex query : traversal — trouver les nœuds similaires (même sensor)
    """
    driver = GraphDatabase.driver("bolt://localhost:7687", auth=("neo4j", "neo4j123"))

    def point_lookup():
        with driver.session() as s:
            s.run(
                "MATCH (r:Record {id: $id}) RETURN r",
                id=random.randint(0, 9_999)
            ).data()

    def range_query():
        lo = random.randint(0, 9_000)
        with driver.session() as s:
            s.run(
                "MATCH (r:Record) WHERE r.value >= $lo AND r.value <= $hi RETURN r LIMIT 100",
                lo=lo, hi=lo + 1_000
            ).data()

    def complex_query():
        sid = f"sensor_{random.randint(1, 1000)}"
        with driver.session() as s:
            s.run("""
                MATCH (r:Record {sensor_id: $sid})
                RETURN r.sensor_id, avg(r.temperature) AS avg_temp, count(r) AS cnt
            """, sid=sid).data()

    results = {
        "point_lookup":  measure_latency(point_lookup, iterations),
        "range_query":   measure_latency(range_query, iterations),
        "complex_query": measure_latency(complex_query, iterations),
    }
    driver.close()
    return results


# ─── Ex3 : Charge concurrente ─────────────────────────────────────────────────

def benchmark_concurrent(
    db_fn: Callable,
    n_clients: int = 50,
    requests_per_client: int = 200,
    label: str = "DB",
) -> dict:
    """
    Lance n_clients threads simultanés.
    Chaque thread exécute requests_per_client fois db_fn().
    Mesure la dégradation vs un seul client.
    """
    all_latencies: List[float] = []
    errors: List[int] = [0]
    lock = threading.Lock()

    def worker():
        local_lat = []
        for _ in range(requests_per_client):
            try:
                t0 = time.perf_counter()
                db_fn()
                local_lat.append((time.perf_counter() - t0) * 1000)
            except Exception:
                with lock:
                    errors[0] += 1
        with lock:
            all_latencies.extend(local_lat)

    # Mesure single-client (baseline)
    baseline = measure_latency(db_fn, 200)

    # Charge concurrente
    threads = [threading.Thread(target=worker) for _ in range(n_clients)]
    wall_start = time.perf_counter()
    for t in threads:
        t.start()
    for t in threads:
        t.join()
    wall_elapsed = time.perf_counter() - wall_start

    total_requests = n_clients * requests_per_client - errors[0]
    all_latencies.sort()

    return {
        "label":                label,
        "n_clients":            n_clients,
        "total_requests":       total_requests,
        "errors":               errors[0],
        "wall_s":               wall_elapsed,
        "throughput_rps":       total_requests / wall_elapsed,
        "baseline_p50_ms":      baseline["p50_ms"],
        "concurrent_p50_ms":    all_latencies[len(all_latencies) // 2] if all_latencies else -1,
        "concurrent_p95_ms":    all_latencies[int(0.95 * len(all_latencies))] if all_latencies else -1,
        "concurrent_p99_ms":    all_latencies[int(0.99 * len(all_latencies))] if all_latencies else -1,
        "degradation_factor":   (all_latencies[len(all_latencies) // 2] / baseline["p50_ms"])
                                 if all_latencies and baseline["p50_ms"] > 0 else -1,
    }


# ─── Rapport de recommandation (Ex4) ──────────────────────────────────────────

def print_decision_table(write_results: dict, read_results: dict, concurrent_results: dict):
    """
    Affiche un tableau de décision final avec les métriques collectées.
    """
    dbs = ["redis", "mongodb", "cassandra", "neo4j"]
    labels = {"redis": "Redis", "mongodb": "MongoDB", "cassandra": "Cassandra", "neo4j": "Neo4j"}

    print("\n" + "═" * 80)
    print("  TABLEAU DE DÉCISION — RECOMMANDATION ARCHITECTURALE")
    print("═" * 80)

    header = f"{'Critère':<30}" + "".join(f"{labels[d]:>12}" for d in dbs)
    print(header)
    print("-" * 80)

    def get_write_rps(db):
        r = write_results.get(db, {})
        return f"{r.get('throughput_rps', 0):>10,.0f}" if r else "      N/A"

    def get_read_p50(db, query_type="point_lookup"):
        r = read_results.get(db, {}).get(query_type, {})
        return f"{r.get('p50_ms', 0):>10.2f}" if r else "      N/A"

    def get_concurrent_p50(db):
        r = concurrent_results.get(db, {})
        return f"{r.get('concurrent_p50_ms', 0):>10.2f}" if r else "      N/A"

    def get_degradation(db):
        r = concurrent_results.get(db, {})
        v = r.get('degradation_factor', -1)
        return f"{v:>10.1f}x" if v > 0 else "      N/A"

    rows = [
        ("Débit écriture (rec/s)",       get_write_rps),
        ("Lecture P50 ms (point)",        lambda db: get_read_p50(db, "point_lookup")),
        ("Lecture P50 ms (range)",        lambda db: get_read_p50(db, "range_query")),
        ("Lecture P50 ms (complex)",      lambda db: get_read_p50(db, "complex_query")),
        ("P50 concurrent ms (50 clients)",get_concurrent_p50),
        ("Facteur dégradation",           get_degradation),
    ]

    for label, fn in rows:
        row = f"{label:<30}" + "".join(fn(d) for d in dbs)
        print(row)

    print("-" * 80)
    use_cases = {
        "redis":     "Cache / Sessions",
        "mongodb":   "Documents / API",
        "cassandra": "IoT / Logs",
        "neo4j":     "Graphes / Reco",
    }
    print(f"{'Use case idéal':<30}" + "".join(f"{use_cases[d]:>12}" for d in dbs))
    print("═" * 80)
    print("\n💡 RECOMMANDATIONS :")
    print("  • Redis     → latence sub-ms, idéal pour cache, sessions, pub/sub")
    print("  • MongoDB   → modèle flexible, agrégations puissantes, bon équilibre")
    print("  • Cassandra → écriture massive, scalabilité linéaire, partition key critique")
    print("  • Neo4j     → requêtes relationnelles complexes, traversal de graphe")


# ─── Main ─────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    print("🚀 Benchmark NoSQL - Comparatif des 4 technologies")
    print("=" * 60)

    N = 10_000   # Réduire pour les tests, 100_000 pour la production
    ITER = 1_000  # Itérations pour les benchmarks de lecture

    write_results     = {}
    read_results      = {}
    concurrent_results = {}

    # ── Ex1 : Écriture ────────────────────────────────────────────────────────
    print(f"\n📝 Ex1 — Benchmark Écriture ({N:,} enregistrements)")

    print("  → Redis...")
    try:
        write_results["redis"] = benchmark_write_redis(N)
        print_results("Redis — Écriture", write_results["redis"])
    except Exception as e:
        print(f"  ⚠  Redis non disponible : {e}")

    print("  → MongoDB...")
    try:
        write_results["mongodb"] = benchmark_write_mongodb(N)
        print_results("MongoDB — Écriture", write_results["mongodb"])
    except Exception as e:
        print(f"  ⚠  MongoDB non disponible : {e}")

    print("  → Cassandra...")
    try:
        write_results["cassandra"] = benchmark_write_cassandra(N)
        print_results("Cassandra — Écriture", write_results["cassandra"])
    except Exception as e:
        print(f"  ⚠  Cassandra non disponible : {e}")

    print("  → Neo4j...")
    try:
        write_results["neo4j"] = benchmark_write_neo4j(N)
        print_results("Neo4j — Écriture", write_results["neo4j"])
    except Exception as e:
        print(f"  ⚠  Neo4j non disponible : {e}")

    # ── Ex2 : Lecture ─────────────────────────────────────────────────────────
    print(f"\n📖 Ex2 — Benchmark Lecture ({ITER:,} requêtes / type)")

    print("  → Redis...")
    try:
        read_results["redis"] = benchmark_read_redis(ITER)
        for qtype, stats in read_results["redis"].items():
            print_results(f"Redis — {qtype}", stats)
    except Exception as e:
        print(f"  ⚠  Redis non disponible : {e}")

    print("  → MongoDB...")
    try:
        read_results["mongodb"] = benchmark_read_mongodb(ITER)
        for qtype, stats in read_results["mongodb"].items():
            print_results(f"MongoDB — {qtype}", stats)
    except Exception as e:
        print(f"  ⚠  MongoDB non disponible : {e}")

    print("  → Cassandra...")
    try:
        read_results["cassandra"] = benchmark_read_cassandra(ITER)
        for qtype, stats in read_results["cassandra"].items():
            print_results(f"Cassandra — {qtype}", stats)
    except Exception as e:
        print(f"  ⚠  Cassandra non disponible : {e}")

    print("  → Neo4j...")
    try:
        read_results["neo4j"] = benchmark_read_neo4j(min(ITER, 500))
        for qtype, stats in read_results["neo4j"].items():
            print_results(f"Neo4j — {qtype}", stats)
    except Exception as e:
        print(f"  ⚠  Neo4j non disponible : {e}")

    # ── Ex3 : Charge concurrente ──────────────────────────────────────────────
    print(f"\n⚡ Ex3 — Charge Concurrente (50 clients × 200 requêtes)")

    # Fonctions de lecture point_lookup pour chaque base
    def redis_point_lookup():
        r = redis.Redis(host='localhost', port=6379, decode_responses=True)
        r.hgetall(f"record:{random.randint(0, N - 1)}")

    def mongo_point_lookup():
        client = MongoClient("mongodb://admin:admin123@localhost:27017/")
        client["benchmark"]["records"].find_one({"id": random.randint(0, N - 1)})
        client.close()

    for db_label, fn in [
        ("redis",    redis_point_lookup),
        ("mongodb",  mongo_point_lookup),
    ]:
        try:
            print(f"  → {db_label}...")
            concurrent_results[db_label] = benchmark_concurrent(
                fn, n_clients=50, requests_per_client=200, label=db_label
            )
            print_results(f"{db_label} — Concurrent", concurrent_results[db_label])
        except Exception as e:
            print(f"  ⚠  {db_label} non disponible : {e}")

    # ── Ex4 : Tableau de décision ─────────────────────────────────────────────
    print("\n📊 Ex4 — Rapport de Recommandation")
    print_decision_table(write_results, read_results, concurrent_results)

    print("\n✅ Benchmark terminé !")
