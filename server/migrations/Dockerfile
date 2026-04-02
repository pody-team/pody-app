FROM postgres:16-alpine

WORKDIR /migrations

COPY ./sql/services/identity_service.sql /migrations/identity_service.sql
COPY ./sql/services/identity_service_email_verification.sql /migrations/identity_service_email_verification.sql
COPY ./sql/services/identity_service_eventing.sql /migrations/identity_service_eventing.sql
COPY ./sql/services/identity_service_password_reset.sql /migrations/identity_service_password_reset.sql
COPY ./sql/services/notification_service.sql /migrations/notification_service.sql
COPY ./sql/services/content_service.sql /migrations/content_service.sql
COPY ./sql/services/content_service_demo_seed.sql /migrations/content_service_demo_seed.sql
COPY ./sql/services/ai_service.sql /migrations/ai_service.sql
COPY ./sql/services/article_service.sql /migrations/article_service.sql
COPY ./sql/services/article_service_demo_seed.sql /migrations/article_service_demo_seed.sql
COPY ./migrations/run-migrations.sh /usr/local/bin/run-migrations.sh

RUN apk add --no-cache dos2unix postgresql16-client && \
    dos2unix /usr/local/bin/run-migrations.sh && \
    chmod +x /usr/local/bin/run-migrations.sh

ENTRYPOINT ["/usr/local/bin/run-migrations.sh"]
