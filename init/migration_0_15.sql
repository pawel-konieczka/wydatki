update `oc_data` set `UserID` = 1 where `UserID` = 0;
delete from `oc_users` where `ID` = 0;

update `oc_config` set `Value` = '0.15' where `Param` = 'version';
