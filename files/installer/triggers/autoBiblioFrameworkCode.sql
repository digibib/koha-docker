-- trigger for å automatisk sette MARC rammeverk for nye poster
DROP TRIGGER IF EXISTS autoBiblioFrameworkCode;
CREATE TRIGGER autoBiblioFrameworkCode BEFORE UPDATE ON biblio
  FOR EACH ROW SET NEW.frameworkcode = 'DCHM'; 
