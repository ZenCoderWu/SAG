#!/bin/sh
set -e

echo "==> Running database migrations..."
node dist/src/db/migrate.js

echo "==> Seeding default data..."
node dist/src/db/seed.js

echo "==> Starting SAG server..."
exec node dist/src/index.js
