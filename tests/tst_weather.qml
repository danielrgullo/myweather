import QtQuick
import QtTest
import "../package/contents/code/weather.js" as W
import "fixtures/openmeteo.js" as OM
import "fixtures/metno.js" as MET
import "fixtures/geocoding.js" as GEO

// Testes unitários do parsing (sem rede). Rodar com TZ=America/Sao_Paulo (ver Makefile).
TestCase {
    name: "Weather"

    function clone(x) {
        return JSON.parse(JSON.stringify(x));
    }

    // Mensagem do erro lançado por fn, ou null se não lançou.
    function errorOf(fn) {
        try {
            fn();
        } catch (e) {
            return e.message;
        }
        return null;
    }

    // Monta um passo da série do MET. n1/n6 = [symbol_code, precipitação mm] ou null.
    function metStep(iso, temp, n1, n6) {
        const data = { instant: { details: { air_temperature: temp, relative_humidity: 80, wind_speed: 2 } } };
        if (n1) data.next_1_hours = { summary: { symbol_code: n1[0] }, details: { precipitation_amount: n1[1] } };
        if (n6) data.next_6_hours = { summary: { symbol_code: n6[0] }, details: { precipitation_amount: n6[1] } };
        return { time: iso, data: data };
    }

    function metDoc(steps) {
        return { properties: { timeseries: steps } };
    }

    // Série com trecho horário e trecho de 6 em 6 h, cruzando a virada do dia local.
    function syntheticMet() {
        return metDoc([
            metStep("2026-10-24T12:00:00Z", 20, ["rain", 1.0], ["rain", 9]),          // 24/10 09h
            metStep("2026-10-24T13:00:00Z", 22, ["cloudy", 0.5], ["cloudy", 9]),      // 24/10 10h
            metStep("2026-10-25T02:00:00Z", 30, ["clearsky_night", 0], null),         // 24/10 23h local!
            metStep("2026-10-25T12:00:00Z", 18, ["fair_day", 0], null),               // 25/10
            metStep("2026-10-26T12:00:00Z", 15, null, ["heavyrain", 8.0]),            // 26/10, só 6 h
            metStep("2026-10-26T18:00:00Z", 17, null, ["lightrain", 2.0]),            // 26/10, só 6 h
            metStep("2026-10-27T12:00:00Z", 25, null, ["clearsky_day", 0]),           // 27/10
            metStep("2026-10-28T12:00:00Z", 26, null, ["rain", 5.0])                  // 5º dia: descartado
        ]);
    }

    function initTestCase() {
        // Os testes de data assumem o fuso de São Paulo (UTC-3).
        compare(new Date("2026-10-24T12:00:00Z").getTimezoneOffset(), 180, "rode com TZ=America/Sao_Paulo");
    }

    // ---------- helpers ----------

    function test_parseDay() {
        const d = W.parseDay("2026-10-25");
        compare(d.getFullYear(), 2026);
        compare(d.getMonth(), 9);
        compare(d.getDate(), 25);
        compare(d.getHours(), 0);
    }

    function test_coord() {
        compare(W.coord(-23.547512), "-23.5475");
        compare(W.coord("-46.6"), "-46.6000");
    }

    function test_fmtTemp_data() {
        return [
            { tag: "arredonda", v: 22.6, out: "23°" },
            { tag: "negativo", v: -3.5, out: "-3°" },
            { tag: "menos zero", v: -0.4, out: "0°" },
            { tag: "null", v: null, out: "–" },
            { tag: "undefined", v: undefined, out: "–" },
            { tag: "NaN", v: NaN, out: "–" },
            { tag: "string", v: "22", out: "–" }
        ];
    }
    function test_fmtTemp(row) {
        compare(W.fmtTemp(row.v), row.out);
    }

    // ---------- Open-Meteo ----------

    function test_openmeteo_fixture() {
        const j = OM.json;
        const d = W.parseOpenMeteo(j, 1000);
        compare(d.source, "Open-Meteo");
        compare(d.updatedAt, 1000);
        compare(d.current.temp, j.current.temperature_2m);
        compare(d.current.humidity, j.current.relative_humidity_2m);
        compare(d.current.isDay, j.current.is_day === 1);
        compare(d.days.length, 4);
        for (let i = 0; i < 4; i++) {
            compare(W.localDayKey(d.days[i].date), j.daily.time[i]);
            verify(d.days[i].min <= d.days[i].max);
        }
    }

    function test_openmeteo_campoObrigatorioNulo_data() {
        return ["temperature_2m", "relative_humidity_2m", "wind_speed_10m", "weather_code"]
            .map(f => ({ tag: f, field: f }));
    }
    function test_openmeteo_campoObrigatorioNulo(row) {
        const j = clone(OM.json);
        j.current[row.field] = null;
        compare(errorOf(() => W.parseOpenMeteo(j, 0)), "dados atuais incompletos");
    }

    function test_openmeteo_diarioNulo() {
        const j = clone(OM.json);
        j.daily.temperature_2m_max[2] = null;
        compare(errorOf(() => W.parseOpenMeteo(j, 0)), "previsão diária incompleta");
    }

    function test_openmeteo_opcionaisNulos() {
        const j = clone(OM.json);
        j.current.apparent_temperature = null;
        j.daily.precipitation_probability_max[1] = null;
        j.daily.precipitation_sum[1] = null;
        const d = W.parseOpenMeteo(j, 0);
        compare(d.current.feels, null);
        compare(d.days[1].precipProb, null);
        compare(d.days[1].precipMm, null);
    }

    function test_openmeteo_poucosDias() {
        const j = clone(OM.json);
        for (const k in j.daily)
            j.daily[k] = j.daily[k].slice(0, 2);
        compare(errorOf(() => W.parseOpenMeteo(j, 0)), "previsão com 2 dias");
    }

    // ---------- MET Norway ----------

    function test_metno_fixture() {
        const now = new Date(MET.json.properties.timeseries[0].time);
        const d = W.parseMetNo(MET.json, now);
        compare(d.source, "MET Norway");
        compare(d.current.feels, null);
        compare(d.days.length, 4);
        for (let i = 0; i < 4; i++) {
            verify(d.days[i].min <= d.days[i].max, "dia " + i);
            verify(d.days[i].precipMm >= 0, "dia " + i);
            if (i > 0)
                compare(d.days[i].date.getTime() - d.days[i - 1].date.getTime(), 86400000);
        }
        // vento chega em m/s e sai em km/h
        compare(d.current.wind, MET.json.properties.timeseries[0].data.instant.details.wind_speed * 3.6);
    }

    function test_metno_agrupaPorDiaLocal() {
        const d = W.parseMetNo(syntheticMet(), new Date("2026-10-24T12:00:00Z"));
        compare(d.days.length, 4, "o 5º dia deve ser descartado");
        compare(d.days.map(x => W.localDayKey(x.date)), ["2026-10-24", "2026-10-25", "2026-10-26", "2026-10-27"]);
        // 02:00Z de 25/10 = 23:00 de 24/10 em São Paulo
        compare(d.days[0].max, 30);
        compare(d.days[0].min, 20);
    }

    function test_metno_chuvaEmBlocosDe6h() {
        const d = W.parseMetNo(syntheticMet(), new Date("2026-10-24T12:00:00Z"));
        // trecho horário: usa só next_1_hours (ignora o next_6_hours sobreposto)
        compare(d.days[0].precipMm, 1.5);
        compare(d.days[1].precipMm, 0);
        // trecho de 6 h: soma os blocos (bug da versão 1.0, que dava 0)
        compare(d.days[2].precipMm, 10);
        compare(d.days[3].precipMm, 0);
    }

    function test_metno_piorTempoDoDia() {
        const d = W.parseMetNo(syntheticMet(), new Date("2026-10-24T12:00:00Z"));
        compare(d.days[0].code, 63);  // chuva > nublado > céu limpo
        compare(d.days[1].code, 1);
        compare(d.days[2].code, 65);  // chuva forte > chuva fraca
        compare(d.days[3].code, 0);
    }

    function test_metno_dadoAtualIncompleto() {
        const j = syntheticMet();
        j.properties.timeseries[0].data.instant.details.air_temperature = null;
        compare(errorOf(() => W.parseMetNo(j, new Date("2026-10-24T12:00:00Z"))), "dados atuais incompletos");
    }

    function test_metno_serieVazia() {
        verify(errorOf(() => W.parseMetNo(metDoc([]), new Date())) !== null);
    }

    function test_metSymbolToWmo_data() {
        return [
            { tag: "clearsky_day", s: "clearsky_day", c: 0 },
            { tag: "partlycloudy_night", s: "partlycloudy_night", c: 2 },
            { tag: "polartwilight", s: "fair_polartwilight", c: 1 },
            { tag: "fog", s: "fog", c: 45 },
            { tag: "heavyrainshowers_day", s: "heavyrainshowers_day", c: 82 },
            { tag: "trovoada", s: "heavyrainandthunder", c: 95 },
            { tag: "trovoada pancada", s: "lightrainshowersandthunder_night", c: 95 },
            { tag: "desconhecido", s: "algumacoisa", c: 3 }
        ];
    }
    function test_metSymbolToWmo(row) {
        compare(W.metSymbolToWmo(row.s), row.c);
    }

    function test_severidade() {
        compare(W.worse(3, 45), 45);
        compare(W.worse(45, 3), 45);
        compare(W.worse(66, 65), 65);
        compare(W.worse(61, 95), 95);
        compare(W.worse(0, 0), 0);
    }

    // ---------- Geocodificação ----------

    function test_geocoding_fixture() {
        const r = W.parseGeocoding(GEO.json);
        verify(r.length > 0);
        compare(r[0].label, "São Paulo, São Paulo, Brasil");
        verify(Math.abs(r[0].latitude + 23.55) < 0.1);
    }

    function test_geocoding_saneamento() {
        const r = W.parseGeocoding({ results: [
            { name: "<img src=x>Cidade", admin1: "<b>UF</b>", country: "BR", latitude: 1, longitude: 2 },
            { name: "Sem coordenada", latitude: null, longitude: 2 },
            { latitude: 1, longitude: 2 }
        ] });
        compare(r.length, 1);
        compare(r[0].label, "img src=xCidade, bUF/b, BR");
    }

    function test_geocoding_semResultados() {
        compare(W.parseGeocoding({}).length, 0);
    }

    // ---------- Ícones / descrições ----------

    function test_todosCodigosMapeados() {
        for (const code of W.ALL_CODES) {
            verify(W.iconFor(code, true) !== "weather-none-available", "ícone dia " + code);
            verify(W.iconFor(code, false) !== "weather-none-available", "ícone noite " + code);
            verify(W.describe(code) !== "Indisponível", "descrição " + code);
        }
        compare(W.iconFor(1234, true), "weather-none-available");
    }
}
