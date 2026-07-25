#!/usr/bin/env python3
import argparse
from mlflow.tracking import MlflowClient


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--model-name", required=True)
    p.add_argument("--version", required=True)
    p.add_argument("--stage", default="Production")
    args = p.parse_args()

    client = MlflowClient()
    client.transition_model_version_stage(
        name=args.model_name,
        version=args.version,
        stage=args.stage,
        archive_existing_versions=True,
    )
    print(f"Promoted {args.model_name} v{args.version} → {args.stage}")


if __name__ == "__main__":
    main()
