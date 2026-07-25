# ${{ values.name }}

${{ values.description }}

Scaffolded from MLOps Platform template (Lab 1 pattern).

## Quick start

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
python train.py
python serve.py
```

## CI/CD

GitHub Actions workflow `ci-lab01.yml` runs on every PR.

## Docs

Registered in Backstage Catalog under system `mlops-labs`.
