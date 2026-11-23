# Labs OpenTelemetry

Labs OpenTelemetry, du socle Collector jusqu'au diagnostic d'incident.

## Programme

Labs à concevoir et rédiger : 1, 3, 4, 5, 6, 7, 10 et 11 (numérotation d'origine conservée).

| Lab | Titre | Contenu |
|---|---|---|
| [lab 1](Lab_01_Socle.md) | Socle (1A, 1B, 1C) | Backend Jaeger/Grafana, premier Collector, processors (batch, filtrage, OTTL) |
| [lab 3](Lab_03_Kubernetes.md) | Kubernetes | Collector en agent et gateway (Helm), OTel Operator et auto-instrumentation par annotation |
| [lab 4](Lab_04_Ansible_Jinja2.md) | Ansible + Jinja2 | Déploiement du Collector sur VM Linux, puis modification de la configuration |
| [lab 5](lab05-nodejs-nginx/) | Node.js + Nginx | Auto-instrumentation, export OTLP vers Jaeger, trace de bout en bout |
| [lab 6](lab06-java-python-dotnet/) | Java, Python et .NET | Auto-instrumentation sur Linux |
| [lab 7](Lab_07_Instrumentation_Manuelle.md) | Instrumentation manuelle | Spans et attributs custom, propagation, corrélation logs/traces |
| [lab 10](lab10-exploitation/) | Exploitation | Supervision du Collector, dépannage de pipeline, export OTLP vers le backend du client |
| [lab 11](lab11-diagnostic-incident/) | Diagnostic d'incident | OpenTelemetry Demo (feature flags) |
