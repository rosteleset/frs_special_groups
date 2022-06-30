<?php

/**
 * @api {post} /list_faces.php Получить список зарегистрированных лиц в специальной группе
 * @apiName list_faces
 * @apiGroup _
 * @apiVersion 1.0.0
 *
 * @apiDescription **[в работе]**
 *
 * @apiParam {String} login имя пользователя
 * @apiParam {String} password пароль пользователя
 *
 * @apiParamExample {json} Пример использования
 * {
 *   "login": "test",
 *   "password": "123123"
 * }
 *
 * @apiSuccess {Number} code код ответа
 * @apiSuccess {String} name заголовок ответа
 * @apiSuccess {String} message комментарий ответа
 * @apiSuccess {Object[]} [data] массив объектов
 * @apiSuccess {Number} data.faceId идентификатор дескриптора
 * @apiSuccess {String} data.faceImage URL изображения лица
 *
 * @apiSuccessExample {json} Пример результата выполнения
 * {
 *   "code": 200,
 *   "name": "OK",
 *   "message": "запрос выполнен",
 *   "data:" [
 *     {
 *       "faceId": 123,
 *       "faceImage": "data:image/jpeg,base64,..."
 *     },
 *     {
 *       "faceId": 456,
 *       "faceImage": "data:image/jpeg,base64,..."
 *     },
 *     {
 *       "faceId": 789,
 *       "faceImage": "data:image/jpeg,base64,..."
 *     }
 *   ]
 * }
 *
 * @apiErrorExample {json} Ошибки
 * 401 Unauthorized
 * 403 Forbidden
 * 500 Internal Server Error
 */

include 'auth.php';
include 'frs_api.php';

if (!checkUserRight(ACCESS_RIGHT_SEARCH, JSON_CAN_READ))
{
    header('HTTP/1.1 403 Forbidden');
    exit();
}

list($response_code, $result) = curlFrsApiCall("sgListFaces", file_get_contents("php://input"));
http_response_code($response_code);
echo($result);
