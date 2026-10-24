# Testes rodam no toolbox (precisa de qt6-qtdeclarative-devel); install/restart vão para o host.
QT_BIN ?= /usr/lib64/qt6/bin
HOST   ?= $(shell [ -f /run/.containerenv ] && echo flatpak-spawn --host)
QML_FILES := $(wildcard package/contents/ui/*.qml package/contents/config/*.qml tests/*.qml)

export TZ := America/Sao_Paulo
export QT_QPA_PLATFORM := offscreen
export QT_FORCE_STDERR_LOGGING := 1

.PHONY: test unit icons syntax smoke fixtures install restart uninstall

test: syntax unit icons

unit:
	$(QT_BIN)/qmltestrunner -input tests/tst_weather.qml

icons:
	QML=$(QT_BIN)/qml tests/check-icons.sh

syntax:
	@for f in $(QML_FILES); do $(QT_BIN)/qmlformat "$$f" > /dev/null || exit 1; done; echo "ok: sintaxe QML"

# usa rede
smoke:
	$(QT_BIN)/qml tests/smoke.qml

fixtures:
	tests/update-fixtures.sh

install: test
	$(HOST) kpackagetool6 -t Plasma/Applet -u $(CURDIR)/package 2>/dev/null \
		|| $(HOST) kpackagetool6 -t Plasma/Applet -i $(CURDIR)/package

restart:
	$(HOST) systemctl --user restart plasma-plasmashell

uninstall:
	$(HOST) kpackagetool6 -t Plasma/Applet -r org.daniel.myweather
