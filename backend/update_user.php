<?php

include 'auth.php';

if (!checkUserRight(ACCESS_RIGHT_USERS, JSON_CAN_WRITE))
{
    header('HTTP/1.1 403 Forbidden');
    exit();
}

if (!property_exists($object, JSON_USER_ID))
{
    header('HTTP/1.1 400 Bad Request');
    exit();
}

$id_updating_user = $object->userId;

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
    //обновление данных пользователя
    $query = "select login, password, description from users where id_user = ? and id_sgroup = ?";
    if ($stmt = $con->prepare($query))
    {
        $stmt->bind_param("ii", $id_updating_user, $id_sgroup);
        $stmt->execute();
        $stmt->bind_result($user_login, $user_password, $user_description);
        if (!$stmt->fetch())  //пользователь не существует
        {
            $stmt->close();
            $con->close();
            header('HTTP/1.1 400 Bad Request');
            exit();
        }
        $stmt->close();
    }
    $do_update = false;
    if (property_exists($object, JSON_USER_LOGIN))
    {
        $do_update = true;
        $user_login = $object->userLogin;
    }
    if (property_exists($object, JSON_USER_PASSWORD))
    {
        $do_update = true;
        $user_password = $object->userPassword;
    }
    if (property_exists($object, JSON_USER_DESCRIPTION))
    {
        $do_update = true;
        $user_description = $object->userDescription;
    }

    if ($do_update)
    {
        //собственно, обновление данных в таблице users
        $query = "update users set login = ?, password = ?, description = ? where id_user = ?";
        if ($stmt = $con->prepare($query))
        {
            $stmt->bind_param('sssi', $user_login, $user_password, $user_description, $id_updating_user);
            $stmt->execute();
            $stmt->close();
        }
    }

    //обновление прав пользователя
    if (property_exists($object, JSON_ACCESS_RIGHTS))
    {
        //удаляем старые права
        $query = "delete from user_rights where id_user = " . $id_updating_user;
        $con->query($query);

        //добавляем новые права
        $query = "insert into user_rights set id_user = ?, id_right = ?, can_read = ?, can_write = ?";
        if ($stmt = $con->prepare($query))
        {
            foreach ($object->accessRights as &$value)
            {
                $stmt->bind_param('iiii', $id_updating_user, $value->rightType, $value->canRead, $value->canWrite);
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
