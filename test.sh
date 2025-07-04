#!/bin/bash

echo "▶ Initialisation de Terraform..."
terraform init -input=false -backend=false

echo "▶ Vérification de la syntaxe..."
terraform validate

echo "▶ Formatage du code (vérification uniquement)..."
terraform fmt -recursive -check

echo "✅ Tous les tests Terraform sont passés !"