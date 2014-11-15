SHELL     := /bin/bash

deploy-production-full:
	# Sets up all local & remote dependencies. Usefull for firs-time uses
	# and to apply infra / software changes.
	git checkout master
	@test -z "$$(git status --porcelain)" || (echo "Please first commit/clean your Git working directory" && false)
	git pull
	source envs/production.sh && scripts/control.sh prepare

deploy-production-full-unsafe:
	# Sets up all local & remote dependencies. Usefull for firs-time uses
	# and to apply infra / software changes.
	# Does not check git index
	git checkout master
	git pull
	source envs/production.sh && scripts/control.sh prepare

deploy-production:
	# For regular use. Just uploads the code and restarts the services
	git checkout master
	@test -z "$$(git status --porcelain)" || (echo "Please first commit/clean your Git working directory" && false)
	git pull
	source envs/production.sh && scripts/control.sh upload

deploy-production-unsafe:
	# Does not check git index
	git checkout master
	git pull
	source envs/production.sh && scripts/control.sh upload

ssh-production:
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
	deploy-production \
	deploy-production-full \
	deploy-production-unsafe \
	deploy-production-full-unsafe \
	release-major \
	release-minor \
	release-patch \
	ssh-production \
