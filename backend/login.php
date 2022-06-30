<?php

include 'auth.php';

$data[JSON_GROUP_NAME] = $special_groups[$id_sgroup]->group_name;
$data[JSON_GROUP_API_TOKEN] = $special_groups[$id_sgroup]->group_api_token;
echo(json_encode($data));
