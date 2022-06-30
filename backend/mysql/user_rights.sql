-- auto-generated definition
create table user_rights
(
  id_user   int               not null comment 'Идентификатор пользователя',
  id_right  int               not null comment 'Идентификатор типа доступа',
  can_read  tinyint default 1 not null comment 'Чтение',
  can_write tinyint default 0 not null comment 'Запись (управление)',
  primary key (id_user, id_right),
  constraint user_rights_id_right_fk
    foreign key (id_right) references access_right_types (id_right)
      on update cascade on delete cascade,
  constraint user_rights_id_user_fk
    foreign key (id_user) references users (id_user)
      on update cascade on delete cascade
)
  comment 'Права пользователей';
