"""
TP3 - Exercice 2 : Ingestion de données IoT
Use Case : SmartGrid DZ - 10 000 capteurs, 5 minutes de mesures
"""
from cassandra.cluster import Cluster
from cassandra.query import BatchStatement, BatchType
import uuid
import random
from datetime import datetime, timedelta
import time

# Configuration
CASSANDRA_HOST = 'localhost'
KEYSPACE = 'smartgrid'
NB_CAPTEURS = 10000
MINUTES_HISTORIQUE = 5
BATCH_SIZE = 50  # Bonne pratique Cassandra : batches ≤ 50 lignes

WILAYAS = ["Alger", "Oran", "Constantine", "Annaba", "Blida"]
COMMUNES = {
    "Alger": ["Bab Ezzouar", "Hydra", "El Harrach", "Dar El Beida"],
    "Oran": ["Bir El Djir", "Es Senia", "Arzew"],
    "Constantine": ["El Khroub", "Ain Smara", "Hamma Bouziane"],
    "Annaba": ["El Bouni", "El Hadjar", "Seraidi"],
    "Blida": ["Bougara", "Boufarik", "Larbaa"],
}


def connect():
    """Connexion au cluster Cassandra"""
    cluster = Cluster([CASSANDRA_HOST])
    session = cluster.connect(KEYSPACE)
    return session, cluster


def generate_mesure(capteur_id, wilaya, commune, timestamp):
    """Générer une mesure réaliste pour un capteur"""
    tension_base = 220.0  # Volts (réseau algérien)
    tension = round(tension_base + random.gauss(0, 5), 2)
    alerte = tension < 200.0 or tension > 240.0 or random.random() < 0.05

    return {
        "capteur_id": capteur_id,
        "date_jour": timestamp.date(),
        "timestamp": timestamp,
        "wilaya": wilaya,
        "commune": commune,
        "tension_v": tension,
        "courant_a": round(random.uniform(0.5, 15.0), 2),
        "puissance_kw": round(random.uniform(0.1, 3.3), 3),
        "frequence_hz": round(50 + random.gauss(0, 0.1), 2),
        "temperature": round(random.uniform(20, 65), 1),
        "alerte": alerte,
        "code_alerte": "TENSION_ANORMALE" if alerte else None,
    }


def prepare_statements(session):
    """Préparer les requêtes à l'avance (meilleure performance)"""
    insert_mesure = session.prepare("""
        INSERT INTO mesures_par_capteur (
            capteur_id, date_jour, timestamp, wilaya, commune,
            tension_v, courant_a, puissance_kw, frequence_hz,
            temperature, alerte, code_alerte
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        USING TTL 7776000
    """)

    insert_alerte = session.prepare("""
        INSERT INTO alertes_par_wilaya (
            wilaya, date_jour, timestamp, capteur_id,
            code_alerte, description, gravite, resolue
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        USING TTL 31536000
    """)

    return insert_mesure, insert_alerte


def insert_single(session, prepared_stmt, mesure):
    """
    Insérer une seule mesure dans mesures_par_capteur
    Utilise une prepared statement pour éviter le parsing répété.
    """
    session.execute(prepared_stmt, (
        mesure["capteur_id"],
        mesure["date_jour"],
        mesure["timestamp"],
        mesure["wilaya"],
        mesure["commune"],
        mesure["tension_v"],
        mesure["courant_a"],
        mesure["puissance_kw"],
        mesure["frequence_hz"],
        mesure["temperature"],
        mesure["alerte"],
        mesure["code_alerte"],
    ))


def insert_batch(session, prepared_stmt, mesures: list):
    """
    Insérer un batch de mesures de manière efficace.
    Utilise UNLOGGED BATCH pour les séries temporelles :
    - LOGGED = overhead transactionnel inutile ici
    - UNLOGGED = meilleure performance pour des données de même partition
    Batches de max BATCH_SIZE items (bonne pratique Cassandra).
    """
    # Découper en sous-batches de BATCH_SIZE lignes maximum
    for i in range(0, len(mesures), BATCH_SIZE):
        chunk = mesures[i:i + BATCH_SIZE]
        batch = BatchStatement(batch_type=BatchType.UNLOGGED)
        for m in chunk:
            batch.add(prepared_stmt, (
                m["capteur_id"],
                m["date_jour"],
                m["timestamp"],
                m["wilaya"],
                m["commune"],
                m["tension_v"],
                m["courant_a"],
                m["puissance_kw"],
                m["frequence_hz"],
                m["temperature"],
                m["alerte"],
                m["code_alerte"],
            ))
        session.execute(batch)


def run_ingestion(session):
    """
    Générer et insérer NB_CAPTEURS × MINUTES_HISTORIQUE mesures.
    Stratégie :
      1. Générer les capteurs avec leur affectation wilaya/commune
      2. Pour chaque minute des MINUTES_HISTORIQUE dernières minutes,
         insérer toutes les mesures en batches
      3. Insérer aussi les alertes dans alertes_par_wilaya
      4. Mesurer et afficher le débit
    """
    print(f"Démarrage ingestion : {NB_CAPTEURS} capteurs × {MINUTES_HISTORIQUE} min")
    print(f"Total prévu : {NB_CAPTEURS * MINUTES_HISTORIQUE:,} mesures")

    insert_mesure_stmt, insert_alerte_stmt = prepare_statements(session)

    # Générer les capteurs une seule fois
    capteurs = []
    for i in range(NB_CAPTEURS):
        wilaya = random.choice(WILAYAS)
        commune = random.choice(COMMUNES[wilaya])
        capteurs.append({
            "id": uuid.uuid4(),
            "wilaya": wilaya,
            "commune": commune,
        })

    start = time.time()
    nb_alertes = 0
    total_insere = 0

    # Pour chaque minute de l'historique
    for minute_offset in range(MINUTES_HISTORIQUE):
        ts = datetime.now() - timedelta(minutes=minute_offset)

        # Générer toutes les mesures de cette minute
        mesures_minute = []
        alertes_minute = []

        for capteur in capteurs:
            m = generate_mesure(capteur["id"], capteur["wilaya"], capteur["commune"], ts)
            mesures_minute.append(m)

            if m["alerte"]:
                alertes_minute.append(m)

        # Insérer en batches les mesures
        insert_batch(session, insert_mesure_stmt, mesures_minute)

        # Insérer les alertes
        if alertes_minute:
            for alerte in alertes_minute:
                session.execute(insert_alerte_stmt, (
                    alerte["wilaya"],
                    alerte["date_jour"],
                    alerte["timestamp"],
                    alerte["capteur_id"],
                    alerte["code_alerte"],
                    f"Tension anormale : {alerte['tension_v']}V",
                    3 if alerte["tension_v"] < 195 or alerte["tension_v"] > 245 else 2,
                    False,
                ))
            nb_alertes += len(alertes_minute)

        total_insere += len(mesures_minute)

        # Affichage progression
        elapsed = time.time() - start
        print(f"  Minute {minute_offset + 1}/{MINUTES_HISTORIQUE} : "
              f"{total_insere:,} mesures ({elapsed:.1f}s écoulées)")

    elapsed = time.time() - start
    total = NB_CAPTEURS * MINUTES_HISTORIQUE
    print(f"\n✅ {total:,} mesures insérées en {elapsed:.1f}s")
    print(f"   Débit        : {total / elapsed:,.0f} mesures/seconde")
    print(f"   Alertes      : {nb_alertes:,} ({nb_alertes / total * 100:.1f}%)")


if __name__ == "__main__":
    session, cluster = connect()
    run_ingestion(session)
    cluster.shutdown()