# LeaderWorkerSet (LWS) Tests

Tests to validate that the LeaderWorkerSet operator is working correctly.

## Available Tests

| Test | File | Purpose |
|------|------|---------|
| Ring Test | `lws-ring-test.yaml` | Basic LWS validation - leader/worker topology and connectivity |
| Network Test | `lws-network-test.yaml` | Network bandwidth test with iperf3/ping (credit: David Whyte-Gray) |

---

# Ring Test (lws-ring-test.yaml)

A simple test to validate that the LeaderWorkerSet operator is working correctly.

## What This Tests

1. **LWS creates correct pod topology** - Leader pod + worker pods
2. **Leader address injection** - Workers can discover leader via `LWS_LEADER_ADDRESS`
3. **Network connectivity** - Workers can HTTP call the leader
4. **Group coordination** - All workers register with leader

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    LeaderWorkerSet                          │
│                    name: ring-test                          │
│                    replicas: 1 (one group)                  │
│                    size: 4 (1 leader + 3 workers)           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   ┌─────────────┐                                          │
│   │   LEADER    │  ← ring-test-0 (worker-index: 0)         │
│   │  Port 8080  │                                          │
│   │             │  Endpoints:                               │
│   │  - /health  │   - Returns status + registered workers  │
│   │  - /register│   - Workers call this to register        │
│   │  - /workers │   - Lists all registered worker IPs      │
│   └──────▲──────┘                                          │
│          │                                                  │
│          │ HTTP calls to register                           │
│          │                                                  │
│   ┌──────┴──────┐  ┌─────────────┐  ┌─────────────┐       │
│   │  WORKER 1   │  │  WORKER 2   │  │  WORKER 3   │       │
│   │ Port 8080   │  │ Port 8080   │  │ Port 8080   │       │
│   │             │  │             │  │             │       │
│   │ ring-test-0-1│ │ring-test-0-2│ │ring-test-0-3│       │
│   │ worker-idx:1│  │worker-idx:2 │  │worker-idx:3 │       │
│   └─────────────┘  └─────────────┘  └─────────────┘       │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## How LWS Provides Leader Discovery

LWS automatically injects metadata into each pod:

| Mechanism | Type | Value |
|-----------|------|-------|
| `leaderworkerset.sigs.k8s.io/leader-address` | Annotation | Leader's pod IP |
| `leaderworkerset.sigs.k8s.io/group-index` | Label | Which replica group (0, 1, 2...) |
| `leaderworkerset.sigs.k8s.io/worker-index` | Label | Position in group (0=leader, 1,2,3=workers) |

## Prerequisites

- LeaderWorkerSet operator installed (via lws-operator-chart)
- kubectl configured to access your cluster

## Deploy

```bash
kubectl apply -f lws-ring-test.yaml
```

## Verify

### 1. Watch pods come up

```bash
kubectl get pods -n lws-test -w
```

Expected output:
```
NAME             READY   STATUS    RESTARTS   AGE
ring-test-0      1/1     Running   0          30s   # Leader
ring-test-0-1    1/1     Running   0          30s   # Worker 1
ring-test-0-2    1/1     Running   0          30s   # Worker 2
ring-test-0-3    1/1     Running   0          30s   # Worker 3
```

### 2. Check leader logs (see workers registering)

```bash
kubectl logs -n lws-test ring-test-0
```

Expected output:
```
==========================================
  LEADER STARTING
==========================================
Hostname: ring-test-0
IP: 10.224.0.50
Group Index: 0
Worker Index: 0

Starting leader HTTP server on port 8080...
[REGISTERED] Worker from 10.224.0.51
[REGISTERED] Worker from 10.224.0.52
[REGISTERED] Worker from 10.224.0.53
```

### 3. Check worker logs (see leader discovery)

```bash
kubectl logs -n lws-test ring-test-0-1
```

Expected output:
```
==========================================
  WORKER STARTING
==========================================
Hostname: ring-test-0-1
IP: 10.224.0.51
Group Index: 0
Worker Index: 1
Leader Address: 10.224.0.50

Waiting for leader at 10.224.0.50:8080...
Leader is ready!

Registering with leader...
  Result: registered 10.224.0.51

Leader status:
{
    "status": "healthy",
    "role": "leader",
    "hostname": "ring-test-0",
    "registered_workers": ["10.224.0.51"]
}
```

### 4. Query leader status (see all registered workers)

```bash
kubectl exec -n lws-test ring-test-0 -- curl -s localhost:8080/health
```

Expected output:
```json
{
  "status": "healthy",
  "role": "leader",
  "hostname": "ring-test-0",
  "ip": "10.224.0.50",
  "group_index": "0",
  "worker_index": "0",
  "registered_workers": [
    "10.224.0.51",
    "10.224.0.52",
    "10.224.0.53"
  ]
}
```

## Success Criteria

- All 4 pods are Running and Ready
- Leader logs show 3 workers registered
- Worker logs show successful leader discovery and registration
- Leader `/health` endpoint lists all 3 worker IPs

## Cleanup

```bash
kubectl delete -f lws-ring-test.yaml
```

## Troubleshooting

### Pods stuck in Pending
- Check if LWS operator is running: `kubectl get pods -n openshift-lws-operator`
- Check LWS operator logs: `kubectl logs -n openshift-lws-operator -l app.kubernetes.io/name=lws`

### Workers can't reach leader
- Check if leader pod IP is correctly injected: `kubectl get pod ring-test-0-1 -n lws-test -o jsonpath='{.metadata.annotations}'`
- Check network policies: `kubectl get networkpolicy -n lws-test`

### LWS not creating pods
- Check LeaderWorkerSet status: `kubectl describe lws ring-test -n lws-test`
- Check LWS controller logs for errors
