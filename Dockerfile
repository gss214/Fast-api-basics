FROM python:3.10.12
WORKDIR /app
COPY requirements.txt .
RUN pip install --upgrade pip
RUN pip install --progress-bar off --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 80
CMD ["uvicorn", "app/main:app", "--host", "0.0.0.0", "--port", "80"]