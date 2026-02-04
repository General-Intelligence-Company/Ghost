# MySQL 8.0 Docker image for Render deployment
# Based on https://github.com/render-examples/mysql
FROM mysql:8.0

# Set default MySQL configuration for Ghost
# These can be overridden via environment variables
ENV MYSQL_DATABASE=ghost
ENV MYSQL_USER=ghost

# Expose MySQL port
EXPOSE 3306

# Use the default MySQL entrypoint and command
CMD ["mysqld"]
