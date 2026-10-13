---
name: hpc-jobs
description: Use the HPC tools to query Slurm jobs and read files from PLGrid clusters over SSH. Includes job status queries (live/past, batch/singular) and remote file reading via the hpc_* tool namespace.
---

# HPC Jobs & File Operations

Use these tools to interact with PLGrid HPC clusters via SSH and the Slurm REST API.

## Available Tools

All tools are in the `hpc_*` namespace and connect over SSH using key-based authentication with signed certificates.

### Live Job Queries

**hpc_jobs_status** — List all live Slurm jobs on the cluster

```typescript
hpc_jobs_status({
  host: "ares.cyfronet.pl",        // Optional, defaults to HPC_HOST env
  user: "plgusername",             // Optional, defaults to HPC_USER env
  sshKey: "/path/to/id_rsa",       // Required
  sshCertificate: "/path/to/cert"  // Optional
})
```

Returns job list with states: PENDING, RUNNING, COMPLETED, FAILED, etc.

**hpc_singular_job_status** — Status of a specific live job

```typescript
hpc_singular_job_status({
  host: "ares.cyfronet.pl",
  user: "plgusername",
  jobId: "123456",                 // Required - job ID to query
  sshKey: "/path/to/id_rsa",
  sshCertificate: "/path/to/cert"
})
```

### Past Job Queries

**hpc_past_jobs_status** — List completed jobs within a date range

```typescript
hpc_past_jobs_status({
  host: "ares.cyfronet.pl",
  user: "plgusername",
  dateFrom: "2024-01-01",          // Required - YYYY-MM-DD format
  dateTo: "2024-01-31",            // Required - YYYY-MM-DD format
  sshKey: "/path/to/id_rsa",
  sshCertificate: "/path/to/cert"
})
```

**hpc_past_singular_job_status** — Detailed status of a specific completed job

```typescript
hpc_past_singular_job_status({
  host: "ares.cyfronet.pl",
  user: "plgusername",
  jobId: "123456",                 // Required - past job ID
  sshKey: "/path/to/id_rsa",
  sshCertificate: "/path/to/cert"
})
```

### Remote File Operations

**hpc_file_read** — Read a file from the cluster filesystem over SFTP

```typescript
hpc_file_read({
  host: "ares.cyfronet.pl",
  user: "plgusername",
  remotePath: "/net/scratch/job.out", // Required - absolute or home-relative path
  sshKey: "/path/to/id_rsa",
  sshCertificate: "/path/to/cert"
})
```

Useful for inspecting job output/error logs, config files, or scripts on the cluster.

## Required Arguments

All tools require SSH key-based authentication:

| Argument | Required | Description |
|----------|----------|-------------|
| `host` | Env fallback | Cluster hostname (e.g., "ares.cyfronet.pl") |
| `user` | Env fallback | Cluster username (e.g., "plgusername") |
| `sshKey` | **Always required** | SSH private key path |
| `sshCertificate` | Optional | SSH certificate path (if using cert-based auth) |

Job-specific tools also need:
- `jobId` — For singular job queries
- `dateFrom`, `dateTo` — For past job date range queries
- `remotePath` — For file read operations

## Environment Fallbacks

Set these environment variables to avoid repeating host/user:

```bash
export HPC_HOST="ares.cyfronet.pl"
export HPC_USER="plgusername"
```

Then omit `host` and `user` from tool calls - they'll be pulled from the environment.

## Authentication

The tools use SSH key + signed certificate authentication:
- `sshKey` — Your SSH private key (e.g., `~/.ssh/id_rsa`)
- `sshCertificate` — Optional signed certificate from Cyfronet

For PLGrid clusters, you typically need both an SSH key and a certificate signed by Cyfronet's CA.

## Typical Workflows

### Check running jobs
```
1. hpc_jobs_status({sshKey: "~/.ssh/id_rsa"})
   → Returns list of live jobs with IDs and states
2. hpc_singular_job_status({jobId: "123456", sshKey: "~/.ssh/id_rsa"})
   → Detailed status for specific job
```

### Check job history
```
1. hpc_past_jobs_status({dateFrom: "2024-01-01", dateTo: "2024-01-31", sshKey: "~/.ssh/id_rsa"})
   → List of completed jobs in date range
2. hpc_past_singular_job_status({jobId: "123456", sshKey: "~/.ssh/id_rsa"})
   → Detailed exit code, runtime, resources used
```

### Inspect job output
```
1. hpc_file_read({remotePath: "job.out", sshKey: "~/.ssh/id_rsa"})
   → Read stdout log from cluster
2. hpc_file_read({remotePath: "job.err", sshKey: "~/.ssh/id_rsa"})
   → Read stderr log from cluster
```

## API Version

All tools query Slurm REST API v0.0.39:
- Live jobs: `GET /slurm/v0.0.39/jobs`
- Single job: `GET /slurm/v0.0.39/job/{jobId}`
- Past jobs: `GET /slurmdb/v0.0.39/jobs?...`
- Past single: `GET /slurmdb/v0.0.39/job/{jobId}`

## Troubleshooting

**"No host provided and HPC_HOST not set"** — Set `host` argument or `HPC_HOST` env var.

**"No user provided and HPC_USER not set"** — Set `user` argument or `HPC_USER` env var.

**SSH connection failed** — Verify:
- SSH key path is correct and readable
- Certificate is valid and signed by Cyfronet CA (if required)
- You can SSH to the host manually: `ssh -i key cert user@host`

**File not found** — Verify `remotePath` is absolute or relative to your home directory on the cluster.

## Security Notes

- Never share or commit SSH keys or certificates
- Use environment variables carefully - they may be logged in shell history
- SSH key path must be readable by the OpenCode process
