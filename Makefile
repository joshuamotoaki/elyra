.PHONY: db-up db-down db-clear

db-up:
	docker-compose up -d

db-down:
	docker-compose down

db-clear:
	docker-compose down -v