# Fonctions d'aide pour le TP3. À charger dans chaque terminal : source ~/tp03/helpers.sh
#
#   app /api/orders          appelle le frontend de l'application via l'ingress
#   jaeger '/api/v3/services'   appelle l'API de Jaeger via l'ingress
#
# Les appels passent par localhost:8080 (ingress-nginx) avec l'en-tête Host
# attendu, ce qui évite de dépendre de la résolution DNS de sslip.io.
# Nom qui pointe vers la machine depuis le navigateur : IP publique en tirets
# et suffixe sslip.io. Surchargeable en exportant INGRESS_HOST avant le source.
: "${INGRESS_HOST:=$(curl -s https://api.ipify.org | tr '.' '-').sslip.io}"
export INGRESS_HOST

app() { curl -s -H "Host: app.${INGRESS_HOST}" "http://localhost:8080$1"; }
jaeger() { curl -s -H "Host: jaeger.${INGRESS_HOST}" "http://localhost:8080$1"; }
