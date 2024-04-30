install:
	docker compose build

bash:
	docker compose run --rm --service-ports dart bash
