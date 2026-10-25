.PHONY: format format-check lint style-check

format:
	stylua .

format-check:
	stylua --check .

lint:
	selene .

style-check: format-check lint
