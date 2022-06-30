<?php

include 'auth.php';

if (!checkUserRight(ACCESS_RIGHT_SEARCH, JSON_CAN_READ))
{
    header('HTTP/1.1 403 Forbidden');
    exit();
}

include 'send_photo_telegram.php';
