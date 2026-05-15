"""
TP1 - Exercice 2 : Gestion des sessions utilisateur
Use Case : ShopFast - Sessions avec expiration glissante (sliding TTL)
"""
import redis
import json
import uuid
import time

r = redis.Redis(host='localhost', port=6379, decode_responses=True)

SESSION_TTL = 1800  # 30 minutes en secondes


def create_session(r, user_id: int, user_data: dict, ttl: int = SESSION_TTL) -> str:
    """
    Créer une nouvelle session utilisateur.
    - Génère un token unique (UUID4)
    - Clé Redis : "session:{token}"
    - Stocke user_id + données de session en JSON
    - Applique un TTL de 'ttl' secondes
    - Retourne le token de session
    """
    token = str(uuid.uuid4())
    session_data = {
        "user_id": user_id,
        "created_at": time.time(),
        **user_data
    }
    # SETEX stocke la valeur ET fixe l'expiration atomiquement
    r.setex(f"session:{token}", ttl, json.dumps(session_data))

    # Maintenir un index user → sessions pour pouvoir les lister/invalider
    r.sadd(f"user_sessions:{user_id}", token)

    return token


def get_session(r, token: str) -> dict | None:
    """
    Récupérer les données d'une session.
    Retourner None si la session n'existe pas (expirée ou invalide).
    """
    raw = r.get(f"session:{token}")
    if raw is None:
        return None
    return json.loads(raw)


def renew_session(r, token: str, ttl: int = SESSION_TTL) -> bool:
    """
    Renouveler le TTL d'une session (sliding expiration).
    Chaque requête de l'utilisateur réinitialise le compteur à 30 min.
    Retourner True si la session existe, False sinon.
    """
    # EXPIRE retourne 1 si la clé existe et a été mise à jour, 0 sinon
    result = r.expire(f"session:{token}", ttl)
    return result == 1


def delete_session(r, token: str) -> bool:
    """
    Supprimer une session (déconnexion explicite).
    Retourner True si la session existait.
    """
    # Récupérer le user_id avant suppression pour nettoyer l'index
    raw = r.get(f"session:{token}")
    if raw:
        session_data = json.loads(raw)
        user_id = session_data.get("user_id")
        if user_id:
            r.srem(f"user_sessions:{user_id}", token)

    deleted = r.delete(f"session:{token}")
    return deleted > 0


def get_user_sessions(r, user_id: int) -> list:
    """
    Lister toutes les sessions actives d'un utilisateur.
    (Utile pour la fonctionnalité "déconnecter tous les appareils")
    """
    tokens = r.smembers(f"user_sessions:{user_id}")
    active_sessions = []
    for token in tokens:
        session = get_session(r, token)
        if session:
            active_sessions.append({"token": token, **session})
        else:
            # Nettoyer les tokens expirés de l'index
            r.srem(f"user_sessions:{user_id}", token)
    return active_sessions


def invalidate_all_user_sessions(r, user_id: int) -> int:
    """
    Invalider toutes les sessions d'un utilisateur.
    Cas d'usage : changement de mot de passe, compte compromis.
    Retourner le nombre de sessions supprimées.
    """
    tokens = r.smembers(f"user_sessions:{user_id}")
    count = 0
    for token in tokens:
        if r.delete(f"session:{token}") > 0:
            count += 1
    r.delete(f"user_sessions:{user_id}")
    return count


def get_session_ttl(r, token: str) -> int:
    """Retourner le TTL restant en secondes (-2 si inexistante, -1 si sans expiration)"""
    return r.ttl(f"session:{token}")


if __name__ == "__main__":
    r.flushdb()

    print("=== Test Sessions Utilisateur ===\n")

    # Créer une session
    token = create_session(r, user_id=42, user_data={"username": "amina", "role": "customer"})
    print(f"Session créée : {token}")

    # Lire la session
    session = get_session(r, token)
    print(f"Session data : {session}")
    print(f"TTL initial  : {get_session_ttl(r, token)}s")

    # Simuler un délai puis renouveler
    print("\nSimulation de 2 secondes d'inactivité...")
    time.sleep(2)
    ttl_before = get_session_ttl(r, token)
    renew_session(r, token)
    ttl_after = get_session_ttl(r, token)
    print(f"TTL avant renouvellement : {ttl_before}s → après : {ttl_after}s")

    # Créer une 2ème session (autre appareil)
    token2 = create_session(r, user_id=42, user_data={"username": "amina", "role": "customer", "device": "mobile"})
    print(f"\nSessions actives pour user 42 : {len(get_user_sessions(r, 42))}")

    # Supprimer une session
    delete_session(r, token)
    print(f"Après déconnexion : sessions actives = {len(get_user_sessions(r, 42))}")

    # Test session inexistante
    result = get_session(r, "token-inexistant")
    print(f"Session inexistante : {result}")

    # Invalider toutes les sessions
    n = invalidate_all_user_sessions(r, 42)
    print(f"\nSessions invalidées : {n}")
    print(f"Sessions restantes  : {len(get_user_sessions(r, 42))}")
