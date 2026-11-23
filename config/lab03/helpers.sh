# Fonctions d'aide pour le lab 3. À charger dans chaque terminal : source ~/lab03/helpers.sh
#
#   appA /api/orders                          appelle application-a via la Gateway API
#   appB /api/orders                          appelle application-b via la Gateway API
#   jaeger '/api/v3/services'                 appelle l'API de Jaeger sur srv-N
#   vlogs '/select/logsql/query?query=...'    interroge VictoriaLogs sur srv-N
#
# Les applications passent par localhost:8080, le port que KinD publie depuis
# le control-plane, avec l'en-tête Host attendu par la HTTPRoute : cela évite
# de dépendre de la résolution DNS de sslip.io. INGRESS_HOST est le nom qui
# pointe vers clt-N depuis le navigateur : IP publique en tirets, suffixe
# sslip.io. Surchargeable en exportant INGRESS_HOST avant le source.
#
# Les backends, eux, écoutent sur srv-N : SRV_HOST est fourni par
# l'environnement de la machine (srv-N.<domaine>).
: "${INGRESS_HOST:=$(curl -s https://api.ipify.org | tr '.' '-').sslip.io}"
export INGRESS_HOST
: "${SRV_HOST:?SRV_HOST non défini : ouvrez un nouveau terminal}"

appA() { curl -s -H "Host: app-a.${INGRESS_HOST}" "http://localhost:8080$1"; }
appB() { curl -s -H "Host: app-b.${INGRESS_HOST}" "http://localhost:8080$1"; }
jaeger() { curl -s "http://${SRV_HOST}:16686$1"; }
vlogs() { curl -s "http://${SRV_HOST}:9428$1"; }
