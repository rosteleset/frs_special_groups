<?php

function frsApiCall(string $api_method, string $json_data)
{
    global $special_groups;
    global $id_sgroup;
    global $frs_api_url;

    $opts = array('http' =>
        array(
            'method'  => 'POST',
            'header'  => "Content-Type: application/json\r\n".'Authorization: Bearer ' . $special_groups[$id_sgroup]->group_api_token,
            'content' => $json_data
        )
    );
    $context = stream_context_create($opts);
    return file_get_contents($frs_api_url . $api_method, false, $context);
}

function curlFrsApiCall(string $api_method, string $json_data): array
{
    global $special_groups;
    global $id_sgroup;
    global $frs_api_url;

    $curl = curl_init();
    curl_setopt($curl, CURLOPT_URL, $frs_api_url . $api_method);
    curl_setopt($curl, CURLOPT_HTTPHEADER, array('Expect:', 'Accept: application/json', 'Content-Type: application/json',
        'Authorization: Bearer ' . $special_groups[$id_sgroup]->group_api_token));
    curl_setopt($curl, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($curl, CURLOPT_POSTFIELDS, $json_data);
    $result = curl_exec($curl);
    $response_code = curl_getinfo($curl, CURLINFO_RESPONSE_CODE);
    curl_close($curl);

    return array($response_code, $result);
}
