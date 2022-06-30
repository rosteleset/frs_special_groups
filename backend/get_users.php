<?php

include 'auth.php';

if (!checkUserRight(ACCESS_RIGHT_USERS, JSON_CAN_READ))
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

$query2 = "select id_right, can_read, can_write from user_rights where id_user = ?";
$stmt2 = $con->prepare($query2);
$stmt2->bind_param('i', $id_user2);
$query = "select id_user, login, description from users where id_sgroup = " . $id_sgroup;
if ($res = $con->query($query))
{
    $result = [];
    while ($row = $res->fetch_row())
    {
        $id_user2 = $row[0];
        mysqli_stmt_execute($stmt2);
        $res2 = $stmt2->get_result();
        $result2 = [];
        while ($row2 = mysqli_fetch_array($res2, MYSQLI_ASSOC))
        {
            $result2[] = array(JSON_RIGHT_TYPE => $row2["id_right"], JSON_CAN_READ => $row2["can_read"],
                JSON_CAN_WRITE => $row2["can_write"]);
        }
        $r = [];
        $r[JSON_USER_ID] = $id_user2;
        $r[JSON_USER_LOGIN] = $row[1];
        if ($row[2] != null)
        {
            $r[JSON_USER_DESCRIPTION] = $row[2];
        }
        if (!empty($result2))
        {
            $r[JSON_ACCESS_RIGHTS] = $result2;
        }
        $result[] = $r;
    }
    echo(json_encode($result));
}

$con->close();
