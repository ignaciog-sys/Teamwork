FROM python:3.12-slim

# Instalar dependencias del sistema
RUN apt-get update && apt-get install -y \
    build-essential \
    postgresql-client \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Directorio de trabajo
WORKDIR /workspace

# Copiar requirements
COPY requirements.txt .

# Instalar dependencias Python
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copiar código
COPY . .

# Crear directorios
RUN mkdir -p logs data/{raw,processed,sample}

# Ejecutar tests al construir (opcional)
# RUN pytest src/tests/ -v

CMD ["python"]