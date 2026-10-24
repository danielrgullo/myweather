#!/bin/sh
# Captura respostas reais das APIs (São Paulo/SP) como fixtures JS para os testes.
# Só rode quando quiser atualizar as amostras; os testes unitários não usam rede.
set -eu
cd "$(dirname "$0")/fixtures"
UA="myweather-plasmoid/1.1 (KDE Plasma widget)"
LAT=-23.5475 LON=-46.6361

wrap() { printf '.pragma library\n// gerado por tests/update-fixtures.sh em %s\nvar json = ' "$(date -Iseconds)"; cat; printf ';\n'; }

curl -sf "https://api.open-meteo.com/v1/forecast?latitude=$LAT&longitude=$LON\
&current=temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,weather_code,is_day\
&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,precipitation_sum\
&timezone=auto&forecast_days=4" | wrap > openmeteo.js
curl -sf -A "$UA" "https://api.met.no/weatherapi/locationforecast/2.0/compact?lat=$LAT&lon=$LON" | wrap > metno.js
curl -sf "https://geocoding-api.open-meteo.com/v1/search?count=8&language=pt&name=S%C3%A3o%20Paulo" | wrap > geocoding.js
ls -l openmeteo.js metno.js geocoding.js
