SHELL     := /bin/bash

deploy-production:
	# Sets up all local & remote dependencies. Usefull for firs-time uses
	# and to apply infra / software changes.
	git checkout master
	@test -z "$$(git status --porcelain)" || (echo "Please first commit/clean your Git working directory" && false)
	git pull
	source envs/production.sh && scripts/control.sh prepare

deploy-production-unsafe:
	# Sets up all local & remote dependencies. Usefull for firs-time uses
	# and to apply infra / software changes.
	# Does not check git index
	git checkout master
	git pull
	source envs/production.sh && scripts/control.sh prepare

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
	deploy-production-unsafe \
	release-major \
	release-minor \
	release-patch \
	ssh-production \
