run:
	docker compose build --build-arg SYLIUS_PLUS_TOKEN=${SYLIUS_PLUS_TOKEN}
	docker compose up -d

prod:
	MYSQL_PASSWORD=temp-password docker compose -f docker-compose.prod.yml build --build-arg SYLIUS_PLUS_TOKEN=${SYLIUS_PLUS_TOKEN}
	MYSQL_PASSWORD=temp-password docker compose -f docker-compose.prod.yml up -d

reset:
	docker compose exec node yarn build
	docker compose exec php bin/console sylius:fixtures:load plus -n

phpunit:
	docker compose exec php vendor/bin/phpunit

phpspec:
	docker compose exec php vendor/bin/phpspec run --ansi --no-interaction -f dot

phpstan:
	docker compose exec php vendor/bin/phpstan analyse

psalm:
	docker compose exec php vendor/bin/psalm
