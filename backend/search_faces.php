<?php

/**
 * @api {post} /search_faces.php Сделать поиск в специальной группе
 * @apiName search_faces
 * @apiGroup _
 * @apiVersion 1.0.0
 *
 * @apiDescription **[в работе]**
 *
 * Производится поиск по зарегистрированным лицам специальной группы в сохранённых данных событий и журнале FRS.
 *
 * @apiParam {String} login имя пользователя
 * @apiParam {String} password пароль пользователя
 *
 * @apiParam {Number{0.0-1.0}} [similarity=0.55] параметр сходства; в результат попадают события, у которых сходство больше заданного
 *
 * @apiParamExample {json} Пример использования
 * {
 *   "login": "test",
 *   "password": "123123",
 *   "similarity": 0.55
 * }
 *
 * @apiSuccess {Object[]} result результат поиска: массив объектов
 * @apiSuccess {String="yyyy-MM-dd hh:mm:ss.zzz"} result.event_date дата события
 * @apiSuccess {String} result.event_id идентификатор кадра события из FRS
 * @apiSuccess {String} result.uuid идентификатор события бэкенда
 * @apiSuccess {Number} result.id_descriptor идентификатор дескриптора FRS
 * @apiSuccess {Number{0.0-1.0}} result.similarity сходство
 * @apiSuccess {String} result.url_image URL кадра события
 *
 * @apiSuccessExample {json} Пример результата выполнения
 * {
 *   "result:" [
 *     {
 *       "event_date": "2022-06-20 18:34:05",
 *       "event_id": "0e5c0e57ca44953934a7cb2506995092",
 *       "uuid": "",
 *       "id_descriptor": 123,
 *       "similarity": 0.711324,
 *       "url_image": "..."
 *     },
 *     {
 *       "event_date": "2022-06-20 15:57:21.089",
 *       "event_id": "d7b4783fac27c568e277f1c591f05a8e",
 *       "uuid": "13ab67cc-7989-403d-ab23-1a3ad52a2c74",
 *       "id_descriptor": 456,
 *       "similarity": 0.734981,
 *       "url_image": "..."
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

if (!checkUserRight(ACCESS_RIGHT_SEARCH, JSON_CAN_READ))
{
    header('HTTP/1.1 403 Forbidden');
    exit();
}

if (property_exists($object, JSON_SIMILARITY))
{
    $search_faces_tolerance = $object->similarity;
}

$key = "search" . $id_sgroup;
$redis = new Redis();

try
{
    $redis->connect($redis_host, $redis_port);
    if ($redis->get($key) == null)
    {
        $redis->set($key, 1, $special_groups[$id_sgroup]->search_timeout);
        $result = exec("$search_faces_cmd --events --frs_logs --config=$search_faces_config --group_id=$id_sgroup --tolerance=$search_faces_tolerance --output_type=json");
        echo($result);
    } else
    {
        header('HTTP/1.1 204 No Content');
        exit();
    }
} catch (Exception $e)
{
    $log_file = fopen("./logs.txt", "a");
    fwrite($log_file, $e . PHP_EOL);
    fclose($log_file);
    return false;
}
