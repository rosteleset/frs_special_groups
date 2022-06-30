<?php

include 'auth.php';

if (!checkUserRight(ACCESS_RIGHT_SEARCH, JSON_CAN_READ))
{
    header('HTTP/1.1 403 Forbidden');
    exit();
}

$con = new mysqli($db_host, $db_user, $db_password, $db_database);
if ($con->connect_errno)
{
    header('HTTP/1.1 500 Internal Server Error');
    exit();
}

$query = "select id_descriptor, info from people_info where id_sgroup = " . $id_sgroup;
if ($res = $con->query($query))
{
    $result = [];
    while ($row = $res->fetch_row())
    {
        $result[] = array(JSON_FACE_ID => intval($row[0]), JSON_INFO => $row[1]);
    }
    echo(json_encode($result));
}

$con->close();
