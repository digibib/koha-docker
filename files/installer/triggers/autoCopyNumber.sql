-- trigger for å øke eksemplarnummer på biblios automatisk
-- bruker coalesce for å defaulte til 1 hvis ingen eksemplarer fra før
DROP TRIGGER IF EXISTS autoCopyNumber;
DELIMITER $$;
CREATE TRIGGER autoCopyNumber BEFORE INSERT ON items
FOR EACH ROW
BEGIN
  SET NEW.copynumber = (SELECT COALESCE((MAX(CAST(copynumber AS SIGNED)) + 1), 1) FROM items WHERE biblionumber = NEW.biblionumber); 
END $$;
DELIMITER ;
