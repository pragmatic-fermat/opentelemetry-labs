# Labs OpenTelemetry

Labs OpenTelemetry, du socle Collector jusqu'au diagnostic d'incident.

## Programme

Labs à concevoir et rédiger : 1, 3, 4, 5, 6, 7, 10 et 11 (numérotation d'origine conservée).

| Lab | Titre | Contenu |
|---|---|---|
| [lab 1](Lab_01_Socle.md) | Socle, premier **collector** et processors | Trois parties 1A, 1B, 1C : backend Jaeger/Grafana, premier **collector**, processors (batch, filtrage, OTTL) |
| [lab 3](Lab_03_Kubernetes.md) | **gateway** et logs sur Kubernetes, avec **agent** et **operator** | **collector** en **agent** et **gateway** (Helm), OpenTelemetry **operator**, auto-instrumentation par annotation, collecte des logs |
| [lab 4](Lab_04_Ansible_Jinja2.md) | Déploiement et gestion de la configuration du **collector** via Ansible et Jinja2 | Déploiement du **collector** sur VM Linux, puis modification de la configuration |
| [lab 5](Lab_05_NodeJS_Nginx.md) | Une trace de bout en bout, de Nginx à Node.js en passant par RabbitMQ | Auto-instrumentation, export OTLP vers Jaeger, trace de bout en bout |
| [lab 6](Lab_06_Java_Python_DotNet.md) | Java, Python, .NET et PHP, auto-instrumentation sur Linux | Auto-instrumentation sur Linux |
| [lab 7](Lab_07_Instrumentation_Manuelle.md) | Instrumenter une application Python à la main | Spans et attributs custom, propagation, baggage |
| [lab 10](Lab_10_Exploitation.md) | Exploitation du **collector** | Supervision du **collector**, dépannage de pipeline, export OTLP vers le backend du client |
| [lab 11](Lab_11_Diagnostic_Incident.md) | Diagnostic d'incident sur l'OpenTelemetry Demo | OpenTelemetry Demo (feature flags) |
