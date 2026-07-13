CURRENT_DIR = $(shell pwd)
LOCALBIN ?= $(CURRENT_DIR)/bin

# Tool Versions
GITCHGLOG_VERSION ?= v0.15.4
HELMDOCS_VERSION ?= v1.14.2

GITCHGLOG ?= $(LOCALBIN)/git-chglog
HELMDOCS ?= $(LOCALBIN)/helm-docs

SHELL = /bin/bash -o pipefail -o errexit

.PHONY: all
all: help

$(LOCALBIN):
	mkdir -p $(LOCALBIN)

# use https://github.com/git-chglog/git-chglog/
.PHONY: changelog
changelog: git-chglog ## Generate CHANGELOG.md from conventional commits
ifneq (${NEXT_RELEASE_TAG},)
	$(GITCHGLOG) --next-tag v${NEXT_RELEASE_TAG} -o CHANGELOG.md
else
	$(GITCHGLOG) -o CHANGELOG.md
endif

.PHONY: git-chglog
git-chglog: $(GITCHGLOG) ## Download git-chglog locally if necessary
$(GITCHGLOG): $(LOCALBIN)
	@test -x $(GITCHGLOG) || GOBIN=$(LOCALBIN) go install github.com/git-chglog/git-chglog/cmd/git-chglog@$(GITCHGLOG_VERSION)

# use https://github.com/norwoodj/helm-docs/
.PHONY: helm-docs
helm-docs: helmdocs ## Generate Helm chart docs (deploy-templates/README.md)
	$(HELMDOCS) --chart-search-root deploy-templates

.PHONY: helmdocs
helmdocs: $(HELMDOCS) ## Download helm-docs locally if necessary
$(HELMDOCS): $(LOCALBIN)
	@test -x $(HELMDOCS) || GOBIN=$(LOCALBIN) go install github.com/norwoodj/helm-docs/cmd/helm-docs@$(HELMDOCS_VERSION)

.PHONY: help
help: ## Display this help screen
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z0-9_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
