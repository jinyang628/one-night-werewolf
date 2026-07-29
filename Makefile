.PHONY: lint test start-backend start-frontend

lint:
	cd one_night_werewolf && dart format .
	cd one_night_werewolf && flutter analyze
	cd backend && poetry run autoflake --in-place --remove-all-unused-imports --recursive .
	cd backend && poetry run isort .
	cd backend && poetry run black .

test:
	cd one_night_werewolf && flutter test
	cd backend && PYTHONPATH=. poetry run python -m unittest discover -s tests -v

start-backend:
	cd backend && poetry run uvicorn app.api.main:app --reload --host 0.0.0.0 --port 8080 --env-file .env

start-frontend:
	cd one_night_werewolf && flutter run
