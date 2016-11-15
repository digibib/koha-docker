-- hentenummer --

CREATE TABLE IF NOT EXISTS `pickup_counter` (
  `counter` int(6) NOT NULL auto_increment,
  PRIMARY KEY  (`counter`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 AUTO_INCREMENT=0 ;


/* procedure to add columns safely if already existing */
DROP PROCEDURE IF EXISTS AddCol;
DELIMITER //
CREATE PROCEDURE AddCol(
  IN param_table_name VARCHAR(100),
  IN param_column VARCHAR(100),
  IN param_column_details VARCHAR(100)
)
BEGIN
  IF NOT EXISTS(
    SELECT NULL FROM information_schema.COLUMNS
    WHERE COLUMN_NAME=param_column AND TABLE_NAME=param_table_name
  )
  THEN
    SET @ddl = CONCAT('ALTER TABLE ', param_table_name, ' ADD COLUMN ', param_column, ' ', param_column_details);
    /* Prepare and execute the statement that was built */
    PREPARE stmt FROM @ddl;
    EXECUTE stmt ;
    /* Cleanup the prepared statement */
    DEALLOCATE PREPARE stmt ;
  END IF;
END //
DELIMITER ;


-- legg til hentenummer på reserves --
CALL AddCol('reserves', 'pickupnumber', 'VARCHAR(10)');
DROP PROCEDURE AddCol;

-- trigger ved plukking --
--   hvis en reservering endrer status til 'W' (Waiting), inkrementer tabell pickupnumber
--   og legg til hentenummer i kolonnen 'pickupnumber' på den aktuelle reservasjonen 
DROP TRIGGER IF EXISTS autoPickupNumber;
DELIMITER //
CREATE TRIGGER autoPickupNumber BEFORE UPDATE ON reserves
FOR EACH ROW
BEGIN
  IF NEW.found = 'W' AND OLD.found != 'W' THEN
    -- We have picked a new reserve --
    INSERT INTO pickup_counter (counter) VALUES (NULL);
    SET NEW.pickupnumber = CONCAT(DAYOFMONTH(NOW()), '/', (SELECT LAST_INSERT_ID() FROM pickup_counter));
  END IF;
END //
DELIMITER ;