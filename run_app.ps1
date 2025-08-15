#!/usr/bin/env pwsh

# Script para ejecutar la aplicación Legado
Write-Host "🇲🇽 Ejecutando aplicación Legado..."
Write-Host "📁 Directorio actual: $(Get-Location)"

# Verificar que estamos en el directorio correcto
if (!(Test-Path "pubspec.yaml")) {
    Write-Host "❌ Error: No se encontró pubspec.yaml"
    Write-Host "📁 Asegúrate de estar en el directorio del proyecto Flutter"
    exit 1
}

Write-Host "✅ Archivo pubspec.yaml encontrado"

# Limpiar y construir
Write-Host "🧹 Limpiando proyecto..."
flutter clean

Write-Host "📦 Obteniendo dependencias..."
flutter pub get

# Mostrar dispositivos disponibles
Write-Host "📱 Dispositivos disponibles:"
flutter devices

# Ejecutar en Windows (más estable que Chrome)
Write-Host "🖥️ Ejecutando en Windows Desktop..."
flutter run -d windows --hot

Write-Host "🎉 ¡Aplicación ejecutada!"
Write-Host "💡 Presiona 'r' en la consola para hot reload después de cambios"
