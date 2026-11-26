# Fonteyn Holiday Parks – Part C (Booking App & Legacy Baseline)

## Layout
- `app/` – Reusable container image (`Dockerfile`, `app.py`, `requirements.txt`) used in both the EduCloud legacy DMZ server and Azure Container Apps.
- `old-environment/booking/` – Single-server Docker Compose stack (`booking_web` + `postgres:16`) + 30 seeded legacy bookings (`init.sql`) + one-command installer (`setup.sh`).

## Deploy on `hq-booking-01` (Ubuntu in EduCloud)
```bash
git clone <YOUR_REPO_URL>
cd <YOUR_REPO_NAME>/old-environment/booking
bash setup.sh
```

## Endpoints
- `/` – Guest booking portal + ledger
- `/staff` – Staff portal (`legacy` shared password in EduCloud; switches to Entra ID header in Azure when `AUTH_MODE=entra`)
- `/api/arrivals` – Daily arrivals JSON for Part E barriers (supports `?park=NL-HEL`)
- `/health` – Container health probe (checks PostgreSQL connectivity)
