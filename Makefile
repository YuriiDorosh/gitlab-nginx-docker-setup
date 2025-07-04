# ───────────── Settings ──────────────────
DC            ?= docker compose
CT            ?= gitlab                   # container name
BACKUP_DIR    ?= ./backups
KEEP_DAYS     ?= 7 
# ─────────────────────────────────────────

.PHONY: up up-build down restart logs shell console \
        backup backup-now list-backups backup-clean \
        restore restore-latest health

up:
	$(DC) --env-file .env up -d

up-build:
	@echo "▸ Building images…"
	$(DC) --env-file .env up -d --build

down
	$(DC) down

restart:
	$(DC) restart

logs:
	$(DC) logs -f $(CT)

shell:
	@if [ -z "$(CMD)" ]; then echo 'Use: make shell CMD="<command>"'; exit 1; fi
	$(DC) exec $(CT) /bin/bash -c '$(CMD)'

console:
	$(DC) exec $(CT) gitlab-rails console

health:
	$(DC) exec $(CT) gitlab-rake gitlab:doctor:secrets && \
	$(DC) exec $(CT) gitlab-rake gitlab:db:validate_config


backup:
	$(DC) exec $(CT) gitlab-backup create STRATEGY=copy

backup-now:      ## Full backup → $(BACKUP_DIR)/YYYY-MM-DD_HH-MM
	@set -eu; \
	TS=$$(date +%F_%H-%M); \
	DST="$(BACKUP_DIR)/$$TS"; \
	echo "▸ Creating backup → $$TS"; \
	mkdir -p "$$DST"; \
	$(DC) exec -T $(CT) gitlab-backup create STRATEGY=copy; \
	LATEST=$$($(DC) exec -T $(CT) \
	          ls -1t /var/opt/gitlab/backups | head -n1 | tr -d '\r'); \
	echo "▸ Copying files to host…"; \
	$(DC) cp $(CT):/var/opt/gitlab/backups/$$LATEST "$$DST/"; \
	$(DC) cp $(CT):/etc/gitlab/gitlab-secrets.json "$$DST/"; \
	$(DC) cp $(CT):/etc/gitlab/gitlab.rb           "$$DST/"; \
	echo "✔ Backup saved → $$DST"

list-backups:    ## Show local backups in $(BACKUP_DIR)
	@ls -1t $(BACKUP_DIR) || echo "no backups"

backup-clean:
	@find $(BACKUP_DIR) -maxdepth 1 -type d -mtime +$(KEEP_DAYS) -print -exec rm -rf {} +


restore:         ## Restore (FILE=..._gitlab_backup.tar)
	@if [ -z "$(FILE)" ]; then \
	  echo "Use: make restore FILE=<path/to/_gitlab_backup.tar>"; exit 1; fi
	@set -eu; \
	BASENAME=$$(basename $(FILE)); \
	echo "▸ Copying $$BASENAME to container…"; \
	$(DC) cp $(FILE) $(CT):/var/opt/gitlab/backups/; \
	echo "▸ Restoring…"; \
	$(DC) exec -T $(CT) gitlab-backup restore BACKUP=$${BASENAME%%.tar}; \
	echo "▸ Restoring configs…"; \
	DIR=$$(dirname $(FILE)); \
	$(DC) cp $$DIR/gitlab-secrets.json $(CT):/etc/gitlab/; \
	$(DC) cp $$DIR/gitlab.rb           $(CT):/etc/gitlab/ || true; \
	$(DC) exec $(CT) gitlab-ctl reconfigure; \
	$(DC) exec $(CT) gitlab-ctl restart

restore-latest:  ## Restore new backup from(take latest) $(BACKUP_DIR)
	@set -eu; \
	LAST_DIR=$$(ls -1t $(BACKUP_DIR) | head -n1); \
	TAR=$$(ls -1 $(BACKUP_DIR)/$$LAST_DIR/*_gitlab_backup.tar | head -n1); \
	if [ -z "$$TAR" ]; then echo "No backups found"; exit 1; fi; \
	make restore FILE="$$TAR"

