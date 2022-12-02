# Copyright 2022 Google LLC

.PHONY: docker_lint
docker_lint:
	docker run --rm -it \
		-v $(CURDIR):/code \
		registry.gitlab.com/pipeline-components/ansible-lint:latest
