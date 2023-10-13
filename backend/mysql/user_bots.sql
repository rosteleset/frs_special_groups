-- auto-generated definition
create table user_bots
(
    id_user   int         not null comment 'Идентификатор пользователя'
        primary key,
    bot_token varchar(64) null comment 'Токен бота Telegram',
    chat_id   varchar(32) null comment 'Идентификатор чата Telegram для отправки сообщений',
    constraint user_bots_id_user_fk
        foreign key (id_user) references users (id_user)
            on update cascade on delete cascade
)
    comment 'Привязки ботов к пользователям';
