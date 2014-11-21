SHELL := /usr/bin/env bash

git-check:
	git checkout master
	@test -z "$$(git status --porcelain)" || (echo "Please first commit/clean your Git working directory" && false)

setup: git-check
	@(MAKE) setup-unsafe

setup-unsafe:
	git pull
	source envs/production.sh && scripts/control.sh setup

launch: git-check
	@(MAKE) launch-unsafe

launch-unsafe:
	git pull
	source envs/production.sh && scripts/control.sh launch

ssh:
	source envs/production.sh && scripts/control.sh remote

release-major: build test
	npm version major -m "Release %s"
	git push
	npm publish

release-minor: build test
	npm version minor -m "Release %s"
	git push
	npm publish

release-patch: build test
	npm version patch -m "Release %s"
	git push
	npm publish

.PHONY: \
	git-check \
	setup \
	setup-unsafe \
	launch \
	launch-unsafe \
	release-major \
	release-minor \
	release-patch \
	ssh \
