<?php

//константы
const ACCESS_RIGHT_ALL = 1;
const ACCESS_RIGHT_USERS = 2;
const ACCESS_RIGHT_SEARCH = 3;
const CAN_READ = "can_read";
const CAN_WRITE = "can_write";

//проверка прав доступа пользователя
function checkUserRight(int $id_right, string $can_what): bool
{
    global $data;
    $result = false;
    foreach ($data[JSON_ACCESS_RIGHTS] as &$value)
    {
        if (($value[JSON_RIGHT_TYPE] == ACCESS_RIGHT_ALL || $value[JSON_RIGHT_TYPE] == $id_right) && $value[$can_what] == 1)
        {
            $result = true;
        }
    }

    return $result;
}

include 'config.php';
$body = file_get_contents("php://input");
$object = json_decode($body, false);
if (property_exists($object, JSON_LOGIN))
{
    $login = $object->login;
}
if (property_exists($object, JSON_PASSWORD))
{
    $password = $object->password;
}

$con = new mysqli($db_host, $db_user, $db_password, $db_database);
if ($con->connect_errno)
{
    header('HTTP/1.1 500 Internal Server Error');
    exit();
}
if (!isset($id_sgroup) && isset($login) && isset($password))
{
    $query = "select id_user, id_sgroup from users where login = ? and password = ?";
    if ($stmt = $con->prepare($query))
    {
        $stmt->bind_param('ss', $login, $password);
        $stmt->execute();
        $stmt->bind_result($id_user, $id_sgroup);
        $stmt->fetch();
        $stmt->close();
    } else
    {
        $con->close();
        header('HTTP/1.1 500 Internal Server Error');
        exit();
    }
}
if (isset($id_sgroup) && $id_sgroup > 0)
{
    $query = "select sgroup_name, api_token, bot_token, chat_id, search_timeout from sgroups where id_sgroup = ?";
    if ($stmt = $con->prepare($query))
    {
        $stmt->bind_param('i', $id_sgroup);
        $stmt->execute();
        $stmt->bind_result($sgroup_name, $api_token, $bot_token, $chat_id, $search_timeout);
        $stmt->fetch();
        $stmt->close();
        $special_groups[$id_sgroup] = new GroupData();
        $special_groups[$id_sgroup]->group_name = $sgroup_name;
        $special_groups[$id_sgroup]->group_api_token = $api_token;
        $special_groups[$id_sgroup]->bot_token = $bot_token;
        $special_groups[$id_sgroup]->chat_id = $chat_id;
        $special_groups[$id_sgroup]->search_timeout = $search_timeout;

        header('Content-Type: application/json; charset=utf-8');
    } else
    {
        $con->close();
        header('HTTP/1.1 500 Internal Server Error');
        exit();
    }
} else
{
    $con->close();
    header('HTTP/1.1 401 Unauthorized');
    exit();
}

//права пользователя
$data[JSON_ACCESS_RIGHTS] = [];
$query = "select id_right, can_read, can_write from user_rights where id_user = ?";
if ($stmt = $con->prepare($query))
{
    $stmt->bind_param('i', $id_user);
    $stmt->execute();
    $result = $stmt->get_result();
    while ($row = mysqli_fetch_array($result, MYSQLI_ASSOC))
    {
        $data[JSON_ACCESS_RIGHTS][] = array(JSON_RIGHT_TYPE => $row["id_right"], JSON_CAN_READ => $row["can_read"],
            JSON_CAN_WRITE => $row["can_write"]);
    }
}

$con->close();
