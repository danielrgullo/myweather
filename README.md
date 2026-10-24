# MyWeather

Plasmoid de previsão do tempo para KDE Plasma 6: ícone + temperatura no painel/bandeja;
ao clicar, detalhes de hoje e dos próximos 3 dias.

- QML + JavaScript puro, roda dentro do `plasmashell` (sem processo extra).
- Dados: [Open-Meteo](https://open-meteo.com) (primária) e [MET Norway](https://api.met.no) (fallback),
  ambos gratuitos e sem chave de API.
- Atualiza a cada 30 min (configurável), ao abrir o popup se o dado tiver > 15 min e ao voltar
  da suspensão. Em falha, tenta de novo em 1, 2, 5 e 10 min. Dados com mais de 1 h aparecem
  esmaecidos e com aviso.

## Uso do Makefile

```sh
make test       # sintaxe QML + testes unitários (sem rede) + ícones existem no Breeze
make smoke      # testa as APIs reais (usa rede)
make install    # roda os testes e instala/atualiza o plasmoid no host
make restart    # reinicia o plasmashell para recarregar o widget
make uninstall
make fixtures   # recaptura as respostas reais usadas nos testes
```

Os testes precisam de `qt6-qtdeclarative-devel` (`qmltestrunner`, `qml`, `qmlformat`) e rodam
com `TZ=America/Sao_Paulo`. Dentro do toolbox, `install`/`restart` usam `flatpak-spawn --host`.

Para ver o widget numa janela, sem mexer no painel: `plasmawindowed org.daniel.myweather` (no host).

## Estrutura

- `package/contents/code/weather.js` — rede, parsing (testável sem rede), validação, ícones.
- `package/contents/ui/` — `main.qml` (agenda/retry/fallback), `CompactView.qml`, `FullView.qml`,
  `ConfigGeneral.qml`.
- `tests/tst_weather.qml` — testes unitários; `tests/fixtures/` — respostas reais capturadas.

O User-Agent enviado ao MET Norway identifica só o app (`weather.js`, `USER_AGENT`); se for
publicar o widget, acrescente uma URL de contato do projeto.

Cidade (padrão: São Paulo) e intervalo de atualização: botão direito no widget →
Configurar MyWeather → buscar a cidade e escolher na lista.

## Licença

GPL-2.0-or-later (ver `LICENSE`). Dados: [Open-Meteo](https://open-meteo.com) (CC BY 4.0) e
[MET Norway](https://api.met.no) (CC BY 4.0).
