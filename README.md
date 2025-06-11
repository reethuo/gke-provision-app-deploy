In hello-world folder,deployment file
LABELS:
 RELEASE: KUBE-PROMETEUS-STACK
is to match labels with service monitor
Service monitor yaml file in helloworld folder has same labels.

We are deploying an app that should be monitored by the existing KUBE-PROMETEUS-STACK,keep the label 
RELEASE: KUBE-PROMETEUS-STACK

A ServiceMonitor is a Custom Resource Definition (CRD) used by the Prometheus Operator to tell Prometheus which Kubernetes services to scrape metrics from.
Instead of manually editing Prometheus configs, you create a ServiceMonitor, and Prometheus automatically finds it—if its labels match what Prometheus is watching for.

If you change or remove this, Prometheus won’t find it unless you also modify the prometheus.prometheusSpec.serviceMonitorSelector

SERVICEMONITORSELECTOR: {} in prometheus-values.yaml 
This configuration appears in a Prometheus Custom Resource when you deploy Prometheus via the Prometheus Operator. It controls which ServiceMonitor objects Prometheus should discover and scrape.
It means:
Prometheus will select all ServiceMonitor objects in the same namespace, regardless of their labels.
This is the widest/most permissive configuration — Prometheus will try to scrape any ServiceMonitor it can find in its namespace.

servicemonitor:
ENDPOINTS:
    - PORT: HTTP
      INTERVAL: 15S
      PATH: /METRICS

port: should match the name of the port in your Service

service
PORTS:
    - PROTOCOL: TCP
      PORT: 8082
      TARGETPORT: 8082
      NAME: HTTP

interval: how often Prometheus scrapes metrics (every 15 seconds).

path: where your app exposes metrics. Most apps expose at /metrics.

NAMESPACESELECTOR:
  MATCHNAMES:
    - {{ .RELEASE.NAMESPACE }}

This allows cross-namespace discovery, but here it restricts Prometheus to scrape from the same namespace your app is deployed in.

IMAGE:
  REPOSITORY: TRIALQ2A49V.JFROG.IO/YOUR-HELLO-WORLD-REPO/HELLO-WORLD
  TAG: LATEST
  PULLPOLICY: IFNOTPRESENT
  PULLSECRET: JFROG-SECRET

pullPolicy: Pulls image only if not present locally.

pullSecret: Uses Kubernetes secret jfrog-secret to authenticate with JFrog.

MONITOR:
    ENABLED: TRUE 

enabled: true – Creates a ServiceMonitor object, used by the Prometheus Operator.

DEFAULTRULES:
  CREATE: TRUE

Instructs the chart to create default alerting & recording rules (usually provided by kube-prometheus-stack).
in a Helm chart like kube-prometheus-stack, it tells the chart to install a comprehensive set of prebuilt Prometheus alerting and recording rules, which are known as the default rules.

They are predefined Prometheus rules provided by the kube-prometheus-stack to:

Monitor the health of your Kubernetes cluster

Detect common failures and issues early

Generate alerts for operational problems

Optimize queries using recording rules

📊 Categories of Default Rules
Here's what these default rules typically include:

✅ Alerting Rules (examples)
These are used to trigger alerts when something goes wrong.

| Alert Name                        | What it Detects                          |
| --------------------------------- | ---------------------------------------- |
| `KubePodCrashLooping`             | Pod is crash-looping frequently          |
| `KubeDeploymentReplicasMismatch`  | Deployment not matching desired replicas |
| `KubeMemoryOvercommit`            | Node memory overcommitment               |
| `NodeFilesystemAlmostFull`        | Disk is nearly full                      |
| `KubeNodeNotReady`                | Node is in `NotReady` status             |
| `KubeDaemonSetRolloutStuck`       | DaemonSet rollout is stuck               |
| `KubeJobFailed`                   | Job has failed                           |
| `KubeStatefulSetReplicasMismatch` | StatefulSet replicas mismatch            |


These alerts often use labels like:

severity: warning
severity: critical

📝 Recording Rules
These precompute expensive queries for performance and reuse.

Examples:

| Rule Name                                    | What it Records                         |
| -------------------------------------------- | --------------------------------------- |
| `instance:node_cpu:rate:sum`                 | Precomputed CPU usage per instance      |
| `namespace:container_memory_usage_bytes:sum` | Memory usage per namespace              |
| `cluster:namespace_cpu:rate:sum`             | CPU usage per namespace for the cluster |

Recording rules reduce dashboard/query load and speed up repeated queries.

📁 Where do these rules come from?
They are defined in:

kube-prometheus

Or under: charts/kube-prometheus-stack/templates/prometheus/rules/*.yaml

When you set defaultRules.create: true, these YAML files are rendered and applied automatically.

🛠️ Final Tip
To view which rules are installed:

kubectl get prometheusrules -A

To inspect them:

kubectl -n <namespace> get prometheusrule <name> -o yaml

📊 kubeStateMetrics

KUBESTATEMETRICS:
  METRICLABELSALLOWLIST:
    - PODS=[*]

Allows all pod labels to be included in metrics exported by kube-state-metrics

This configures kube-state-metrics (KSM) to export all labels from all pods as Prometheus metric labels — it doesn't filter metrics, but rather controls what labels get attached to the exported metrics.

✅ So what does it actually do?
It tells kube-state-metrics:

"For all Pod metrics, include all labels ([*]) that exist on the Pod as part of the metric's labels."

So if your pod has:
metadata:
  labels:
    app: hello-world
    team: payments

Then metrics like kube_pod_info will include:

kube_pod_info{pod="hello-world", app="hello-world", team="payments", ...}

Without metricLabelsAllowlist, only a few standard labels are exposed (like pod, namespace), and custom labels like team=payments are dropped.

🔁 How it works together:
App is deployed using the image from JFrog, exposed via LoadBalancer on port 8082.

The app exposes metrics at /metrics.

A ServiceMonitor is created to allow Prometheus Operator to scrape those metrics.

Prometheus sends metrics to Grafana Cloud via remoteWrite.

You can now query your app metrics in Grafana.

Prometheus Alertmanager configuration, and its purpose is to send alerts to Grafana Cloud via webhook.

GLOBAL:
  RESOLVE_TIMEOUT: 5M

This sets how long Alertmanager waits for an alert to be resolved before declaring it "resolved" (useful in flapping scenarios).

Alertmanager will send alert notifications to a Grafana Cloud Alertmanager endpoint via webhook.

Prometheus generates alerts based on rules.

Alertmanager handles the delivery of those alerts.

alertmanager config tells Alertmanager to send all alerts to Grafana Cloud Alerting using webhook + authentication.

GLOBAL:
  SECURITY:
    ALLOWINSECUREIMAGES: TRUE

🔍 What it does:
allowInsecureImages: true means:

The system permits pulling or running container images that are not from a verified or trusted source.

It may skip checks for things like image signatures, secure registries (HTTPS), or other verification mechanisms.

In order to check metrics:

GO TO: ->https://reethu.grafana.net/explore

        ->Open code mode

        ->In PromQL,

          enter the below queries one by one

          -> label_replace(
              sum by(container, namespace) (
               rate(kube_pod_container_status_restarts_total{namespace="hello"}[5m])
              ),
             "pod", "$1", "container", "(.*)"
             )

             hit run query which is in blue color(below share)
           -> kube_pod_container_status_restarts_total

           -> rate(kube_pod_container_status_restarts_total[5m])

           -> count by(namespace) (rate(kube_pod_container_status_restarts_total[5m]))

           -> rate(kube_pod_container_status_restarts_total[5m])

           -> rate(kube_pod_container_status_restarts_total{namespace="hello"}[5m])

           -> sum by(pod, namespace) (
               rate(kube_pod_container_status_restarts_total{namespace="hello"}[5m])
              ) 
