# Scripts Directory

Utility scripts for testing and managing the mini-msa services.

## Available Scripts

### test.sh
Integration test script that validates inter-service communication.

**Usage:**
```bash
# Make executable (if needed)
chmod +x scripts/test.sh

# Run directly
./scripts/test.sh

# Or via Makefile
make test
```

**What it tests:**
1. Queue service health check
2. Core service health check
3. Inter-service health verification (core → queue)
4. Job creation via core service
5. Job queue retrieval
6. Job processing
7. User creation with automatic job queueing
8. Final queue status

**Requirements:**
- Services must be running (`make up` or `docker-compose up`)
- `curl` and `jq` installed on host machine
- Port 3001 and 3002 accessible

## Adding New Scripts

Place new utility scripts in this directory and update this README with:
- Script name and purpose
- Usage instructions
- Requirements
- Example output (optional)
