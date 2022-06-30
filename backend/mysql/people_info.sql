-- auto-generated definition
create table people_info
(
  id_descriptor int          not null comment 'Идентификатор дескриптора лица в FRS',
  id_user       int          null comment 'Пользователь, который добавил фотографию человека',
  info          varchar(250) null comment 'Информация о человеке',
  id_sgroup     int          not null comment 'Идентификатор специальной группы',
  primary key (id_descriptor, id_sgroup),
  constraint people_info_sgroups_id_sgroup_fk
    foreign key (id_sgroup) references sgroups (id_sgroup)
      on update cascade on delete cascade,
  constraint people_info_users_id_user_fk
    foreign key (id_user) references users (id_user)
      on update cascade on delete set null
)
  comment 'Информация о разыскиваемых людях';
