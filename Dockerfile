FROM python:3.14-slim
WORKDIR /app

ARG APP_SOURCE=app.py
COPY ${APP_SOURCE} app.py

USER 10001:10001
EXPOSE 8080
CMD ["python", "-u", "app.py"]