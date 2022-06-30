<?php

include 'auth.php';

if (!checkUserRight(ACCESS_RIGHT_USERS, JSON_CAN_WRITE))
{
    header('HTTP/1.1 403 Forbidden');
    exit();
}

if (!property_exists($object, JSON_USER_LOGIN) || !property_exists($object, JSON_USER_PASSWORD))
{
    header('HTTP/1.1 400 Bad Request');
    exit();
}

$user_login = $object->userLogin;
$user_password = $object->userPassword;
if (property_exists($object, JSON_USER_DESCRIPTION))
{
    $user_description = $object->userDescription;
}

$con = new mysqli($db_host, $db_user, $db_password, $db_database);
if ($con->connect_errno)
{
    header('HTTP/1.1 500 Internal Server Error');
    exit();
}

mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);
$con->begin_transaction();
try
{
    //добавление нового пользователя
    $query = "insert into users set login = ?, password = ?, id_sgroup = ?, description = ?";
    if ($stmt = $con->prepare($query))
    {
        $stmt->bind_param('ssis', $user_login, $user_password, $id_sgroup, $user_description);
        $stmt->execute();
        $stmt->close();
    }
    $id_new_user = $con->insert_id;

    //добавление прав пользователя
    if (property_exists($object, JSON_ACCESS_RIGHTS))
    {
        $query = "insert into user_rights set id_user = ?, id_right = ?, can_read = ?, can_write = ?";
        if ($stmt = $con->prepare($query))
        {
            foreach ($object->accessRights as &$value)
            {
                $stmt->bind_param('iiii', $id_new_user, $value->rightType, $value->canRead, $value->canWrite);
                $stmt->execute();
            }
            $stmt->close();
        }
    }

    $con->commit();
} catch(mysqli_sql_exception $exception)
{
    $con->rollback();
    $con->close();
    header('HTTP/1.1 500 Internal Server Error');
    exit();
}

$con->close();
