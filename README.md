# Labs OpenTelemetry

Travaux pratiques de la formation OpenTelemetry, du socle Collector jusqu'au diagnostic d'incident.

## Programme

TPs à concevoir et rédiger : 1, 3, 4, 5, 6, 7, 10 et 11 (numérotation d'origine conservée).

| TP | Titre | Contenu | Durée |
|---|---|---|---|
| [TP1](Lab_TP01_Socle.md) | Socle | Backend Jaeger/Grafana, premier Collector, processors (batch, filtrage, OTTL) | 1/4 j |
| [TP3](Lab_TP03_Kubernetes.md) | Kubernetes | Collector en agent et gateway (Helm), OTel Operator et auto-instrumentation par annotation | 1/4 j |
| [TP4](tp04-ansible/) | Ansible + Jinja2 | Déploiement du Collector sur VM Linux, puis modification de la configuration | 1/4 j |
| [TP5](tp05-nodejs-nginx/) | Node.js + Nginx | Auto-instrumentation, export OTLP vers Jaeger, trace de bout en bout | 1/4 j |
| [TP6](tp06-java-python-dotnet/) | Java, Python et .NET | Auto-instrumentation sur Linux | 1/4 j |
| [TP7](tp07-instrumentation-manuelle/) | Instrumentation manuelle | Spans et attributs custom, propagation, corrélation logs/traces | 1/4 j |
| [TP10](tp10-exploitation/) | Exploitation | Supervision du Collector, dépannage de pipeline, export OTLP vers le backend du client | 1/4 j |
| [TP11](tp11-diagnostic-incident/) | Diagnostic d'incident | OpenTelemetry Demo (feature flags) | 1/4 j |
