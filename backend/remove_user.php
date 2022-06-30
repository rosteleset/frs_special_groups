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

$id_removing_user = $object->userId;

$con = new mysqli($db_host, $db_user, $db_password, $db_database);
if ($con->connect_errno)
{
    header('HTTP/1.1 500 Internal Server Error');
    exit();
}

$query = "delete from users where id_user = ? and id_sgroup = ?";
if ($stmt = $con->prepare($query))
{
    $stmt->bind_param("ii", $id_removing_user, $id_sgroup);
    $stmt->execute();
    if ($stmt->affected_rows == 0)
    {
        header('HTTP/1.1 400 Bad Request');
    }
    $stmt->close();
}

$con->close();
