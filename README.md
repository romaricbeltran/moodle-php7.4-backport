# Moodle PHP 7.4 Backport

Custom PHP 7.4.33 runtime for Moodle 3.10, rebuilt from the official PHP source tree and patched with the upstream fix from commit 712e60f.

This project provides a Dockerized PHP-FPM runtime designed to keep an existing Moodle installation running on a legacy but still needed PHP stack, while reducing risk by applying a targeted upstream security backport.

## Why this project exists

- Keep Moodle 3.10 compatible with PHP 7.4 during a controlled migration window.
- Rebuild PHP from source instead of relying on the host system installation.
- Apply the upstream security patch before compilation.
- Isolate the runtime in Docker while keeping Apache and MariaDB/MySQL on the host.
- Make rebuilds and validation easier for future maintenance.

> Warning: PHP 7.4 and Debian Buster are end-of-life components. This project is a compatibility and risk-reduction measure, not a replacement for a maintained software stack. A supported Moodle and PHP upgrade remains the recommended long-term path.

## Architecture

Moodle runs on the host. The container provides only the PHP runtime through PHP-FPM.

```text
                 Browser
                     |
                    HTTPS
                     |
           +-------------------------+
           | Apache (host)           |
           | TLS / vhosts / proxy    |
           +-------------------------+
                     |
          FastCGI / TCP 127.0.0.1:9001
                     |
           +-------------------------+
           | Docker                  |
           | PHP-FPM 7.4.33         |
           | Backported patch        |
           +-------------------------+
                     |
           +-------------------------+
           | /var/www/moodle         |
           | Moodle code             |
           +-------------------------+
                     |
           +-------------------------+
           | /var/www/moodledata     |
           | Moodle data files       |
           +-------------------------+
                     |
                 MariaDB/MySQL
                 on the host
```

## Security patch

The project applies the upstream patch from the official php/php-src repository:

- Commit: 712e60f
- Summary: upstream fix for state corruption and stale memory reuse issues
- Relevant advisories:
  - CVE-2026-109618
  - CVE-2026-109619

This patch is applied to the PHP 7.4.33 source tree before compilation, so the compiled binary contains the fix rather than relying on a copied runtime patch alone.

## Repository layout

```text
moodle-php7.4-backport/
├── Dockerfile
├── 712e60f.patch
├── php-src/
├── fpm-conf/
│   ├── php-fpm.conf
│   └── pool.d/
│       └── www.conf
├── README.MD
└── .gitignore
```

Key files:

- `Dockerfile`: builds the PHP runtime and installs required extensions.
- `712e60f.patch`: upstream security backport.
- `php-src/`: PHP source used for compilation.
- `fpm-conf/`: PHP-FPM runtime and pool configuration.

## Build the image

From the repository root:

```bash
docker build --pull --no-cache \
  -t php74-backport:7.4.33 .
```

To keep build logs:

```bash
docker build --pull --no-cache --progress=plain \
  -t php74-backport:7.4.33 . \
  2>&1 | tee build.log
```

## Run the container

```bash
docker rm -f moodle-php74 2>/dev/null || true

docker run -d \
  --name moodle-php74 \
  --restart unless-stopped \
  -p 127.0.0.1:9001:9000 \
  -v /var/www/moodle:/var/www/moodle \
  -v /var/www/moodledata:/var/www/moodledata \
  -v "$PWD/fpm-conf/php-fpm.conf:/usr/local/etc/php-fpm.conf:ro" \
  -v "$PWD/fpm-conf/pool.d:/usr/local/etc/php-fpm.d:ro" \
  --entrypoint php-fpm \
  php74-backport:7.4.33 \
  -F
```

Validate the service:

```bash
docker ps --filter name=moodle-php74
docker logs --tail 50 moodle-php74
docker exec moodle-php74 php-fpm -tt
ss -lntp | grep ':9001'
```

## Apache configuration

Apache stays on the host and proxies PHP requests to the container via FastCGI.

1. Enable the required modules:

```bash
sudo a2enmod proxy proxy_fcgi
```

2. Disable the host PHP module if needed:

```bash
sudo a2dismod php7.4
```

3. Configure the Moodle vhost:

```apache
<Directory /var/www/moodle>
    Options FollowSymLinks
    AllowOverride All
    Require all granted

    <FilesMatch "\.php$">
        SetHandler "proxy:fcgi://127.0.0.1:9001"
    </FilesMatch>
</Directory>
```

4. Validate and reload Apache:

```bash
sudo apache2ctl configtest
sudo systemctl reload apache2
```

If Apache returns 502 or 503, check both the Apache and PHP-FPM logs.

## MariaDB/MySQL connectivity

The database remains on the host, so PHP-FPM must connect to a reachable host address rather than `localhost`.

### 1. Identify the Docker gateway

```bash
docker inspect moodle-php74 \
  --format '{{range .NetworkSettings.Networks}}Gateway: {{.Gateway}}{{end}}'
```

### 2. Check the database listener

```bash
sudo ss -lntp | grep ':3306'
```

If MariaDB/MySQL listens only on 127.0.0.1, Docker cannot reach it. Adjust the bind address if needed, but avoid exposing the database port broadly.

### 3. Create a dedicated database user

```sql
CREATE USER 'moodle_app'@'172.17.0.2'
IDENTIFIED BY 'REPLACE_WITH_A_STRONG_SECRET';

GRANT ALL PRIVILEGES ON moodle_db.*
TO 'moodle_app'@'172.17.0.2';
```

Update the example values to match your environment and the actual Docker source address.

### 4. Update Moodle configuration

In `/var/www/moodle/config.php`, set the database host to a reachable address, for example:

```php
$CFG->dbhost = '172.17.0.1';
```

### 5. Validate connectivity

```bash
docker exec moodle-php74 php -r '
$s = @fsockopen("172.17.0.1", 3306, $errno, $errstr, 3);
if ($s) {
    echo "MariaDB TCP connection successful\n";
    fclose($s);
} else {
    echo "Connection failed: $errstr ($errno)\n";
}
'
```

This confirms TCP reachability only; also test real authentication with the Moodle database account and verify that the application works.

## Testing checklist

After deployment, validate the following:

- The Docker image builds successfully.
- PHP reports the expected version.
- The source provenance and patch are documented.
- Required Moodle extensions are loaded.
- PHP-FPM is running and listening on the correct port.
- Apache forwards requests to PHP-FPM.
- Moodle and moodledata paths match between host and container.
- Filesystem permissions are compatible with `www-data`.
- The database is reachable from Docker.
- The dedicated database account has the required grants.
- Core Moodle features and cron tasks work as expected.

Useful log checks:

```bash
docker logs --tail 100 moodle-php74
sudo journalctl -u apache2 --since "10 minutes ago"
sudo journalctl -u mariadb --since "10 minutes ago"
```

## References

- Project repository: https://github.com/romaricbeltran/moodle-php7.4-backport
- Upstream patch commit: https://github.com/php/php-src/commit/712e60f
- PHP 7.4 backport branch: https://github.com/php/php-src/tree/PHP-7.4-CVE-2026-109618-109619
- CVE-2026-109618 advisory: https://github.com/php/php-src/security/advisories/GHSA-w8hw-w9fx-j79w
- CVE-2026-109619 advisory: https://github.com/php/php-src/security/advisories/GHSA-6wmf-4rv5-p3rp
- Moodle PHP documentation: https://docs.moodle.org/503/en/PHP
- Moodle 3.10 release notes: https://docs.moodle.org/dev/Moodle_3.10_release_notes

## Project status

This project provides a custom PHP 7.4 runtime for Moodle 3.10, built from source and paired with a backported security patch. Final validation depends on the source tree, compiled binary, configured extensions, deployment topology and real runtime testing.

It is a pragmatic compatibility layer for an older but still necessary stack. A supported Moodle, PHP and OS upgrade remains the preferred long-term solution.

