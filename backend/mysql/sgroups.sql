-- auto-generated definition
create table sgroups
(
  id_sgroup      int            not null comment 'Идентификатор специальной группы'
    primary key,
  sgroup_name    varchar(100)   not null comment 'Уникальное название специальной группы',
  api_token      varchar(64)    not null comment 'Токен специальной группы для вызова API методов FRS',
  bot_token      varchar(64)    null comment 'Токен бота Telegram',
  chat_id        varchar(32)    null comment 'Идентификатор чата Telegram для отправки сообщений',
  search_timeout int default 30 not null comment 'Минимальный разрешенный интервал между запросами на поиск лиц из группы (в секундах)',
  constraint sgroups_api_token_uindex
    unique (api_token),
  constraint sgroups_id_sgroup_uindex
    unique (id_sgroup),
  constraint sgroups_sgroup_name_uindex
    unique (sgroup_name)
)
  comment 'Специальные группы и их параметры';
