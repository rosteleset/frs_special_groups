/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `access_right_types`
--

DROP TABLE IF EXISTS `access_right_types`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `access_right_types` (
  `id_right` int NOT NULL AUTO_INCREMENT COMMENT 'Идентификатор типа доступа',
  `right_name` varchar(100) NOT NULL COMMENT 'Название типа доступа',
  PRIMARY KEY (`id_right`),
  UNIQUE KEY `access_right_types_right_name_uindex` (`right_name`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='Типы прав доступа';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `access_right_types`
--

LOCK TABLES `access_right_types` WRITE;
/*!40000 ALTER TABLE `access_right_types` DISABLE KEYS */;
INSERT INTO `access_right_types` VALUES (1,'Все разделы'),(2,'Раздел пользователей'),(3,'Раздел поиска людей');
/*!40000 ALTER TABLE `access_right_types` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `people_info`
--

DROP TABLE IF EXISTS `people_info`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `people_info` (
  `id_descriptor` int NOT NULL COMMENT 'Идентификатор дескриптора лица в FRS',
  `id_user` int DEFAULT NULL COMMENT 'Пользователь, который добавил фотографию человека',
  `info` varchar(250) DEFAULT NULL COMMENT 'Информация о человеке',
  `id_sgroup` int NOT NULL COMMENT 'Идентификатор специальной группы',
  PRIMARY KEY (`id_descriptor`,`id_sgroup`),
  KEY `people_info_users_id_user_fk` (`id_user`),
  KEY `people_info_sgroups_id_sgroup_fk` (`id_sgroup`),
  CONSTRAINT `people_info_sgroups_id_sgroup_fk` FOREIGN KEY (`id_sgroup`) REFERENCES `sgroups` (`id_sgroup`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `people_info_users_id_user_fk` FOREIGN KEY (`id_user`) REFERENCES `users` (`id_user`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='Информация о разыскиваемых людях';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sgroups`
--

DROP TABLE IF EXISTS `sgroups`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sgroups` (
  `id_sgroup` int NOT NULL COMMENT 'Идентификатор специальной группы',
  `sgroup_name` varchar(100) NOT NULL COMMENT 'Уникальное название специальной группы',
  `api_token` varchar(64) NOT NULL COMMENT 'Токен специальной группы для вызова API методов FRS',
  `bot_token` varchar(64) DEFAULT NULL COMMENT 'Токен бота Telegram',
  `chat_id` varchar(32) DEFAULT NULL COMMENT 'Идентификатор чата Telegram для отправки сообщений',
  `search_timeout` int NOT NULL DEFAULT '30' COMMENT 'Минимальный разрешенный интервал между запросами на поиск лиц из группы (в секундах)',
  PRIMARY KEY (`id_sgroup`),
  UNIQUE KEY `sgroups_api_token_uindex` (`api_token`),
  UNIQUE KEY `sgroups_sgroup_name_uindex` (`sgroup_name`),
  UNIQUE KEY `sgroups_id_sgroup_uindex` (`id_sgroup`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='Специальные группы и их параметры';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `sgroups`
--

LOCK TABLES `sgroups` WRITE;
/*!40000 ALTER TABLE `sgroups` DISABLE KEYS */;
INSERT INTO `sgroups` VALUES (1,'TestGroup','','','',3);
/*!40000 ALTER TABLE `sgroups` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `user_rights`
--

DROP TABLE IF EXISTS `user_rights`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `user_rights` (
  `id_user` int NOT NULL COMMENT 'Идентификатор пользователя',
  `id_right` int NOT NULL COMMENT 'Идентификатор типа доступа',
  `can_read` tinyint NOT NULL DEFAULT '1' COMMENT 'Чтение',
  `can_write` tinyint NOT NULL DEFAULT '0' COMMENT 'Запись (управление)',
  PRIMARY KEY (`id_user`,`id_right`),
  KEY `user_rights_id_right_fk` (`id_right`),
  CONSTRAINT `user_rights_id_right_fk` FOREIGN KEY (`id_right`) REFERENCES `access_right_types` (`id_right`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `user_rights_id_user_fk` FOREIGN KEY (`id_user`) REFERENCES `users` (`id_user`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='Права пользователей';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `user_rights`
--

LOCK TABLES `user_rights` WRITE;
/*!40000 ALTER TABLE `user_rights` DISABLE KEYS */;
INSERT INTO `user_rights` VALUES (1,1,1,1);
/*!40000 ALTER TABLE `user_rights` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `users`
--

DROP TABLE IF EXISTS `users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `users` (
  `id_user` int NOT NULL AUTO_INCREMENT COMMENT 'Идентификатор пользователя',
  `login` varchar(32) NOT NULL COMMENT 'Имя пользователя',
  `password` varchar(64) NOT NULL DEFAULT '' COMMENT 'Пароль пользователя',
  `id_sgroup` int DEFAULT NULL COMMENT 'Идентификатор специальной группы, к которой принадлежит пользователь',
  `description` varchar(250) DEFAULT NULL COMMENT 'Описание пользователя',
  PRIMARY KEY (`id_user`),
  UNIQUE KEY `users_login_uindex` (`login`),
  KEY `users_sgroups_id_sgroup_fk` (`id_sgroup`),
  CONSTRAINT `users_sgroups_id_sgroup_fk` FOREIGN KEY (`id_sgroup`) REFERENCES `sgroups` (`id_sgroup`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='Зарегистрированные пользователи';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `users`
--

LOCK TABLES `users` WRITE;
/*!40000 ALTER TABLE `users` DISABLE KEYS */;
INSERT INTO `users` VALUES (1,'test','123123',1,NULL);
/*!40000 ALTER TABLE `users` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2022-06-24 10:02:55
