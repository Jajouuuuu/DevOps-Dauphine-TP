FROM wordpress:latest

ENV WORDPRESS_DB_USER=wordpress
ENV WORDPRESS_DB_PASSWORD=ilovedevops
ENV WORDPRESS_DB_NAME=wordpress
ENV WORDPRESS_DB_HOST=35.193.197.162
ENV PORT=8080

EXPOSE 8080