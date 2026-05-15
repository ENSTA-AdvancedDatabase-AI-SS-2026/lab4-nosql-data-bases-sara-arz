# Guide d'Installation — Environnement NoSQL

## Option 1 : Docker (Recommandé)

### Prérequis
```bash
# Vérifier Docker
docker --version    # >= 20.x
docker compose version  # >= 2.x

# Vérifier la RAM disponible (minimum 4 Go)
free -h   # Linux
# ou Task Manager > Performance > Memory (Windows)
```

### Démarrage

```bash
# Cloner votre repo GitHub Classroom
git clone https://github.com/VOTRE_ORG/VOTRE_REPO.git
cd nosql-tp-chapter4

# Démarrer tous les services
docker compose up -d

# Vérifier que tout est up
docker compose ps

# Les services démarrent sur :
# Redis     : localhost:6379   (UI: http://localhost:8001)
# MongoDB   : localhost:27017  (UI: http://localhost:8081)
# Cassandra : localhost:9042
# Neo4j     : localhost:7474   (Bolt: localhost:7687)
```

### Connexion à chaque base

```bash
# Redis
docker exec -it nosql_redis redis-cli
> PING   # Réponse attendue : PONG

# MongoDB
docker exec -it nosql_mongodb mongosh -u admin -p admin123
> use medical_db

# Cassandra (attendre 60s au premier démarrage)
docker exec -it nosql_cassandra cqlsh
> DESCRIBE keyspaces;

# Neo4j
# Ouvrir http://localhost:7474 dans le navigateur
# Login : neo4j / password123
```

## Option 2 : Installation Locale (si Docker non disponible)

### Redis
```bash
# Ubuntu/Debian
sudo apt install redis-server
redis-server --daemonize yes

# Windows : Télécharger Redis 7.x depuis https://github.com/tporadowski/redis/releases
```

### MongoDB
```bash
# Ubuntu : https://www.mongodb.com/docs/manual/tutorial/install-mongodb-on-ubuntu/
sudo systemctl start mongod
```

### Python — Dépendances

```bash
# Créer un environnement virtuel
python -m venv venv
source venv/bin/activate  # Linux/Mac
venv\Scripts\activate     # Windows

# Installer les dépendances
pip install redis pymongo cassandra-driver neo4j pytest
```

## Dépannage

### Cassandra ne démarre pas
```bash
# Augmenter la mémoire dans docker-compose.yml
# MAX_HEAP_SIZE: 512M → 1G

# Vérifier les logs
docker compose logs cassandra | tail -50
```

### Neo4j — Erreur APOC
```bash
# Vérifier que le plugin est téléchargé
docker exec nosql_neo4j ls /var/lib/neo4j/plugins/
```

### Port déjà utilisé
```bash
# Trouver le processus utilisant le port
sudo lsof -i :27017  # Linux
netstat -ano | findstr 27017  # Windows
```
