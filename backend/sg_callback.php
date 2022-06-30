<?php

$body = file_get_contents("php://input");
$object = json_decode($body, false);
$id_sgroup = 0;
if (property_exists($object, JSON_GROUP_ID))
{
    $id_sgroup = $object->groupId;
} else
{
    $id_sgroup = $_GET["group_id"];
}

include 'auth.php';
include 'send_photo_telegram.php';
