# Multi-DC Cassandra deployment on Kubernetes

## Quick start
#### Create cluster
Cluster has 15 worker nodes, every group of 5 nodes will be labeled with dc=DC{1,2,3}
```bash
konvoy up -y
konvoy apply kubeconfig --force-overwrite
```

#### Deploy Cassandra
Create namespaces and headless services and deploy first Cassandra Stateful Set:
```bash
k apply -f specs/namespaces.yaml -f specs/services.yaml
k apply -f specs/statefulset-dc1.yaml
```
Wait for at least one Pod to come up and deploy other Stateful Sets after that:
```bash
k apply -f specs/statefulset-dc2.yaml -f specs/statefulset-dc3.yaml
```
This sequence is important to have at least one seed node up and running so that other DCs can join and discover
each other.

Once all Stateful Sets are scaled, verify Cassandra deployment by running:
Exec into a pod:
```bash
k exec -ti cassandra-0 -n dc-1 nodetool status
```
Example output:
```bash
Datacenter: DC1
===============
Status=Up/Down
|/ State=Normal/Leaving/Joining/Moving
--  Address          Load       Tokens       Owns (effective)  Host ID                               Rack
UN  192.168.xxx.xxx  87.86 KiB  32           59.6%             81f7f98e-7df7-4d54-9164-f4f18471ac9f  RACK1
UN  192.168.xxx.xxx  87.86 KiB  32           62.1%             10c47914-62a6-4cfc-8a60-82882e94c1e3  RACK1
UN  192.168.xxx.xxx  92.75 KiB  32           65.4%             1c0bf15c-823d-4c64-9c10-dc15602e9143  RACK1
UN  192.168.xxx.xxx  87.8 KiB   32           59.7%             eddc5875-ea48-402d-85b6-7705e388eb3c  RACK1
UN  192.168.xxx.xxx  87.86 KiB  32           53.2%             5d1806e2-4e02-4bac-8092-619921f4eead  RACK1
Datacenter: DC2
===============
Status=Up/Down
|/ State=Normal/Leaving/Joining/Moving
--  Address          Load       Tokens       Owns (effective)  Host ID                               Rack
UN  192.168.xxx.xxx  87.81 KiB  32           53.7%             fc9f2170-9ad4-4983-a2ad-3d1ef339538b  RACK1
UN  192.168.xxx.xxx  87.86 KiB  32           59.1%             1412fb7b-591c-4c7c-b7c9-d83e3fc4de1f  RACK1
UN  192.168.xxx.xxx  87.85 KiB  32           51.2%             54e9b3eb-9a88-4279-b9b0-c000d7ab89a0  RACK1
UN  192.168.xxx.xxx  87.85 KiB  32           63.4%             9b0004f7-3ac0-49a3-8e19-59f740e8a5fa  RACK1
UN  192.168.xxx.xxx  87.85 KiB  32           72.6%             4f4bdc9d-ddee-4f5a-8d79-fd78db1e3b95  RACK1
Datacenter: DC3
===============
Status=Up/Down
|/ State=Normal/Leaving/Joining/Moving
--  Address          Load       Tokens       Owns (effective)  Host ID                               Rack
UN  192.168.xxx.xxx  87.85 KiB  32           57.1%             daab2cf7-ec28-4c07-a8cf-b3b429b9342d  RACK1
UN  192.168.xxx.xxx  87.86 KiB  32           63.7%             0032f27c-26a4-422b-ac06-0725951944fb  RACK1
UN  192.168.xxx.xxx  92.95 KiB  32           58.4%             75c44170-ff33-4f89-a0c9-24d30681d255  RACK1
UN  192.168.xxx.xxx  87.8 KiB   32           64.1%             3facaed4-2b8b-4854-9f86-dc474471832b  RACK1
UN  192.168.xxx.xxx  87.86 KiB  32           56.7%             92523a40-a0d2-4b1b-a9ce-fcd3e9ed3864  RACK1
```

#### Create keyspace with multi-DC replication
Exec into a pod and launch `cqlsh`:
```bash
k exec -ti cassandra-0 -n dc-1 cqlsh
```

Create a keyspace:
```bash
cqlsh> CREATE KEYSPACE multidc WITH REPLICATION = {'class':'NetworkTopologyStrategy', 'DC1': '3', 'DC2': '3', 'DC3': '3'};
cqlsh> describe keyspace multidc;
```

Create a table and insert some dummy data into it:
```bash
cqlsh> CREATE TABLE IF NOT EXISTS multidc.test (id uuid PRIMARY KEY, text text); 
cqlsh> INSERT INTO multidc.test (id, text) VALUES (uuid(), 'record 1');
cqlsh> INSERT INTO multidc.test (id, text) VALUES (uuid(), 'record 2');
cqlsh> INSERT INTO multidc.test (id, text) VALUES (uuid(), 'record 3');
```

Connect to Cassandra pod belonging to another DC and query the data:
```bash
k exec -ti cassandra-0 -n dc-1 cqlsh
cqlsh> SELECT * FROM multidc.test;

 id                                   | text
--------------------------------------+----------
 a2d61665-dfcc-40ef-8900-6fd29d286e06 | record 3
 d0d3cbc4-4314-49a2-8df5-b264bef353ed | record 1
 1bf3bc9b-430f-49c7-ab13-c7592e3cb9a7 | record 2
```

## Stress testing
### Basic
Create a pod using Cassandra Docker image:
```bash
kubectl run stress -ti --rm --image=akirillov/cassandra:3.11.5-k8s-11 --restart=Never --command -- bash
```

The cluster first should be populated by a simple write test
([link](https://docs.datastax.com/en/ddac/doc/datastax_enterprise/tools/toolsCStress.html#toolsCStress__c-stress-options)).
Run write stress test using `cassandra-stress` tool from `/opt/cassandra/tools/bin`:
```bash
/opt/cassandra/tools/bin/cassandra-stress write n=1000000 no-warmup cl=LOCAL_QUORUM -rate threads=50 -schema replication\(strategy=NetworkTopologyStrategy,DC1=3,DC2=3,DC3=3\) keyspace="local_quorum" \
-node cassandra-0.cassandra.dc-1.svc.cluster.local,cassandra-1.cassandra.dc-1.svc.cluster.local,cassandra-2.cassandra.dc-1.svc.cluster.local,cassandra-3.cassandra.dc-1.svc.cluster.local,cassandra-4.cassandra.dc-1.svc.cluster.local
```
Example results:
```
Results:
Op rate                   :    1,036 op/s  [WRITE: 1,036 op/s]
Partition rate            :    1,036 pk/s  [WRITE: 1,036 pk/s]
Row rate                  :    1,036 row/s [WRITE: 1,036 row/s]
Latency mean              :   48.2 ms [WRITE: 48.2 ms]
Latency median            :   14.1 ms [WRITE: 14.1 ms]
Latency 95th percentile   :  103.2 ms [WRITE: 103.2 ms]
Latency 99th percentile   :  206.0 ms [WRITE: 206.0 ms]
Latency 99.9th percentile :  398.7 ms [WRITE: 398.7 ms]
Latency max               :  888.1 ms [WRITE: 888.1 ms]
Total partitions          :  1,000,000 [WRITE: 1,000,000]
Total errors              :          0 [WRITE: 0]
Total GC count            : 0
Total GC memory           : 0.000 KiB
Total GC time             :    0.0 seconds
Avg GC time               :    NaN ms
StdDev GC time            :    0.0 ms
Total operation time      : 00:16:05
```

Run mixed read/write stress:
```bash
/opt/cassandra/tools/bin/cassandra-stress mixed ratio\(write=1,read=3\) n=1000000 no-warmup cl=LOCAL_QUORUM -rate threads=50 -schema replication\(strategy=NetworkTopologyStrategy,DC1=3,DC2=3,DC3=3\) keyspace="local_quorum" \
-node cassandra-0.cassandra.dc-1.svc.cluster.local,cassandra-1.cassandra.dc-1.svc.cluster.local,cassandra-2.cassandra.dc-1.svc.cluster.local,cassandra-3.cassandra.dc-1.svc.cluster.local,cassandra-4.cassandra.dc-1.svc.cluster.local
```
Example results:
```
Results:
Op rate                   :    1,084 op/s  [READ: 813 op/s, WRITE: 271 op/s]
Partition rate            :    1,084 pk/s  [READ: 813 pk/s, WRITE: 271 pk/s]
Row rate                  :    1,084 row/s [READ: 813 row/s, WRITE: 271 row/s]
Latency mean              :   46.1 ms [READ: 48.7 ms, WRITE: 38.2 ms]
Latency median            :   12.7 ms [READ: 14.6 ms, WRITE: 9.1 ms]
Latency 95th percentile   :  102.9 ms [READ: 104.7 ms, WRITE: 98.0 ms]
Latency 99th percentile   :  194.9 ms [READ: 196.6 ms, WRITE: 185.7 ms]
Latency 99.9th percentile :  305.1 ms [READ: 307.2 ms, WRITE: 299.6 ms]
Latency max               :  994.1 ms [READ: 994.1 ms, WRITE: 811.6 ms]
Total partitions          :  1,000,000 [READ: 749,941, WRITE: 250,059]
Total errors              :          0 [READ: 0, WRITE: 0]
Total GC count            : 0
Total GC memory           : 0.000 KiB
Total GC time             :    0.0 seconds
Avg GC time               :    NaN ms
StdDev GC time            :    0.0 ms
Total operation time      : 00:15:22
```

### Comparing Consistency Levels (LOCAL_QUORUM, EACH_QUORUM, QUORUM)
Check `LOCAL_QUORUM` results in the the previous section. The goal is to repeat the stress test with the same parameters
changing only consistency level of operations.

Create a pod using Cassandra Docker image:
```bash
kubectl run stress -ti --rm --image=akirillov/cassandra:3.11.5-k8s-11 --restart=Never --command -- bash
```

Drop keyspace created by the previous test if needed:
```bash
cqlsh -e "DROP KEYSPACE local_quorum;" cassandra-0.cassandra.dc-1.svc.cluster.local
```

Run stress write test first using `EACH_QUORUM`:
```bash
/opt/cassandra/tools/bin/cassandra-stress write n=1000000 no-warmup cl=EACH_QUORUM -rate threads=50 -schema replication\(strategy=NetworkTopologyStrategy,DC1=3,DC2=3,DC3=3\) keyspace="each_quorum" \
-node cassandra-0.cassandra.dc-1.svc.cluster.local,cassandra-1.cassandra.dc-1.svc.cluster.local,cassandra-2.cassandra.dc-1.svc.cluster.local,cassandra-3.cassandra.dc-1.svc.cluster.local,cassandra-4.cassandra.dc-1.svc.cluster.local
```
Example results:
```
Results:
Op rate                   :      582 op/s  [WRITE: 582 op/s]
Partition rate            :      582 pk/s  [WRITE: 582 pk/s]
Row rate                  :      582 row/s [WRITE: 582 row/s]
Latency mean              :   85.8 ms [WRITE: 85.8 ms]
Latency median            :   93.8 ms [WRITE: 93.8 ms]
Latency 95th percentile   :  187.6 ms [WRITE: 187.6 ms]
Latency 99th percentile   :  279.2 ms [WRITE: 279.2 ms]
Latency 99.9th percentile :  404.0 ms [WRITE: 404.0 ms]
Latency max               :  796.4 ms [WRITE: 796.4 ms]
Total partitions          :  1,000,000 [WRITE: 1,000,000]
Total errors              :          0 [WRITE: 0]
Total GC count            : 0
Total GC memory           : 0.000 KiB
Total GC time             :    0.0 seconds
Avg GC time               :    NaN ms
StdDev GC time            :    0.0 ms
Total operation time      : 00:28:37
```

Run mixed read/write stress using `EACH_QUORUM`:
```bash
/opt/cassandra/tools/bin/cassandra-stress mixed ratio\(write=1,read=3\) n=1000000 no-warmup cl=EACH_QUORUM -rate threads=50 -schema replication\(strategy=NetworkTopologyStrategy,DC1=3,DC2=3,DC3=3\) keyspace="each_quorum" \
-node cassandra-0.cassandra.dc-1.svc.cluster.local,cassandra-1.cassandra.dc-1.svc.cluster.local,cassandra-2.cassandra.dc-1.svc.cluster.local,cassandra-3.cassandra.dc-1.svc.cluster.local,cassandra-4.cassandra.dc-1.svc.cluster.local
```
Example results:
```
Results:
Op rate                   :      620 op/s  [READ: 465 op/s, WRITE: 156 op/s]
Partition rate            :      620 pk/s  [READ: 465 pk/s, WRITE: 156 pk/s]
Row rate                  :      620 row/s [READ: 465 row/s, WRITE: 156 row/s]
Latency mean              :   80.6 ms [READ: 81.6 ms, WRITE: 77.6 ms]
Latency median            :   92.3 ms [READ: 92.7 ms, WRITE: 91.2 ms]
Latency 95th percentile   :  185.3 ms [READ: 185.5 ms, WRITE: 185.3 ms]
Latency 99th percentile   :  207.2 ms [READ: 208.0 ms, WRITE: 204.3 ms]
Latency 99.9th percentile :  382.5 ms [READ: 384.0 ms, WRITE: 378.3 ms]
Latency max               :  903.9 ms [READ: 903.9 ms, WRITE: 822.6 ms]
Total partitions          :  1,000,000 [READ: 749,211, WRITE: 250,789]
Total errors              :          0 [READ: 0, WRITE: 0]
Total GC count            : 0
Total GC memory           : 0.000 KiB
Total GC time             :    0.0 seconds
Avg GC time               :    NaN ms
StdDev GC time            :    0.0 ms
Total operation time      : 00:26:52
```

Drop keyspace created by the previous test:
```bash
cqlsh -e "DROP KEYSPACE each_quorum;" cassandra-0.cassandra.dc-1.svc.cluster.local
```

Run stress write test first using `QUORUM`:
```bash
/opt/cassandra/tools/bin/cassandra-stress write n=1000000 no-warmup cl=QUORUM -rate threads=50 -schema replication\(strategy=NetworkTopologyStrategy,DC1=3,DC2=3,DC3=3\) keyspace="quorum" \
-node cassandra-0.cassandra.dc-1.svc.cluster.local,cassandra-1.cassandra.dc-1.svc.cluster.local,cassandra-2.cassandra.dc-1.svc.cluster.local,cassandra-3.cassandra.dc-1.svc.cluster.local,cassandra-4.cassandra.dc-1.svc.cluster.local
```
Example results:
```
Results:
Op rate                   :      734 op/s  [WRITE: 734 op/s]
Partition rate            :      734 pk/s  [WRITE: 734 pk/s]
Row rate                  :      734 row/s [WRITE: 734 row/s]
Latency mean              :   68.0 ms [WRITE: 68.0 ms]
Latency median            :   86.2 ms [WRITE: 86.2 ms]
Latency 95th percentile   :  180.7 ms [WRITE: 180.7 ms]
Latency 99th percentile   :  199.8 ms [WRITE: 199.8 ms]
Latency 99.9th percentile :  395.6 ms [WRITE: 395.6 ms]
Latency max               :  811.6 ms [WRITE: 811.6 ms]
Total partitions          :  1,000,000 [WRITE: 1,000,000]
Total errors              :          0 [WRITE: 0]
Total GC count            : 0
Total GC memory           : 0.000 KiB
Total GC time             :    0.0 seconds
Avg GC time               :    NaN ms
StdDev GC time            :    0.0 ms
Total operation time      : 00:22:42
```

Run mixed read/write stress using `QUORUM`:
```bash
/opt/cassandra/tools/bin/cassandra-stress mixed ratio\(write=1,read=3\) n=1000000 no-warmup cl=QUORUM -rate threads=50 -schema replication\(strategy=NetworkTopologyStrategy,DC1=3,DC2=3,DC3=3\) keyspace="quorum" \
-node cassandra-0.cassandra.dc-1.svc.cluster.local,cassandra-1.cassandra.dc-1.svc.cluster.local,cassandra-2.cassandra.dc-1.svc.cluster.local,cassandra-3.cassandra.dc-1.svc.cluster.local,cassandra-4.cassandra.dc-1.svc.cluster.local
```
Example results:
```
Results:
Op rate                   :      793 op/s  [READ: 595 op/s, WRITE: 198 op/s]
Partition rate            :      793 pk/s  [READ: 595 pk/s, WRITE: 198 pk/s]
Row rate                  :      793 row/s [READ: 595 row/s, WRITE: 198 row/s]
Latency mean              :   63.0 ms [READ: 68.5 ms, WRITE: 46.5 ms]
Latency median            :   86.2 ms [READ: 88.8 ms, WRITE: 14.6 ms]
Latency 95th percentile   :  118.9 ms [READ: 180.0 ms, WRITE: 101.8 ms]
Latency 99th percentile   :  203.8 ms [READ: 207.7 ms, WRITE: 188.1 ms]
Latency 99.9th percentile :  309.1 ms [READ: 313.5 ms, WRITE: 294.6 ms]
Latency max               : 1086.3 ms [READ: 1,086.3 ms, WRITE: 983.0 ms]
Total partitions          :  1,000,000 [READ: 750,563, WRITE: 249,437]
Total errors              :          0 [READ: 0, WRITE: 0]
Total GC count            : 0
Total GC memory           : 0.000 KiB
Total GC time             :    0.0 seconds
Avg GC time               :    NaN ms
StdDev GC time            :    0.0 ms
Total operation time      : 00:21:01
```