-- trigger for å øke eksemplarnummer på biblios automatisk
-- bruker coalesce for å defaulte til 1 hvis ingen eksemplarer fra før
-- legger også på strekkode inkrementert med 1
DROP TRIGGER IF EXISTS autoCopyNumberAndBarcode;
DELIMITER $$
CREATE TRIGGER autoCopyNumberAndBarcode BEFORE INSERT ON items
FOR EACH ROW
BEGIN
  SET NEW.copynumber = (SELECT COALESCE((MAX(CAST(copynumber AS SIGNED)) + 1), 1) FROM items WHERE biblionumber = NEW.biblionumber);
  SET NEW.barcode = (SELECT COALESCE(MAX(CAST(barcode AS UNSIGNED)) + 1, 1) FROM items);
END;
$$
DELIMITER ;
