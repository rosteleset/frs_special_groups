--- Redis (https://redis.io/topics/quickstart) ---

$ sudo apt-get install redis-server
$ sudo apt-get install php-redis

/etc/redis/redis.conf
вместо:
supervised no 
надо:
supervised systemd

$ sudo systemctl restart redis.service

или

$ wget http://download.redis.io/redis-stable.tar.gz
$ tar xvzf redis-stable.tar.gz
$ cd redis-stable
$ make

Запусе сервера:
$ redis-server


--- PHP ---
$ sudo apt install php-fpm php-mysql php-curl
в файл /etc/php/7.4/fpm/php.ini добавить строку:
extension=redis.so

$ sudo service php7.4-fpm restart
$ sudo service nginx restart
