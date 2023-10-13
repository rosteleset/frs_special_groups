<?php

$face_id = $object->faceId;
$screenshot = $object->screenshot;
$date = $object->date;
$person_info = $object->personInfo;
$event_info = $object->eventInfo;
if ($face_id == null || $screenshot == null || $date == null || $id_sgroup == 0 || $id_sgroup == "")
    return false;

$key = "key" . $face_id;
$redis = new Redis();
try
{
    $bot_token = $special_groups[$id_sgroup]->bot_token;
    $chat_id = $special_groups[$id_sgroup]->chat_id;
    $redis->connect($redis_host, $redis_port);
    if ($redis->get($key) == null)
    {
        $msg = $caption . " [" . $date . "]";
        if ($person_info == "")
        {
            $con = new mysqli($db_host, $db_user, $db_password, $db_database);
            if (!$con->connect_errno)
            {
                $query = "select info from people_info where id_sgroup = " . $id_sgroup . " and id_descriptor = " . $face_id;
                if ($res = $con->query($query))
                {
                    if ($row = $res->fetch_row())
                        $person_info = $row[0];
                }
                $con->close();
            }
        }
        if ($person_info != "")
            $msg = $msg . "\n" . $person_info;
        if ($event_info != "")
            $msg = $msg . "\n" . $event_info;
        $data = [
            'chat_id' => $chat_id,
            'caption' => $msg,
            'photo' => $screenshot
        ];

        $curl = curl_init();
        curl_setopt($curl, CURLOPT_URL, "https://api.telegram.org/bot$bot_token/sendPhoto?" . http_build_query($data, '', '&'));
        $result = curl_exec($curl);
        $response_code = curl_getinfo($curl, CURLINFO_RESPONSE_CODE);
        curl_close($curl);
        if ($response_code == 200)
           $redis->set($key, 1, $timeout);
        http_response_code($response_code);
    }
} catch (Exception $e)
{
    $log_file = fopen("./logs.txt", "a");
    fwrite($log_file, $e . PHP_EOL);
    fclose($log_file);
    return false;
}
