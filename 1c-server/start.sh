#!/bin/bash

# Автоматически определяем путь к установленной версии 1С
# Это сработает для любой версии, которую вы установите в образ.
EXEC_PATH=$(find /opt/1cv8/x86_64 -mindepth 1 -maxdepth 1 -type d)

# Путь к данным сервера 1С
DATA_PATH="/home/usr1cv8/.1cv8/1C/1cv8"

# Функция для корректного завершения работы
_term() {
  echo "Caught SIGTERM or SIGINT signal, shutting down..."
  # Посылаем сигнал SIGINT процессу ras, как рекомендуется
  kill -INT $RAS_PID
  # Посылаем стандартный SIGTERM процессу ragent
  kill -TERM $RAGENT_PID
  # Ждем завершения обоих процессов
  wait $RAGENT_PID
  wait $RAS_PID
  echo "Shutdown complete."
  exit 0
}

# Устанавливаем ловушку на сигналы SIGTERM и SIGINT
trap _term SIGTERM SIGINT

# 1. Запускаем главного агента сервера 1С в фоновом режиме
echo "Starting ragent..."
$EXEC_PATH/ragent -d $DATA_PATH &
RAGENT_PID=$! # Сохраняем PID процесса

# Надежно ожидаем, пока ragent запустится и откроет порт 1541
echo "Waiting for ragent to start..."
while ! nc -z localhost 1541; do
  sleep 1 # ждем 1 секунду перед следующей проверкой
done
echo "ragent started."

# Проверяем, был ли уже создан администратор кластера.
# Если файл srv1cv83 не существует, значит это первый запуск.
if [ ! -f "$DATA_PATH/srv1cv83" ]; then
    echo "First run detected. Creating cluster administrator..."
    sleep 5 # Дополнительная пауза на всякий случай перед созданием администратора
    
    # Ищем ID кластера по умолчанию
    CLUSTER_ID=$($EXEC_PATH/rac cluster list | awk -F: '/cluster/ {print $2}' | sed 's/ //g')

    if [ -n "$CLUSTER_ID" ]; then
        echo "Found cluster ID: $CLUSTER_ID"
        # Создаем администратора кластера с данными из переменных окружения
        $EXEC_PATH/rac cluster admin register --cluster=$CLUSTER_ID --name=$C1_ADMIN_USER --pwd=$C1_ADMIN_PWD
        echo "Cluster administrator '$C1_ADMIN_USER' created."
    else
        echo "Could not find cluster ID. Administrator not created."
    fi
fi

# 2. Запускаем сервис удаленного администрирования (ras) в основном режиме
# Он будет слушать на порту 1542 и проксировать запросы к кластеру,
# который работает на localhost:1541
echo "Starting ras gateway..."
$EXEC_PATH/ras --port=1542 cluster --cluster=localhost:1541 &
RAS_PID=$!

# Ожидаем завершения фоновых процессов
# wait -n будет ждать любого из дочерних процессов
wait -n
# Сохраняем код выхода завершившегося процесса
EXIT_CODE=$?
echo "One of the processes has exited with code $EXIT_CODE. Shutting down..."
# Вызываем нашу функцию для корректной остановки остальных
_term