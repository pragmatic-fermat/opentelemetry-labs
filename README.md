# Labs OpenTelemetry

Labs OpenTelemetry, du socle Collector jusqu'au diagnostic d'incident.

## Programme

| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Lab&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | Titre | Contenu |
|:---|---|---|
| [Lab&nbsp;1](Lab_01_Socle.md) | Socle, premier **collector** et processors | Trois parties 1A, 1B, 1C : backend Jaeger/Grafana, premier **collector**, processors (batch, filtrage, OTTL) |
| [Lab&nbsp;2](Lab_02_Collector_Alloy.md) | **collector** sur mesure et Alloy | À écrire (non commandé) : distribution minimale avec OCB, pipeline avec Grafana Alloy |
| [Lab&nbsp;3](Lab_03_Kubernetes.md) | **gateway** et logs sur Kubernetes, avec **agent** et **operator** | **collector** en **agent** et **gateway** (Helm), OpenTelemetry **operator**, auto-instrumentation par annotation, collecte des logs |
| [Lab&nbsp;4](Lab_04_Ansible_Jinja2.md) | Déploiement et gestion de la configuration du **collector** via Ansible et Jinja2 | Déploiement du **collector** sur VM Linux, puis modification de la configuration |
| [Lab&nbsp;5](Lab_05_NodeJS_Nginx.md) | Une trace de bout en bout, de Nginx à Node.js en passant par RabbitMQ | Auto-instrumentation, export OTLP vers Jaeger, trace de bout en bout |
| [Lab&nbsp;6](Lab_06_Java_Python_DotNet_PHP.md) | Java, Python, .NET et PHP, auto-instrumentation sur Linux | Auto-instrumentation sur Linux |
| [Lab&nbsp;7](Lab_07_Instrumentation_Manuelle.md) | Instrumenter une application Python à la main | Spans et attributs custom, propagation, baggage |
| [Lab&nbsp;8](Lab_08_eBPF_OBI.md) | eBPF et OBI, instrumenter sans toucher au code | À écrire (non commandé) : instrumentation sans modifier le code avec OpenTelemetry eBPF (OBI) |
| [Lab&nbsp;9](Lab_09_Gateway_Production.md) | **gateway** et production, échantillonnage, sécurité et fiabilité | À écrire (non commandé) : tail sampling, chiffrement mTLS, authentification et files d'attente |
| [Lab&nbsp;10](Lab_10_Exploitation.md) | Exploitation du **collector** | Supervision du **collector**, dépannage de pipeline, export OTLP vers le backend du client |
| [Lab&nbsp;11](Lab_11_Diagnostic_Incident.md) | Diagnostic d'incident sur l'OpenTelemetry Demo | OpenTelemetry Demo (feature flags) |
