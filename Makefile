# AgentOps demo — thin wrapper so targets run from repo root.
#
#   make demo              # full deploy + verify (recommended)
#   make deploy-all        # RHOAI platform only
#   make help              # list targets
#
# All targets forward to deploy/Makefile. Do not use `make -C deploy` when your
# cwd is already deploy/ — run `make <target>` from deploy/ instead.

DEPLOY_DIR := deploy

.DEFAULT_GOAL := help

.PHONY: help export-architecture export-architecture-gif
help:
	@$(MAKE) -C $(DEPLOY_DIR) help

export-architecture:
	@./scripts/export-readme-architecture.sh

export-architecture-gif:
	@./scripts/export-readme-architecture-gif.sh

# Forward any other target to deploy/Makefile (demo, deploy-all, validate-full, …)
%:
	@$(MAKE) -C $(DEPLOY_DIR) $@
