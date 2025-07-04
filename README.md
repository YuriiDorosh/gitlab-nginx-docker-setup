Creating user without SMTP:

```bash
curl --header "PRIVATE-TOKEN: <ROOT_PAT>" \
     -X POST "http://$GITLAB_HOST/api/v4/users" \
     --data "email=user@example.com&username=newuser&name=New+User&password=Str0ng!Pass&skip_confirmation=true"
```

or creating with UI admin and create password by rails ORM: 

```bash
make set-pass USER=admin1 PASS='MyN3wPass!'
```
->
```bash
▸ Setting password for 'admin1'…
docker compose exec -e NEW_PASS="MyN3wPass!" -T gitlab \
  gitlab-rails runner "\
u = User.find_by_username('admin1'); \
abort('User not found') unless u; \
u.password              = ENV['NEW_PASS']; \
u.password_confirmation = ENV['NEW_PASS']; \
u.save!; \
puts '✓  Password updated';"
WARN[0000] /mnt/c/Users/atom/Desktop/WSL PROJECTS/gitlab-nginx-docker-setup/docker-compose.yml: the attribute `version` is obsolete, it will be ignored, please remove it to avoid potential confusion 
✓  Password updated
```