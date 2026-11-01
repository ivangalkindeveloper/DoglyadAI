FROM postgres:17-bookworm
RUN apt-get update \
    && apt-get install -y --no-install-recommends pgbackrest ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && install -d -o postgres -g postgres -m 0700 /var/log/pgbackrest /var/spool/pgbackrest
