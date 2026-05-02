# postgres-pgvector-helm

A minimal, opinionated Helm chart for running **PostgreSQL 17 with the [pgvector](https://github.com/pgvector/pgvector) extension** on a local Kubernetes cluster (k3d or Docker Desktop).

No Bitnami, no bloat â just the official `pgvector/pgvector:pg17` image and a handful of templates you can read in five minutes.

---

## Prerequisites

| Tool | Minimum version | Install |
|---|---|---|
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | 1.28+ | `brew install kubectl` |
| [Helm](https://helm.sh/docs/intro/install/) | 3.12+ | `brew install helm` |
| [k3d](https://k3d.io) **or** Docker Desktop K8s | k3d 5+ | `brew install k3d` |

> Only one of k3d or Docker Desktop is required. The setup script auto-detects which you have.

---

## Quick start

```bash
git clone https://github.com/Vhunon/postgres-pgvector-helm.git
cd postgres-pgvector-helm
chmod +x setup.sh teardown.sh
./setup.sh
```

That's it. The script will:
1. Create a k3d cluster called `pgvector-dev` (if k3d is available and the cluster doesn't exist yet).
2. Run `helm install` with the defaults in `chart/values.yaml`.
3. Print a ready-to-use connection string.

### Manual install (no setup script)

```bash
helm install pgvector-dev ./chart
```

---

## Connecting

### k3d (port already mapped via loadbalancer)

```bash
psql postgresql://appuser:devpassword@localhost:5432/appdb
# or
PGPASSWORD=devpassword psql -h localhost -U appuser -d appdb
```

### Docker Desktop (port-forward required)

```bash
kubectl port-forward svc/pgvector-dev-postgres-pgvector 5432:5432 &
psql postgresql://appuser:devpassword@localhost:5432/appdb
```

### Connection string for your app

```
postgresql://appuser:devpassword@localhost:5432/appdb
```

---

## Verifying pgvector

```sql
-- Check the extension is loaded
SELECT extname, extversion FROM pg_extension WHERE extname = 'vector';

-- Create a table with a vector column
CREATE TABLE items (
  id   bigserial PRIMARY KEY,
  name text,
  embedding vector(3)
);

-- Insert some vectors
INSERT INTO items (name, embedding) VALUES
  ('foo', '[1,2,3]'),
  ('bar', '[4,5,6]');

-- Nearest-neighbour search (L2 distance)
SELECT name, embedding <-> '[1,2,4]' AS distance
FROM items
ORDER BY distance
LIMIT 5;
```

---

## Configuration

Edit `chart/values.yaml` or pass `--set` flags:

```bash
helm install pgvector-dev ./chart \
  --set postgres.database=mydb \
  --set postgres.user=myuser \
  --set postgres.password=supersecret \
  --set persistence.size=5Gi
```

| Key | Default | Description |
|---|---|---|
| `postgres.database` | `appdb` | Database name |
| `postgres.user` | `appuser` | Superuser name |
| `postgres.password` | `devpassword` | Superuser password |
| `persistence.size` | `2Gi` | PVC size |
| `persistence.storageClass` | `""` | StorageClass (blank = cluster default) |
| `service.type` | `NodePort` | Service type |
| `service.nodePort` | _(auto)_ | Pin a specific NodePort (optional) |
| `image.tag` | `pg17` | pgvector image tag |

---

## Teardown

```bash
./teardown.sh
```

The script removes the Helm release, deletes the PVC, and optionally deletes the k3d cluster.

Manual equivalent:

```bash
helm uninstall pgvector-dev
kubectl delete pvc pgvector-dev-postgres-pgvector
# k3d only:
k3d cluster delete pgvector-dev
```

---

## Project structure

```
postgres-pgvector-helm/
âââ README.md
âââ setup.sh                     # one-shot setup
âââ teardown.sh                   # cleanup
âââ chart/
    âââ Chart.yaml
    âââ values.yaml
    âââ templates/
        âââ deployment.yaml        # Deployment + ConfigMap (init SQL) helper templates
        âââ service.yaml
        âââ pvc.yaml
        âââ secret.yaml
```

---

## License

MIT â do whatever you like with this.
