.PHONY: test validate

test: validate

validate:
	sh tests/validate.sh
