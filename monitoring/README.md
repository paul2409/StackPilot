# StackPilot Monitoring

Install:
APP_NS=stackpilot-dev \
WALLET_DB_NAME=wallet_db WALLET_DB_USER=wallet_user WALLET_DB_PASS=wallet_pass \
IDENTITY_DB_NAME=identity_db IDENTITY_DB_USER=identity_user IDENTITY_DB_PASS=identity_pass \
./monitoring/scripts/install-monitoring.sh

kubectl apply -f monitoring/servicemonitors/

Ingress scraping:
- monitoring/servicemonitors/ingress-nginx-controller.yaml assumes the ingress namespace is ingress-nginx and the service is labeled as the standard ingress-nginx controller.
