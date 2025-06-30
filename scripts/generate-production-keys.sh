#!/bin/bash

echo "=== Rails Production Keys Generator ==="

echo "Generating SECRET_KEY_BASE..."
SECRET_KEY_BASE=$(rails secret)
echo "SECRET_KEY_BASE=$SECRET_KEY_BASE"

echo ""
echo "Generating RAILS_MASTER_KEY..."
echo "Run: EDITOR=nano rails credentials:edit --environment production"
echo "This will generate config/credentials/production.key"

echo ""
echo "=== Copy these values to Railway Environment Variables ==="
echo "SECRET_KEY_BASE=$SECRET_KEY_BASE"
