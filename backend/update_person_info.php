<?php

include 'auth.php';

if (!checkUserRight(ACCESS_RIGHT_SEARCH, JSON_CAN_WRITE))
{
    header('HTTP/1.1 403 Forbidden');
    exit();
}

if (property_exists($object, JSON_FACE_ID))
{
    $face_id = $object->faceId;
    $person_info = $object->info;
} else
{
    header('HTTP/1.1 400 Bad Request');
    exit();
}

if ($person_info == null)
{
    $person_info = '';
}
if (strlen($person_info) > 250)
{
    $person_info = substr($person_info, 0, 250);
}

$con = new mysqli($db_host, $db_user, $db_password, $db_database);
if ($con->connect_errno)
{
    header('HTTP/1.1 500 Internal Server Error');
    exit();
}

$query = "replace into people_info set id_descriptor = ?, id_user = ?, info = ?, id_sgroup = ?";
if ($stmt = $con->prepare($query))
{
    $stmt->bind_param('iisi', $face_id, $id_user, $person_info, $id_sgroup);
    $stmt->execute();
    $stmt->close();
} else
{
    $con->close();
    header('HTTP/1.1 500 Internal Server Error');
    exit();
}

$con->close();
