# SOA-deployment

Prvi put u root projekta pokrenuti docker network create soa-net


Ako zelimo samo projekat bez observability onda samo:
docker compose up -d --build

Ako zelimo samo monitoring navigiramo se u folder monitoring i pokrenemo:
docker compose -f docker-compose.monitoring.yml up -d

Da bi pokrenuli sve potrebno pokrenuti:  SAVET-NEMOJ, BOLJE JEDNO PO JEDNO
docker compose -f docker-compose.yml -f monitoring/docker-compose.monitoring.yml up -d 