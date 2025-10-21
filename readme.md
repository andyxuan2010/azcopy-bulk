## How to use


Blob Storage (SAS token):
```
export SRC_PATH=/mnt/nfs/project-data
export DEST_URL='https://mystorage.blob.core.windows.net/backups?sv=...<SAS>...'
./azcopy_bulk.sh
```

ADLS Gen2:

```
export SRC_PATH=/data
export DEST_URL='https://mydatalake.dfs.core.windows.net/raw/ingest?sv=...<SAS>...'
./azcopy_bulk.sh
```

Tune performance:
```
export CONCURRENCY=64         # or leave auto
export CAP_MBPS=0             # unlimited; set e.g. 400 if you must throttle
export PUT_MD5=true           # store MD5 for later integrity checks
./azcopy_bulk.sh
```

Sync only changes (incremental):
```
export MODE=sync
export DELETE_DEST=false      # set true to delete extras at destination
./azcopy_bulk.sh
```

Include/Exclude patterns:
```
export INCLUDE_PATTERN="*.parquet;*.csv"
export EXCLUDE_PATTERN="*.tmp;*.log"
./azcopy_bulk.sh
```

Dry-run (print command only):
```
export DRY_RUN=true
./azcopy_bulk.sh
```
Pro tips for 1 TB+ jobs

Run from an Azure VM in the same region as the storage account for best throughput and lowest latency/egress.

If your source is NFS-mounted, mount with rsize=65536,wsize=65536,async to avoid a read bottleneck.

Keep an eye on ~/.azcopy/<jobid>/*.log for per-transfer details.

If interrupted, use:
```
azcopy jobs list
azcopy jobs resume <JobId>
```