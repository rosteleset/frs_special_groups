## Описание проекта
Данный проект представляет собой сервис поиска людей в специальных группах системы распознавания лиц ([FRS](https://github.com/rosteleset/frs)). Состоит из серверной части (бэкенда) и web-приложения (фронтенда). Бэкенд на PHP, фронтенд использует Flutter (в планах создать мобильное приложение). Фронтенд взаимодействует с бэкендом посредством вызова API методов. В данном описании мы будем исходить из того, что у вас уже имеется сервер с работающим FRS, а фронтенд и бэкенд будут размещены на этом же сервере.
Проект находится в стадии разработки.

### Настройка серверной части
Бэкенд использует Redis, PHP, MySQL. Все дальнейшие примеры команд приведены для Ubuntu.
Redis:
```bash
$ sudo apt-get install redis-server 
```
В файле /etc/redis/redis.conf вместо *supervised no* надо поставить *supervised systemd*. Далее:
```bash
$ sudo systemctl restart redis.service
```
Установка и настройка PHP:
```bash
$ sudo apt install php-fpm php-mysql php-redis php-curl
```
В файл php.ini добавить строку:
```
extension=redis.so
```
и перезапустить сервис PHP и веб-сервер (например, мы у себя используем nginx).

#### Сборка утилиты для поиска лиц
Для поиска лиц используются данные, которые генерирует и сохраняет в файлы FRS.
Клонируем репозиторий проекта:
```bash
$ cd ~
$ git clone --recurse-submodules https://github.com/rosteleset/frs_special_groups.git
```
Консольная утилита находится в папке *utils/search_faces*. Сборку можно сделать с помощью компилятора Clang или gcc. Если вы уже до этого выполнили сборку FRS, то для Clang:
```bash
$ export CC=clang-14
$ export CXX=clang++-14
$ export CXXFLAGS=-stdlib=libc++
$ cd ~/frs_special_groups/utils/search_faces && mkdir build && cd build
$ ~/cmake-3.23.1/bin/cmake \
-DCMAKE_BUILD_TYPE=Release \
-DBoost_USE_RELEASE_LIBS=ON \
-DBoost_USE_STATIC_LIBS=ON \
-DBoost_USE_STATIC_RUNTIME=ON \
-DBoost_NO_SYSTEM_PATHS=ON \
-DBOOST_INCLUDEDIR:PATH=$HOME/boost_1_79_0 \
-DBOOST_LIBRARYDIR:PATH=$HOME/boost_1_79_0/stage/lib \
..
$ make -j`nproc`
```
Для сборки с помощью gcc версии 11 или выше:
```bash
$ sudo apt-get install --yes libboost-system-dev libboost-date-time-dev libboost-program-options-dev libssl-dev libz-dev cmake
$ cd ~/frs_special_groups/utils/search_faces && mkdir build && cd build
$ cmake -DCMAKE_BUILD_TYPE=Release ..
```
Полученный исполняемый файл нужно положить в директорию к FRS так, чтобы полный путь к утилите был */opt/frs/search_faces/search_faces* В той же директории нужно создать файл search_faces.config и указать требуемые параметры. За основу лучше взять файл *utils/search_faces/search_faces.config.example*
Для просмотра параметров утилиты, запустите:
```bash
$ /opt/frs/search_faces/search_faces --help
```

#### БД бэкенда
Для работы бэкенда нужна своя отдельная MySQL база. Создать структуру БД и её первоначальное заполнение данными можно с помощью файла  *backend/mysql/db_dump.sql*. В базе появится пользователь с логином *test* и паролем *123123*, а также специальная группа с названием TestGroup.

#### Файлы бэкенда
PHP файлы расположены в папке *backend* репозитория. Настройка параметров находится в файле *config.php*. Все PHP файлы необходимо поместить в рабочую директорию веб-сервера, например, в */var/www/html/sg/*

#### Сборка фронтенда
Для сборки фронтенда требуется фреймворк Flutter.
```bash
$ cd ~
$ git clone https://github.com/rosteleset/frs_special_groups.git
$ cd frs_special_groups/frontend
$ flutter build web --web-renderer html --release --base-href "/sg/web/"
```
Собранное веб-приложение появится в директории *build/web*. Эту директорию нужно поместить на сервер в рабочую директорию веб-сервера, например, в */var/www/html/sg/*

#### Создание специальной группы в FRS
Для создания специальной группы нужно "вручную" вызвать API метод FRS **addSpecialGroup**. В параметре *groupName* указать *TestGroup*. В результате метод вернёт идентификатор созданной группы *groupId* (например, 1) и токен авторизации *accessApiToken* (например, 12341549-6789-01ab-c34e-5634567abcdf). Значение последнего нужно внести в поле *api_token* таблицы *sgroups* БД бэкенда.
Теперь FRS знает про новую спецгруппу, но не знает URL, по которому вызывать *callback* при распознавании лиц из этой группы. С помощью вызова API метода **sgUpdateGroup** и токена авторизации, указываем параметр callback, например, http://localhost/sg/sg_callback.php?group_id=1.

### Web-приложение
Приложение доступно в браузере по адресу *http(s)://host/sg/web/*
Для входа используйте имя пользователя *test*, пароль *123123*.

#### Регистрация лиц
Регистрировать новые лица можно с помощью кнопки "Добавить фото". В случае успешной регистрации в списке появится новая фотография и FRS. Когда FRS распознает зарегистрированное лицо, то сообщит об этом бэкенду посредством вызова callback (файл sg_callback.php). Получив кадр с распознанным лицом, бэкенд отправит его в чат-канал телеграмма с помощью бота. Вам нужно самостоятельно создать  или использовать существующий телеграм-бот и чат-канал, а также добавить бота в этот канал. Токен бота и идентификатор чат-канала задаются в полях *bot_token* и *chat_id* таблицы sgroups бэкенда.

#### Поиск лиц
Для поиска зарегистрированных лиц в прошедших событиях и журнале FRS используется кнопка "Поиск".  Параметр сходства определяет степень уверенности системы в том, что лицо в кадре похоже на зарегистрированную фотографию. Чем выше это значение, тем точнее результат поиска, но тем меньше кадров будет вам показано. Значение задаётся в диапазоне от 0,4 до 1. По умолчанию используется значение 0,55.
