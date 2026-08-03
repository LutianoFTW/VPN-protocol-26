.PHONY: test validate render-check

test validate:
	chmod +x scripts/*.sh tests/*.sh
	./tests/validate-server-nolog.sh

render-check:
	python3 tools/xray_nolog.py validate-template
