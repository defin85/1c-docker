FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

# Создаем пользователя и группу
RUN groupadd --system usr1cv8 && \
    useradd --system --no-create-home --gid usr1cv8 usr1cv8

# Устанавливаем зависимости
RUN apt-get update && \
    echo "ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true" | debconf-set-selections && \
    apt-get install -y \
    imagemagick \
    unixodbc \
    ttf-mscorefonts-installer \
    locales \
    net-tools \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Настраиваем локаль
RUN locale-gen ru_RU.UTF-8
ENV LANG=ru_RU.UTF-8
ENV LANGUAGE=ru_RU:ru
ENV LC_ALL=ru_RU.UTF-8

# Копируем дистрибутивы
COPY ./distr/*.deb /tmp/1c-distr/

# Устанавливаем все пакеты 1С
RUN dpkg -i /tmp/1c-distr/*.deb && rm -rf /tmp/1c-distr

# Создаем директории и назначаем права
RUN mkdir -p /var/log/1c /home/usr1cv8/.1cv8 && \
    chown -R usr1cv8:usr1cv8 /var/log/1c /home/usr1cv8/.1cv8

# Копируем наш новый скрипт запуска и делаем его исполняемым
COPY start.sh /opt/1cv8/start.sh
RUN chmod +x /opt/1cv8/start.sh

# Открываем все нужные порты, включая 1542 для RAS
EXPOSE 1540 1541 1542 1560-1591

# Меняем пользователя
USER usr1cv8

# Указываем volume
VOLUME ["/home/usr1cv8/.1cv8"]

# Запускаем наш скрипт
CMD ["/opt/1cv8/start.sh"]