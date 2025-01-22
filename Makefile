SHELL=/bin/bash

blueprint: ## Generate all blueprints file
	@if ! type orbit >/dev/null 2>&1; then echo "Missing orbit dependency, please install from https://github.com/gulien/orbit/"; exit 1; fi
	orbit run generate

test-latest: test-8.4 ## Test the latest build only

_test-prerequisites: blueprint
	docker pull ubuntu:20.04

test-quick:  ## Test 8.2, 8.3 and 8.4 quickly
	VERSION=8.2 VARIANT=cli $(MAKE) _test-version-quick
	VERSION=8.3 VARIANT=cli $(MAKE) _test-version-quick
	VERSION=8.4 VARIANT=cli $(MAKE) _test-version-quick

test-8.3:  ## Test php8.3 build only
	VERSION=8.3 VARIANT=cli $(MAKE) _test-version
	VERSION=8.3 VARIANT=apache $(MAKE) _test-version
	VERSION=8.3 VARIANT=fpm $(MAKE) _test-version

test-8.2:  ## Test php8.2 build only
	VERSION=8.2 VARIANT=cli $(MAKE) _test-version
	VERSION=8.2 VARIANT=apache $(MAKE) _test-version
	VERSION=8.2 VARIANT=fpm $(MAKE) _test-version

test-8.1:  ## Test php8.1 build only
	VERSION=8.1 VARIANT=cli $(MAKE) _test-version
	VERSION=8.1 VARIANT=apache $(MAKE) _test-version
	VERSION=8.1 VARIANT=fpm $(MAKE) _test-version

test-8.4:  ## Test php8.4 build only
	VERSION=8.4 VARIANT=cli $(MAKE) _test-version
	VERSION=8.4 VARIANT=apache $(MAKE) _test-version
	VERSION=8.4 VARIANT=fpm $(MAKE) _test-version

test-node:  ## Test node builds only
	VERSION=8.4 VARIANT=cli NODE=12 $(MAKE) _test-node
	VERSION=8.4 VARIANT=cli NODE=14 $(MAKE) _test-node
	VERSION=8.4 VARIANT=cli NODE=16 $(MAKE) _test-node
	VERSION=8.4 VARIANT=cli NODE=18 $(MAKE) _test-node
	VERSION=8.4 VARIANT=cli NODE=20 $(MAKE) _test-node
	VERSION=8.4 VARIANT=cli NODE=22 $(MAKE) _test-node

_test-node: _test-prerequisites ## Test node for VERSION="" and VARIANT=""
	docker buildx bake --load \
		--set "*.platform=$(uname -p)" \
		php$${VERSION//.}-$(VARIANT)-all
	PHP_VERSION="$(VERSION)" BRANCH=v5 VARIANT=$(VARIANT) NODE=$(NODE) ./tests-suite/bash_unit -f tap ./tests-suite/*.sh || (notify-send -u critical "Tests failed ($(VERSION)-$(VARIANT)-node$(NODE))" && exit 1)
	notify-send -u critical "Tests passed with success ($(VERSION)-$(VARIANT)-node$(NODE))"

_test-version: _test-prerequisites ## Test php build for VERSION="" and VARIANT=""
	docker buildx bake --load \
		--set "*.platform=$(uname -p)" \
		php$${VERSION//.}-$(VARIANT)-all
	PHP_VERSION="$(VERSION)" BRANCH=v5 VARIANT=$(VARIANT) ./tests-suite/bash_unit -f tap ./tests-suite/*.sh || (notify-send -u critical "Tests failed ($(VERSION)-$(VARIANT))" && exit 1)
	notify-send -u critical "Tests passed with success ($(VERSION)-$(VARIANT))"

_test-version-quick: _test-prerequisites ## Test php build for VERSION="" and VARIANT="" (without node variants)
	docker buildx bake --load \
		--set "*.platform=$(uname -p)" \
		php$${VERSION//.}-slim-$(VARIANT) php$${VERSION//.}-$(VARIANT)
	PHP_VERSION="$(VERSION)" BRANCH=v5 VARIANT=$(VARIANT) ./tests-suite/bash_unit -f tap ./tests-suite/*.sh || (notify-send -u critical "Tests failed ($(VERSION)-$(VARIANT))" && exit 1)
	notify-send -u critical "Tests passed with success ($(VERSION)-$(VARIANT)) - without node-*"

clean: ## Clean dangles image after build
	rm -rf /tmp/buildx-cache


test-manual-build:
	docker build \
		--build-arg PHP_VERSION="8.4" \
		--build-arg VARIANT="cli" \
		--build-arg GLOBAL_VERSION="v5" \
		--file ./Dockerfile.slim.cli \
		--tag testv5-slim \
		.
	docker --debug build \
		--build-arg PHP_VERSION="8.4" \
		--build-arg VARIANT="cli" \
		--build-arg GLOBAL_VERSION="v5" \
		--build-arg FROM_IMAGE="testv5-slim" \
		--file ./Dockerfile.cli \
		--tag testv5 \
		.
#		--target=base \

test-manual-exec:
	docker run --rm -it testv5 bash


testtt:
	PHP_EXTENSION_SWOOLE=1 php -m | grep -i swoole
	PHP_EXTENSION_GETTEXT=1 php -m | grep -i gettext
