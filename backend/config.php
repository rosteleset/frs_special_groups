<?php

//константы
const JSON_LOGIN = 'login';
const JSON_PASSWORD = 'password';
const JSON_ACCESS_RIGHTS = 'accessRights';
const JSON_RIGHT_TYPE = 'rightType';
const JSON_CAN_READ = 'canRead';
const JSON_CAN_WRITE = 'canWrite';
const JSON_FACE_ID = 'faceId';
const JSON_INFO = 'info';
const JSON_GROUP_NAME= 'groupName';
const JSON_GROUP_API_TOKEN = 'groupApiToken';
const JSON_SIMILARITY ='similarity';
const JSON_GROUP_ID = 'groupId';
const JSON_USER_ID = 'userId';
const JSON_USER_LOGIN = 'userLogin';
const JSON_USER_PASSWORD = 'userPassword';
const JSON_USER_DESCRIPTION = 'userDescription';

//классы
class GroupData
{
    public string $group_name;
    public string $group_api_token;
    public string $bot_token;
    public string $chat_id;
    public int $search_timeout;
}

class UserData
{
    public string $password;
    public int $id_sgroup;
}

//параметры
$db_host = "localhost";
$db_user = "user_sg";
$db_password = "123123";
$db_database = "db_sg";

$frs_api_url = "http://localhost:9051/sgapi/";

$redis_host = "127.0.0.1";
$redis_port = 6379;
$timeout = 10;
$caption = "Сервис поиска людей";
$search_faces_cmd = "/opt/frs/search_faces/search_faces_new";
$search_faces_config = "/opt/frs/search_faces/search_faces.config";
$search_faces_tolerance = "0.55";

$special_groups = [];
