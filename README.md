\# Kubernetes Service Reliability Lab



This lab demonstrates how a Kubernetes rollout can succeed while an application endpoint fails. A deliberately broken release kept `/health` healthy but returned HTTP 503 from `/api/status`. A Kubernetes Job detected the failure, and a manual rollback restored the endpoint. The three test runs were archived in Amazon S3 and analyzed in Databricks.



\## Verified results



| Scenario | Requests | Errors | Error rate | p95 response time |

|---|---:|---:|---:|---:|

| Healthy baseline | 20 | 0 | 0% | 8.32 ms |

| Failing release | 20 | 20 | 100% | 10.25 ms |

| After rollback | 20 | 0 | 0% | 7.93 ms |



These are measurements from a small local demo with 20 requests per scenario.



!\[Databricks dashboard showing error rate and p95 response time by scenario](docs/dashboard.png)



\## Architecture



```mermaid

flowchart LR

&#x20;   A\["API on local Kubernetes"] --> B\["Kubernetes telemetry Job"]

&#x20;   B --> C\["Private Amazon S3 bucket"]

&#x20;   C --> D\["Databricks managed volume"]

&#x20;   D --> E\["Delta table and dashboard"]

```



Terraform provisions the S3 bucket in `us-east-1` with Block Public Access, S3-managed encryption, and a 30-day expiration rule for `telemetry/`. The handoff uses the AWS CLI to download the S3 objects and the Databricks UI to upload them to a managed volume. PySpark reads the JSON Lines files and merges requests into Delta using `(run\_id, request\_number)` as the key.



\## Reproduce the Kubernetes demo



Run the commands from the repository root in PowerShell with Docker running. Run each command in order.



```powershell

kind create cluster --name reliability-lab --wait 5m

docker build -t reliability-api:v1 .

docker build --build-arg APP\_SOURCE=app\_v2.py -t reliability-api:v2 .

kind load docker-image reliability-api:v1 reliability-api:v2 --name reliability-lab

kubectl --context kind-reliability-lab apply -f .\\kubernetes.yaml

kubectl --context kind-reliability-lab rollout status deployment/reliability-api --timeout=120s

kubectl --context kind-reliability-lab apply -f .\\telemetry-job.yaml

kubectl --context kind-reliability-lab wait --for=condition=complete job/telemetry-baseline --timeout=120s

kubectl --context kind-reliability-lab logs job/telemetry-baseline

```



1\. \*\*Baseline.\*\* The Job sends 20 requests and records status, version, and latency as JSON Lines.

2\. \*\*Failure.\*\* Deploy `reliability-api:v2` with `kubectl set image deployment/reliability-api api=reliability-api:v2 --context kind-reliability-lab`. Wait for the rollout, then run a copy of the telemetry Job with `metadata.name` set to `telemetry-failure`.

3\. \*\*Recovery.\*\* Run `kubectl rollout undo deployment/reliability-api --context kind-reliability-lab`. Wait for the rollout, then run a copy of the telemetry Job named `telemetry-recovery`.



The repository includes `baseline.jsonl`, `failure.jsonl`, and `recovery.jsonl` from the verified demo.



\## AWS and Databricks



\- `infra/main.tf` defines the S3 infrastructure. Use an AWS profile authorized for the lab bucket and review `terraform -chdir=infra plan` before applying.

\- Upload the three JSON Lines files to the bucket's `telemetry/` prefix. Download the S3 copies and upload them into a Databricks managed volume.

\- The dashboard groups requests by scenario and shows error rate and p95 response time.

\- To clean up AWS, remove the lab telemetry objects from S3, then review and run `terraform -chdir=infra destroy`.

