<?php

$face_id = $object->faceId;
$screenshot = $object->screenshot;
$date = $object->date;

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
        $data = [
            'chat_id' => $chat_id,
            'caption' => $caption . " [" . $date . "]",
            'photo' => $screenshot
        ];
        $response = file_get_contents("https://api.telegram.org/bot$bot_token/sendPhoto?" . http_build_query($data));
        $r = json_decode($response, false);
        if ($r->ok)
            $redis->set($key, 1, $timeout);
    } else
    {
        echo "already sent\n";
    }
} catch (Exception $e)
{
    $log_file = fopen("./logs.txt", "a");
    fwrite($log_file, $e . PHP_EOL);
    fclose($log_file);
    return false;
}
