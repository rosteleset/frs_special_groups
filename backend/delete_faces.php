<?php

/**
 * @api {post} /delete_faces.php Удалить зарегистрированные лица из специальной группы
 * @apiName delete_faces
 * @apiGroup _
 * @apiVersion 1.0.0
 *
 * @apiDescription **[в работе]**
 *
 * Фотографии безвозвратно удаляются из группы.
 *
 * @apiParam {String} login имя пользователя
 * @apiParam {String} password пароль пользователя
 *
 * @apiParam {Number[]} faces массив faceId (идентификаторов дескрипторов)
 *
 * @apiParamExample {json} Пример использования
 * {
 *   "login": "test",
 *   "password": "123123",
 *   "faces": [123, 234, 4567]
 * }
 *
 * @apiErrorExample {json} Ошибки
 * 401 Unauthorized
 * 403 Forbidden
 * 500 Internal Server Error
 */

include 'auth.php';
include 'frs_api.php';

if (!checkUserRight(ACCESS_RIGHT_SEARCH, JSON_CAN_WRITE))
{
    header('HTTP/1.1 403 Forbidden');
    exit();
}

list($response_code, $result) = curlFrsApiCall("sgDeleteFaces", file_get_contents("php://input"));
if ($response_code >= 200 && $response_code < 300)
{
    //удаляем информацию из базы
    if (property_exists($object, JSON_FACES))
    {
        $con = new mysqli($db_host, $db_user, $db_password, $db_database);
        if ($con->connect_errno)
        {
            header('HTTP/1.1 500 Internal Server Error');
            exit();
        }

        $faces = implode(', ', $object->faces);
        $query = "delete from people_info where id_descriptor in (" . $faces . ")";
        $con->query($query);
        $con->close();
    }
}
http_response_code($response_code);
echo($result);
