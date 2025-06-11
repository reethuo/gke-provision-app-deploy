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

