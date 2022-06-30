<?php

/**
 * @api {post} /register_face.php Зарегистрировать лицо на фотографии в специальной группе
 * @apiName register_face
 * @apiGroup _
 * @apiVersion 1.0.0
 *
 * @apiDescription **[в работе]**
 *
 * @apiParam {String} login имя пользователя
 * @apiParam {String} password пароль пользователя
 *
 * @apiParam {String} url URL изображения для регистрации
 * @apiParam {Number} [left=0] координата X левого верхнего угла прямоугольной области лица
 * @apiParam {Number} [top=0] координата Y левого верхнего угла прямоугольной области лица
 * @apiParam {Number} [width="0 (вся ширина изображения)"] ширина прямоугольной области лица
 * @apiParam {Number} [height="0 (вся высота изображения)"] высота прямоугольной области лица
 *
 * @apiParamExample {json} Пример 1
 * {
 *   "login": "test",
 *   "password": "123123",
 *   "url": "https://host/imageToRegister",
 *   "left": 537,
 *   "top": 438,
 *   "width": 142,
 *   "height": 156
 * }
 *
 * @apiSuccess {Number} code код ответа
 * @apiSuccess {String} name заголовок ответа
 * @apiSuccess {String} message комментарий ответа
 * @apiSuccess {Object} [data] массив объектов
 * @apiSuccess {Number} data.faceId идентификатор зарегистрированного дескриптора
 * @apiSuccess {String} data.faceImage URL изображения лица зарегистрированного дескриптора
 * @apiSuccess {Number} data.left координата X левого верхнего угла прямоугольной области лица
 * @apiSuccess {Number} data.top координата Y левого верхнего угла прямоугольной области лица
 * @apiSuccess {Number} data.width ширина прямоугольной области лица
 * @apiSuccess {Number} data.height высота прямоугольной области лица
 *
 * @apiSuccessExample {json} Пример результата выполнения
 * {
 *   "code": 200,
 *   "name": "OK",
 *   "message": "запрос выполнен",
 *   "data": {
 *     "faceId": 4567,
 *     "faceImage": "data:image/jpeg,base64,...",
 *     "left": 537,
 *     "top": 438,
 *     "width": 142,
 *     "height": 156
 *   }
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

list($response_code, $result) = curlFrsApiCall("sgRegisterFace", file_get_contents("php://input"));
http_response_code($response_code);
echo($result);
