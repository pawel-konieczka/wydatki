-- MySQL dump 10.13  Distrib 5.6.35, for Linux (x86_64)

--
-- Temporary view structure for view `LISTA_KATEGORII`
--

DROP TABLE IF EXISTS `LISTA_KATEGORII`;
/*!50001 DROP VIEW IF EXISTS `LISTA_KATEGORII`*/;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
/*!50001 CREATE VIEW `LISTA_KATEGORII` AS SELECT 
 1 AS `ID`,
 1 AS `Name`,
 1 AS `LONG_NAME`,
 1 AS `Description`,
 1 AS `Position`*/;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `oc_categories`
--

DROP TABLE IF EXISTS `oc_categories`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `oc_categories` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `Name` varchar(64) COLLATE utf8_bin NOT NULL,
  `Description` varchar(255) COLLATE utf8_bin NOT NULL,
  `Position` int(11) NOT NULL,
  PRIMARY KEY (`ID`)
) ENGINE=MyISAM AUTO_INCREMENT=16 DEFAULT CHARSET=utf8 COLLATE=utf8_bin;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `oc_categories`
--

LOCK TABLES `oc_categories` WRITE;
/*!40000 ALTER TABLE `oc_categories` DISABLE KEYS */;
INSERT INTO `oc_categories` (`ID`, `Name`, `Description`, `Position`) VALUES (1,'żywność lub środki czystości','codzienne zakupy, kosmetyki',1),(2,'kościelne, ewangelizacja','ofiary, związane z kościołem',2),(3,'transport i komunikacja','samochód, paliwo, bilety, telefony',3),(4,'mieszkaniowe','za dom, media, serwis filtra, kredyt',4),(5,'rozrywka','kino, bale, puby',5),(6,'zdrowie','leki, wizyty, leczenie, zapobieganie',6),(7,'ubrania','',7),(8,'papiernicze','książki, koperty, kartki, koszulki, pisaki, znaczki',8),(9,'wypoczynek','urlopy, wycieczki, wakacje',9),(10,'wyposażenie','to, co kupujemy do domu (kuchenne, budowlane)',10),(11,'inne','prezenty, kwiaty, fryzjer',11),(12,'inne - większe','',12),(13,'inwestycje','fundusze, akcje, itp.',13),(14,'edukacja','',14),(15,'ubezpieczenia','',15);
/*!40000 ALTER TABLE `oc_categories` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `oc_config`
--

DROP TABLE IF EXISTS `oc_config`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `oc_config` (
  `Param` varchar(15) COLLATE utf8_bin NOT NULL,
  `Value` varchar(30) COLLATE utf8_bin NOT NULL,
  UNIQUE KEY `Param` (`Param`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_bin;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `oc_config`
--

LOCK TABLES `oc_config` WRITE;
/*!40000 ALTER TABLE `oc_config` DISABLE KEYS */;
INSERT INTO `oc_config` (`Param`, `Value`) VALUES ('version','0.14');
/*!40000 ALTER TABLE `oc_config` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `oc_data`
--

DROP TABLE IF EXISTS `oc_data`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `oc_data` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `Description` varchar(255) COLLATE utf8_bin NOT NULL,
  `Date` date NOT NULL,
  `CategoryID` int(11) NOT NULL,
  `Value` float NOT NULL,
  `UserID` int(11) NOT NULL,
  `Details` varchar(256) COLLATE utf8_bin DEFAULT NULL,
  `Discount` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`),
  KEY `FK_USERID` (`UserID`),
  KEY `FK_CATEGORYID` (`CategoryID`),
  KEY `IDX_DATA` (`Date`)
) ENGINE=MyISAM AUTO_INCREMENT=22196 DEFAULT CHARSET=utf8 COLLATE=utf8_bin;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `oc_data`
--

/*!40000 ALTER TABLE `oc_data` DISABLE KEYS */;
/*!40000 ALTER TABLE `oc_data` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `oc_users`
--

DROP TABLE IF EXISTS `oc_users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `oc_users` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `User` varchar(16) COLLATE utf8_bin NOT NULL,
  `Passwd` varchar(41) COLLATE utf8_bin NOT NULL,
  PRIMARY KEY (`ID`)
) ENGINE=MyISAM AUTO_INCREMENT=23 DEFAULT CHARSET=utf8 COLLATE=utf8_bin;

--
-- Dumping data for table `oc_users`
--

LOCK TABLES `oc_users` WRITE;
/*!40000 ALTER TABLE `oc_users` DISABLE KEYS */;
INSERT INTO `oc_users` (`ID`, `User`, `Passwd`) VALUES (1,'danka','*160D64036D7B875A2921FF9FA6FAE930F1596661'),(2,'pawel','*00DEC0846AB4EB9349FD1E3E2BC86C465F7EE98B'),(3,'tester','*696AB056EED0987ABDDF75925FFEFA6F36B88928'),(0,'undef','');
/*!40000 ALTER TABLE `oc_users` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping events for database 'urny54_wydatki'
--

--
-- Dumping routines for database 'urny54_wydatki'
--

--
-- Final view structure for view `LISTA_KATEGORII`
--

/*!50001 DROP VIEW IF EXISTS `LISTA_KATEGORII`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8 */;
/*!50001 SET character_set_results     = utf8 */;
/*!50001 SET collation_connection      = utf8_general_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`urny54`@`w05.int.webd` SQL SECURITY DEFINER */
/*!50001 VIEW `LISTA_KATEGORII` AS select `c`.`ID` AS `ID`,`c`.`Name` AS `Name`,concat((case when (`c`.`Position` < 10) then `c`.`Position` else char(((ascii('A') + `c`.`Position`) - 10)) end),'. ',`c`.`Name`) AS `LONG_NAME`,`c`.`Description` AS `Description`,`c`.`Position` AS `Position` from `oc_categories` `c` order by `c`.`Position` */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2018-01-14  5:28:04
