init:
	docker compose exec node yarn build
	docker compose exec php bin/console sylius:fixtures:load plus -n
