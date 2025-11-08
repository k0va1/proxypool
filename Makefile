.PHONY: test lint-fix console install

install:
	bundle install

console:
	bin/console


test:
	bundle exec rspec



lint-fix:
	bundle exec standardrb --fix

