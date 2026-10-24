.pragma library

// Busca e normalização dos dados de previsão.
// Modelo comum entregue à UI:
// { updatedAt, source,
//   current: { temp, feels, humidity, wind, code, isDay },
//   days: [ { date, min, max, precipProb, precipMm, code } ] }  (hoje + 3 dias)
// feels, precipProb e precipMm podem ser null (dado não fornecido pela fonte).
//
// O parsing (parseOpenMeteo/parseMetNo) não faz rede, para poder ser testado com fixtures.

// Sem dados pessoais: o MET Norway só exige um User-Agent que identifique o app.
var USER_AGENT = "myweather-plasmoid/1.1 (KDE Plasma widget)";
var DAYS = 4;

function request(url, headers, callback) {
    var xhr = new XMLHttpRequest();
    var done = false;
    xhr.onreadystatechange = function () {
        if (xhr.readyState !== XMLHttpRequest.DONE || done)
            return;
        done = true;
        if (xhr.status !== 200) {
            callback(xhr.status === 0 ? "sem conexão ou tempo esgotado" : "HTTP " + xhr.status, null);
            return;
        }
        var json;
        try {
            json = JSON.parse(xhr.responseText);
        } catch (e) {
            callback("resposta inválida", null);
            return;
        }
        callback(null, json);
    };
    xhr.open("GET", url);
    for (var h in headers)
        xhr.setRequestHeader(h, headers[h]);
    xhr.send();
    return xhr;
}

// Coordenadas sempre com 4 casas (~11 m): suficiente e consistente entre as fontes.
function coord(x) {
    return (+x).toFixed(4);
}

// "2026-10-25" -> Date local (evita o deslocamento de fuso de new Date("2026-10-25"))
function parseDay(s) {
    var p = s.split("-");
    return new Date(+p[0], +p[1] - 1, +p[2]);
}

function localDayKey(d) {
    function pad(n) { return (n < 10 ? "0" : "") + n; }
    return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate());
}

function isNum(x) {
    return typeof x === "number" && isFinite(x);
}

function numOrNull(x) {
    return isNum(x) ? x : null;
}

// Rejeita dados incompletos: melhor cair no fallback / mostrar erro do que exibir "0%" falso.
function validate(data) {
    var c = data.current;
    if (!isNum(c.temp) || !isNum(c.humidity) || !isNum(c.wind) || !isNum(c.code))
        throw new Error("dados atuais incompletos");
    if (data.days.length < DAYS)
        throw new Error("previsão com " + data.days.length + " dias");
    for (var i = 0; i < data.days.length; i++) {
        var d = data.days[i];
        if (!isNum(d.min) || !isNum(d.max) || !isNum(d.code))
            throw new Error("previsão diária incompleta");
    }
    return data;
}

// ---------- Open-Meteo (primária) ----------

function parseOpenMeteo(j, nowMs) {
    var c = j.current, d = j.daily, days = [];
    for (var i = 0; i < d.time.length && i < DAYS; i++) {
        days.push({
            date: parseDay(d.time[i]),
            min: d.temperature_2m_min[i],
            max: d.temperature_2m_max[i],
            precipProb: numOrNull(d.precipitation_probability_max[i]),
            precipMm: numOrNull(d.precipitation_sum[i]),
            code: d.weather_code[i]
        });
    }
    return validate({
        updatedAt: nowMs,
        source: "Open-Meteo",
        current: {
            temp: c.temperature_2m,
            feels: numOrNull(c.apparent_temperature),
            humidity: c.relative_humidity_2m,
            wind: c.wind_speed_10m,
            code: c.weather_code,
            isDay: c.is_day === 1
        },
        days: days
    });
}

function fetchOpenMeteo(lat, lon, callback) {
    var url = "https://api.open-meteo.com/v1/forecast"
        + "?latitude=" + coord(lat) + "&longitude=" + coord(lon)
        + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,weather_code,is_day"
        + "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,precipitation_sum"
        + "&timezone=auto&forecast_days=" + DAYS;
    return request(url, {}, function (err, j) {
        if (err)
            return callback(err, null);
        var data;
        try {
            data = parseOpenMeteo(j, Date.now());
        } catch (e) {
            return callback("Open-Meteo: " + e.message, null);
        }
        callback(null, data);
    });
}

// ---------- MET Norway / yr.no (fallback) ----------

// symbol_code do MET -> código WMO equivalente (a UI só conhece WMO)
function metSymbolToWmo(sym) {
    var s = sym.replace(/_(day|night|polartwilight)$/, "");
    if (s.indexOf("thunder") >= 0) return 95;
    var map = {
        clearsky: 0, fair: 1, partlycloudy: 2, cloudy: 3, fog: 45,
        lightrainshowers: 80, rainshowers: 81, heavyrainshowers: 82,
        lightrain: 61, rain: 63, heavyrain: 65,
        lightsleetshowers: 66, sleetshowers: 67, heavysleetshowers: 67,
        lightsleet: 66, sleet: 67, heavysleet: 67,
        lightsnowshowers: 85, snowshowers: 85, heavysnowshowers: 86,
        lightsnow: 71, snow: 73, heavysnow: 75
    };
    return map.hasOwnProperty(s) ? map[s] : 3;
}

// Os números WMO não seguem gravidade (45 neblina > 3 nublado, 66 > 65...);
// esta ordem define o "pior tempo do dia", como o daily do Open-Meteo.
var SEVERITY = [0, 1, 2, 3, 45, 48, 51, 53, 55, 61, 80, 63, 81, 56, 57, 66, 65, 82, 67,
                71, 85, 73, 75, 86, 77, 95, 96, 99];

function severity(code) {
    var i = SEVERITY.indexOf(code);
    return i < 0 ? 0 : i;
}

function worse(a, b) {
    return severity(b) > severity(a) ? b : a;
}

// A série do MET é horária nas primeiras ~60 h (next_1_hours) e depois de 6 em 6 h
// (só next_6_hours). Cada passo contribui com o próprio intervalo; o bloco de 6 h
// conta para o dia em que começa.
function parseMetNo(j, now) {
    var ts = j.properties.timeseries;
    var first = ts[0].data, inst = first.instant.details;
    var sym = (first.next_1_hours || first.next_6_hours).summary.symbol_code;
    var hour = now.getHours();
    var isDay = sym.indexOf("_night") < 0 && (sym.indexOf("_day") >= 0 || (hour >= 6 && hour < 18));

    var byDay = {}, order = [];
    for (var i = 0; i < ts.length; i++) {
        var key = localDayKey(new Date(ts[i].time));
        if (!byDay[key]) {
            if (order.length >= DAYS) break;
            byDay[key] = { date: parseDay(key), min: Infinity, max: -Infinity, precipMm: 0, code: null };
            order.push(key);
        }
        var day = byDay[key], dd = ts[i].data, temp = dd.instant.details.air_temperature;
        if (isNum(temp)) {
            day.min = Math.min(day.min, temp);
            day.max = Math.max(day.max, temp);
        }
        var next = dd.next_1_hours || dd.next_6_hours;
        if (!next)
            continue;
        var code = metSymbolToWmo(next.summary.symbol_code);
        day.code = day.code === null ? code : worse(day.code, code);
        if (next.details && isNum(next.details.precipitation_amount))
            day.precipMm += next.details.precipitation_amount;
    }
    var days = order.map(function (k) {
        var x = byDay[k];
        return { date: x.date, min: isFinite(x.min) ? x.min : null, max: isFinite(x.max) ? x.max : null,
                 precipProb: null, precipMm: Math.round(x.precipMm * 10) / 10, code: x.code };
    });
    return validate({
        updatedAt: now.getTime(),
        source: "MET Norway",
        current: {
            temp: inst.air_temperature,
            feels: null,
            humidity: inst.relative_humidity,
            wind: isNum(inst.wind_speed) ? inst.wind_speed * 3.6 : null,
            code: metSymbolToWmo(sym),
            isDay: isDay
        },
        days: days
    });
}

function fetchMetNo(lat, lon, callback) {
    var url = "https://api.met.no/weatherapi/locationforecast/2.0/compact"
        + "?lat=" + coord(lat) + "&lon=" + coord(lon);
    return request(url, { "User-Agent": USER_AGENT }, function (err, j) {
        if (err)
            return callback(err, null);
        var data;
        try {
            data = parseMetNo(j, new Date());
        } catch (e) {
            return callback("MET Norway: " + e.message, null);
        }
        callback(null, data);
    });
}

// ---------- Geocodificação ----------

function parseGeocoding(j) {
    return (j.results || []).filter(function (r) {
        return isNum(r.latitude) && isNum(r.longitude) && typeof r.name === "string";
    }).map(function (r) {
        var label = [r.name, r.admin1, r.country].filter(function (x) { return !!x; }).join(", ");
        // nomes de lugares não têm < >; removê-los impede que o texto vire rich text
        // em controles onde não dá para forçar Text.PlainText (ex.: RadioButton)
        return { label: label.replace(/[<>]/g, ""), latitude: r.latitude, longitude: r.longitude };
    });
}

function searchCity(name, callback) {
    var url = "https://geocoding-api.open-meteo.com/v1/search?count=8&language=pt&name="
        + encodeURIComponent(name);
    return request(url, {}, function (err, j) {
        if (err)
            return callback(err, []);
        callback(null, parseGeocoding(j));
    });
}

// ---------- Código WMO -> ícone / descrição ----------

// Todos os códigos WMO que o Open-Meteo pode devolver (usado nos testes).
var ALL_CODES = SEVERITY;

function iconFor(code, isDay) {
    var dn = isDay ? "day" : "night";
    switch (code) {
    case 0:  return isDay ? "weather-clear" : "weather-clear-night";
    case 1:  return isDay ? "weather-few-clouds" : "weather-few-clouds-night";
    case 2:  return isDay ? "weather-clouds" : "weather-clouds-night";
    case 3:  return "weather-overcast";
    case 45: case 48: return "weather-fog";
    case 51: case 53: case 55: case 61: return "weather-showers-scattered-" + dn;
    case 63: case 65: return "weather-showers";
    case 56: case 57: case 66: case 67: return "weather-freezing-rain";
    case 71: case 73: case 75: case 77: return "weather-snow";
    case 80: return "weather-showers-scattered-" + dn;
    case 81: case 82: return "weather-showers-" + dn;
    case 85: case 86: return "weather-snow-scattered-" + dn;
    case 95: return "weather-storm-" + dn;
    case 96: case 99: return "weather-hail";
    }
    return "weather-none-available";
}

function describe(code) {
    switch (code) {
    case 0:  return "Céu limpo";
    case 1:  return "Predominantemente limpo";
    case 2:  return "Parcialmente nublado";
    case 3:  return "Nublado";
    case 45: case 48: return "Neblina";
    case 51: case 53: case 55: return "Garoa";
    case 56: case 57: return "Garoa congelante";
    case 61: return "Chuva fraca";
    case 63: return "Chuva";
    case 65: return "Chuva forte";
    case 66: case 67: return "Chuva congelante";
    case 71: case 73: case 75: case 77: return "Neve";
    case 80: return "Pancadas de chuva fracas";
    case 81: return "Pancadas de chuva";
    case 82: return "Pancadas de chuva fortes";
    case 85: case 86: return "Pancadas de neve";
    case 95: return "Trovoadas";
    case 96: case 99: return "Trovoadas com granizo";
    }
    return "Indisponível";
}

function fmtTemp(t) {
    return isNum(t) ? Math.round(t) + "°" : "–";
}
