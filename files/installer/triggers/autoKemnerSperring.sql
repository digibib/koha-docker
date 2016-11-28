DROP TRIGGER IF EXISTS autoKemnerSperring;
delimiter //
CREATE TRIGGER autoKemnerSperring BEFORE UPDATE ON items
FOR EACH ROW
BEGIN
  IF NEW.itemlost = 12 AND (OLD.itemlost != 12 OR OLD.itemlost IS NULL) THEN
    INSERT INTO borrower_debarments (borrowernumber, type, comment, manager_id)
    (SELECT borrowernumber, 'MANUAL', 'Sendt til kemner',49393 FROM issues
     WHERE issues.itemnumber=NEW.itemnumber AND NOT EXISTS (
      SELECT * FROM borrower_debarments
      WHERE borrowernumber=borrowernumber AND comment='Sendt til kemner'));
  END IF;
END;//
delimiter ;
