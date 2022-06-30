-- auto-generated definition
create table access_right_types
(
  id_right   int auto_increment comment 'Идентификатор типа доступа'
    primary key,
  right_name varchar(100) not null comment 'Название типа доступа',
  constraint access_right_types_right_name_uindex
    unique (right_name)
)
  comment 'Типы прав доступа';
