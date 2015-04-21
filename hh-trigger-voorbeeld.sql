-- ----------------------------------------------------- 
-- IVP4 Hartige Hap

-- -----------------------------------------------------

DROP SCHEMA IF EXISTS `hh-trigger-voorbeeld` ;
CREATE SCHEMA IF NOT EXISTS `hh-trigger-voorbeeld` DEFAULT CHARACTER SET latin1 ;
USE `hh-trigger-voorbeeld` ;

-- -----------------------------------------------------
-- Table `bestelling`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `bestelling` ;
CREATE TABLE IF NOT EXISTS `bestelling` (
	`ID` INT UNSIGNED NOT NULL AUTO_INCREMENT,
	`TafelNummer` TINYINT NOT NULL,
	`Status` ENUM(
		'OPEN',			-- open voor nieuwe bestellingen.
		'GEANNULEERD',	-- geen factuur, bestelregels kunnen niet meer worden gewijzigd
		'AFGEROND'		-- factuur, kunnen geen nieuwe bestelregels meer bij.
		) NOT NULL DEFAULT 'OPEN',
	`LaatstGewijzigdOp` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
	PRIMARY KEY (`ID`)
) 
COMMENT = ''
ENGINE = InnoDB;

-- --------------------------------------------------------
-- 1. Er mag geen nieuwe bestelling geopend worden op een tafel 
--    die al een OPEN of WILBETALEN bestelling heeft.
-- 2. Een bestelling mag alleen GEANNULEERD als deze OPEN is, 
--    en er geen bestelde, niet-GESERVEERDe bestelregels zijn. 
--    Nog doen.
-- 3. Een bestelling die GEANNULEERD is mag alleen terug naar OPEN.
--    Nog doen.
-- 4. Er mag alleen een factuur gemaakt worden wanneer status AFGEROND is.
--    Nog doen.
-- 5. De status van een nieuwe bestelling is altijd OPEN. 
--    Before insert: als Status != OPEN dan foutmelding en exit.
-- 6. Het moet onmogelijk zijn om de status van een oude bestelling
--    te wijzigen. Zodra er dus een nieuwere bestelling is, mag
--    er niet meer gewijzigd worden.
-- 
DELIMITER //

DROP TRIGGER IF EXISTS `insert_bestelling` //
CREATE TRIGGER `insert_bestelling`
BEFORE INSERT ON `bestelling`
FOR EACH ROW 
BEGIN 
	DECLARE msg varchar(255);
	
	-- Er mag niet al een open bestelling op dezelfde tafel zijn.
	IF EXISTS(	
		SELECT * 
		FROM `bestelling` 
		WHERE `TafelNummer` = NEW.`TafelNummer` 
		AND (`Status` = 'OPEN' OR `Status` = 'WILBETALEN')) 
	THEN 
		SET msg = CONCAT('Er loopt reeds een bestelling op tafel ', NEW.`TafelNummer`,'.'); 
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg; 
	END IF; 	
	
	-- De nieuwe bestelling moet status OPEN hebben.
	IF NEW.`Status` != 'OPEN' THEN 
		SET msg = CONCAT('Nieuwe bestelling moet status OPEN hebben.'); 
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg; 
	END IF;
END //

-- --------------------------------------------------------
-- Status overgangen: Initieel = OPEN
-- Van			> Naar
-- OPEN 		> WILBETALEN, GEANNULEERD, AFGEROND
-- WILBETALEN 	> OPEN, AFGEROND
-- GEANNULEERD	> geen toestandsovergang toegestaan, geen factuur aanwezig, geen bestelregels.
-- AGEROND		> geen toestandsovergang toegestaan, wel factuur aanwezig, wel bestelregels.
-- 
-- Daarnaast: Status kan alleen naar AFGEROND als ALLE bijbehorende bestelregels GESERVEERD of GEANNULEERD zijn.

DROP TRIGGER IF EXISTS `update_bestelling` //
CREATE TRIGGER `update_bestelling`
BEFORE UPDATE ON `bestelling`
FOR EACH ROW 
BEGIN 
	DECLARE msg varchar(255);

	-- AFGERONDe bestellingen mogen niet meer gewijzigd worden.
	IF (OLD.`Status` = 'AFGEROND' OR OLD.`Status` = 'GEANNULEERD') THEN 
		SET msg = CONCAT('Bestelling ', NEW.`ID`, ' is reeds afgerond, geen wijzigingen toegestaan.'); 
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg; 
	END IF;	

	-- Check alle mogelijke statusovergangen.
	CASE NEW.`Status`
	WHEN 'OPEN' THEN 
		-- Een wijziging naar OPEN is nooit toegestaan. Een bestelling komt in OPEN
		-- bij het aanmaken, en de tijd van de bestelling wordt dan vastgelegd.
		-- Een update naar OPEN zou dus nooit voor mogen komen.
		BEGIN
		-- ToDo
		END;	
	WHEN 'GEANNULEERD' THEN 
		BEGIN
			-- Annuleren kan alleen als er geen GESERVEERDe of GEREEDe bestelregels zijn.
			-- Alle bestelregels moeten dus GEANNULEERD of INGEDIEND (en nog niet GEREED) zijn.
			IF (EXISTS(	
					SELECT `BestelregelID`, `BestellingID` 
					FROM `bestelregel` 
					WHERE (`BestellingID` = NEW.`ID`) 
						AND ((`Status` != 'GEANNULEERD') 
						AND  (`Status` != 'INGEDIEND'))
				))
			THEN 
				SET msg = CONCAT('Er zijn gerechten of dranken gereed of geserveerd, u kunt bestelling', NEW.`ID`, ' niet annuleren.'); 
				SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg; 
			END IF;
		END;	
	WHEN 'AFGEROND' THEN 
		BEGIN
			-- Er mogen geen openstaande gerecht- of drankbestellingen zijn op deze tafel.
			-- ToDO			
		END;	
	ELSE
		SET msg = 'Onbekende fout bij update van bestelling.';
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg; 
	END CASE;
END
//

DELIMITER ;

-- -----------------------------------------------------
-- Table `bestelregel`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `bestelregel`;
CREATE TABLE IF NOT EXISTS `bestelregel` (
	`BestelregelID` INT UNSIGNED NOT NULL AUTO_INCREMENT,
	`BestellingID` INT UNSIGNED NOT NULL COMMENT 'Referentie naar bestellingID van tafel.',	
	`Barcode` VARCHAR(8) NOT NULL COMMENT 'Referentie naar bestelde gerecht OF drank.',	
	`LaatstGewijzigdOp` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
	`Status` ENUM(
		'INGEDIEND',	-- Bestelregel voor drank of gerecht is aangemaakt
		'GEANNULEERD',	-- Bestelregel geannuleerd.
		'GEREED',		-- Gerecht of drank is gemaakt door keuken of bar, klaar voor serveren.
		'GESERVEERD'	-- Gerecht of drank is op tafel geserveerd.
		) NOT NULL DEFAULT 'INGEDIEND',
	PRIMARY KEY (`BestelregelID`)
) 
COMMENT = 'Een besteld gerecht of drank behorende bij een tafel. Zodra de keuken of bar het item op GEREED zet wordt de hoeveelheid van alle ingredienten van de voorraad afgehaald. Als er geen voorraad meer is kan het item niet besteld worden.'
ENGINE = InnoDB;

ALTER TABLE `bestelregel` 
Add CONSTRAINT `fk_bestelling_bestelregel`
FOREIGN KEY (`BestellingID`)
REFERENCES `bestelling` (`ID`)
ON DELETE CASCADE
ON UPDATE CASCADE;

-- -----------------------------------------------------
-- Maak een user aan, die we kunnen gebruiken voor de connectie in bv. Java.
-- -----------------------------------------------------
DROP USER 'hartigehap'@'localhost';
CREATE USER 'hartigehap'@'localhost' IDENTIFIED BY 'wachtwoord';
-- Rechten toekennen aan deze gebruiker
GRANT SELECT, INSERT, UPDATE ON `bestelling`  TO 'hartigehap'@'localhost';
GRANT SELECT, INSERT, UPDATE ON `bestelregel` TO 'hartigehap'@'localhost';

-- -----------------------------------------------------
-- TESTS 
-- --------------------------------------------------------

-- --------------------------------------------------------
-- Testen of je van een bestelling zonder bestelregels de status op AFGEROND kunt zetten.
INSERT INTO `bestelling` (`TafelNummer`) VALUES (1);
-- Het ID van de laatst toegevoegde bestelling
-- voor het toevoegen van een bestelregel hebbe we de ID van de bestelling nodig.
SET @v_id = LAST_INSERT_ID();
SELECT * FROM bestelling;

-- Voeg bestelregel toe aan bestelling 1, en test hiervan de statusovergangen.
-- Juiste volgordes: INGEDIEND > GEANNULEERD, of INGEDIEND > GEREED > GESERVEERD.
-- Andere overgangen zouden niet mogelijk moeten zijn.
-- Initiële status: INGEDIEND
INSERT INTO `bestelregel` (`BestellingID`, `Barcode`) VALUES (@v_id, '10000002');
SELECT * FROM bestelregel;

-- Er mag niet nog een bestelling op tafel 1 geopend worden.
INSERT INTO `bestelling` (`TafelNummer`) VALUES ( 1 );
SELECT * FROM bestelling;

-- Een nieuwe bestelling mag geen andere status dan OPEN hebben - geeft foutmelding.
INSERT INTO `bestelling` (`TafelNummer`, `Status`) VALUES ( 2, 'GEANNULEERD' );
SELECT * FROM bestelling;

-- De status veranderen naar OPEN mag in ons geval niet - geeft foutmelding
UPDATE `bestelregel` SET `Status` = 'OPEN' WHERE `Barcode` = '10000002';
SELECT * FROM bestelregel;

-- bestelregel INGEDIEND > GEREED mag wel
UPDATE `bestelregel` SET `Status` = 'GEREED' WHERE `Barcode` = '10000002';
SELECT * FROM bestelregel;

-- De status veranderen naar GEANNULEERD mag niet, de bestelling is al gereed - geeft foutmelding
UPDATE `bestelregel` SET `Status` = 'GEANNULEERD' WHERE `Barcode` = '10000002';
SELECT * FROM bestelregel;

-- bestelregen INGEDIEND > GEREED mag wel
UPDATE `bestelregel` SET `Status` = 'GESERVEERD' WHERE `Barcode` = '10000002';
SELECT * FROM bestelregel;

-- Zet bestelling op AFGEROND - mag wel nu wel, omdat alle bestellingen zijn geserveerd.
UPDATE `bestelling` SET `Status` = 'AFGEROND' WHERE `TafelNummer` = 1;
SELECT * FROM bestelling;

-- --------------------------------------------------------
