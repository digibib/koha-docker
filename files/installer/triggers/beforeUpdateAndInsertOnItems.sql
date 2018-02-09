-- xLog
CREATE TABLE IF NOT EXISTS `items_log` (
  `itemnumber` int,
  `at` TIMESTAMP,
  `field` varchar(32),
  `oldval` varchar(256),
  `newval` varchar(256),
  KEY (`itemnumber`),
  KEY `items_log_at` (`at`)
);


-- New items:
--   force copynumber and barcode to highest existing number+1
--   insert event in items_log
DELIMITER $$
DROP TRIGGER IF EXISTS `afterInsertOnItems`;
CREATE TRIGGER `afterInsertOnItems`
AFTER INSERT ON `items`
FOR EACH ROW
BEGIN
  INSERT INTO `items_log` (itemnumber, field, oldval, newval)
  VALUES (NEW.itemnumber, 'created', NULL, NEW.homebranch);
END;
$$

DROP TRIGGER IF EXISTS `beforeUpdateOnItems`;
CREATE TRIGGER `beforeUpdateOnItems`
BEFORE UPDATE ON `items`
FOR EACH ROW
BEGIN
  IF NEW.itemlost <> OLD.itemlost THEN
    INSERT INTO `items_log` (itemnumber, field, oldval, newval)
    VALUES (NEW.itemnumber, 'itemlost', OLD.itemlost, NEW.itemlost);
  END IF;
  IF NEW.notforloan <> OLD.notforloan THEN
    INSERT INTO `items_log` (itemnumber, field, oldval, newval)
    VALUES (NEW.itemnumber, 'notforloan', OLD.notforloan, NEW.notforloan);
  END IF;
  IF NEW.damaged <> OLD.damaged THEN
    INSERT INTO `items_log` (itemnumber, field, oldval, newval)
    VALUES (NEW.itemnumber, 'damaged', OLD.damaged, NEW.damaged);
  END IF;
  IF NEW.homebranch <> OLD.homebranch THEN
    INSERT INTO `items_log` (itemnumber, field, oldval, newval)
    VALUES (NEW.itemnumber, 'homebranch', OLD.homebranch, NEW.homebranch);
  END IF;
END;
$$
DELIMITER ;