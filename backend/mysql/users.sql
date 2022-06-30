-- auto-generated definition
create table users
(
  id_user     int auto_increment comment 'Идентификатор пользователя'
    primary key,
  login       varchar(32)            not null comment 'Имя пользователя',
  password    varchar(64) default '' not null comment 'Пароль пользователя',
  id_sgroup   int                    null comment 'Идентификатор специальной группы, к которой принадлежит пользователь',
  description varchar(250)           null comment 'Описание пользователя',
  constraint users_login_uindex
    unique (login),
  constraint users_sgroups_id_sgroup_fk
    foreign key (id_sgroup) references sgroups (id_sgroup)
      on update cascade on delete cascade
)
  comment 'Зарегистрированные пользователи';
