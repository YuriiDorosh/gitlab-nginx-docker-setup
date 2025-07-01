DC ?= docker compose
BACKUP_DIR ?= ./backups

.PHONY: up down restart logs exec console \
        backup backup-now backup-clean restore restart-backup

up:            ## Запустити всі сервіси
	$(DC) --env-file .env up -d

down:          ## Зупинити й прибрати
	$(DC) down

restart:       ## Перезапустити контейнери
	$(DC) restart

logs:          ## Стрим логи
	$(DC) logs -f

exec:          ## Shell у GitLab (make exec CMD="ls -la")
	@if [ -z "$(CMD)" ]; then echo "Use: make exec CMD='<command>'"; exit 1; fi
	$(DC) exec gitlab /bin/bash -c "$(CMD)"

console:       ## Rails console (GitLab API)
	$(DC) exec gitlab gitlab-rails console

# ──────────────────────────── Бекапи ─────────────────────────────

backup:        ## Створити .tar-бекап тільки у volume (швидко)
	$(DC) exec gitlab gitlab-backup create STRATEGY=copy

backup-now:    ## Повний бекап у $(BACKUP_DIR)/YYYY-MM-DD_HH-MM
	@sh -c '\
	set -e; \
	TS=$$(date +%F_%H-%M); \
	DEST="$(BACKUP_DIR)/$$TS"; \
	echo "▸ Creating backup → $$TS"; \
	mkdir -p "$$DEST"; \
	$(DC) exec -T gitlab gitlab-backup create STRATEGY=copy; \
	LATEST=$$($(DC) exec -T gitlab \
	          ls -1t /var/opt/gitlab/backups | head -n1 | tr -d "\r"); \
	echo "▸ Copying files to host…"; \
	$(DC) cp gitlab:/var/opt/gitlab/backups/$$LATEST   "$$DEST/"; \
	$(DC) cp gitlab:/etc/gitlab/gitlab-secrets.json    "$$DEST/"; \
	$(DC) cp gitlab:/etc/gitlab/gitlab.rb              "$$DEST/"; \
	echo "✔ Backup saved to $$DEST"'

backup-clean:  ## Видалити каталоги у $(BACKUP_DIR) старші 7 днів
	find $(BACKUP_DIR) -maxdepth 1 -type d -mtime +7 -print -exec rm -rf {} +

restart-backup: ## Перезапустити sidecar-контейнер для бекапу
	$(DC) restart gitlab-backup

# ──────────────────────────── Відновлення ───────────────────────

restore:       ## Відновити бекап (FILE=..._gitlab_backup.tar)
	@if [ -z "$(FILE)" ]; then \
		echo "Use: make restore FILE=<backup.tar>"; exit 1; fi
	$(DC) exec gitlab gitlab-backup restore BACKUP=$(basename $(FILE) .tar)
	$(DC) exec gitlab gitlab-ctl reconfigure
