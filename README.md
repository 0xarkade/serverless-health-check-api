# Serverless Health Check API

A `/health` endpoint on AWS — **API Gateway → Lambda → DynamoDB** — defined entirely in
Terraform and deployed to two environments (`staging` and `prod`) by GitHub Actions.

> **Status:** this README is written incrementally alongside the code. Sections are filled
> in as the features they describe are introduced. See the commit history for the full story.

## Repository layout

| Path | Purpose |
| --- | --- |
| `bootstrap/` | One-time, human-applied Terraform: remote state backend, GitHub OIDC provider, deploy role. Separate state from `infra/`. |
| `infra/` | The application stack, applied by CI. Root module plus reusable modules. |
| `infra/modules/` | Reusable Terraform modules (KMS, DynamoDB, network, Lambda, API Gateway). |
| `infra/environments/` | Per-environment `.tfvars` files — `staging.tfvars`, `prod.tfvars`. |
| `src/health_check/` | Lambda source code (Python). |
| `scripts/` | Packaging and post-deploy smoke-test helpers. |
| `.github/workflows/` | CI and deployment pipelines. |

## Architecture

_Added in a later commit._

## Prerequisites

_Added in a later commit._

## How the CI/CD pipeline works

_Added in a later commit._

## Deploying the staging environment

_Added in a later commit._

## Testing the endpoint

_Added in a later commit._

## Design choices and assumptions

_Added in a later commit._
