DROP TRIGGER IF EXISTS autoKemnerSperring;
delimiter //
CREATE TRIGGER autoKemnerSperring BEFORE UPDATE ON items
FOR EACH ROW
BEGIN
  IF NEW.itemlost = 12 AND (OLD.itemlost != 12 OR OLD.itemlost IS NULL) THEN
    -- Add restriction comment: 'Sendt til kemner'
    INSERT INTO borrower_debarments (borrowernumber, type, comment, manager_id)
    (SELECT borrowernumber, 'MANUAL', 'Sendt til kemner',49393 FROM issues
     WHERE issues.itemnumber=NEW.itemnumber AND NOT EXISTS (
      SELECT * FROM borrower_debarments
      WHERE borrowernumber=borrowernumber AND comment='Sendt til kemner'));
    -- Add the actuall debarrment on borrower
    UPDATE borrowers JOIN issues USING (borrowernumber)
      SET debarred='2999-01-01'
    WHERE issues.itemnumber=NEW.itemnumber;
  END IF;
END;//
delimiter ;
