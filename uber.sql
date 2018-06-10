DROP TABLE IF EXISTS Passageiro CASCADE;
DROP TABLE IF EXISTS Categoria CASCADE;
DROP TABLE IF EXISTS Carro CASCADE;
DROP TABLE IF EXISTS Motorista CASCADE;
DROP TABLE IF EXISTS Possui CASCADE;
DROP TABLE IF EXISTS Corrida CASCADE;

CREATE TABLE Passageiro (
	cpf CHAR(11) NOT NULL,
	nome VARCHAR NOT NULL,
	email VARCHAR NOT NULL,
	telefone INT NOT NULL,
	nota INT DEFAULT 0,
	endereco_casa VARCHAR,
	endereco_trabalho VARCHAR,
	
	CONSTRAINT PK_Passageiro PRIMARY KEY (cpf)
);

CREATE TABLE Categoria (
	id INT NOT NULL,
	nome VARCHAR NOT NULL,
	
	CONSTRAINT PK_Categoria PRIMARY KEY (id)
);

CREATE TABLE Carro (
	renavam INT NOT NULL,
	placa CHAR(7) NOT NULL, -- checar
	marca VARCHAR NOT NULL,
	modelo VARCHAR NOT NULL,
	ano INT NOT NULL, -- <= 2018
	categoria INT NOT NULL,
	
	CONSTRAINT PK_Carro PRIMARY KEY (renavam),
	CONSTRAINT FK_Categoria FOREIGN KEY (categoria) REFERENCES Categoria (id)
);

CREATE TABLE Motorista (
	cpf CHAR(11) NOT NULL,
	nome VARCHAR NOT NULL,
	email VARCHAR NOT NULL,
	telefone INT NOT NULL,
	carro INT NOT NULL,
	nota INT DEFAULT 0, -- calcular
	
	CONSTRAINT PK_Motorista PRIMARY KEY (cpf),
	CONSTRAINT FK_Carro FOREIGN KEY (carro) REFERENCES Carro (renavam)
);

CREATE TABLE Possui (
	motorista CHAR(11) NOT NULL,
	carro INT NOT NULL,
	
	CONSTRAINT PK_Possui PRIMARY KEY (motorista, carro),
	CONSTRAINT FK_Motorista FOREIGN KEY (motorista) REFERENCES Motorista (cpf),
	CONSTRAINT FK_Carro FOREIGN KEY (carro) REFERENCES Carro (renavam)
);

CREATE TABLE Corrida (
	passageiro CHAR(11) NOT NULL,
	motorista CHAR(11) NOT NULL,
	categoria INT NOT NULL,
	time_inicio TIMESTAMP NOT NULL,
	time_fim TIMESTAMP NOT NULL,
	end_origem VARCHAR NOT NULL,
	end_destino VARCHAR NOT NULL,
	avaliacao INT, -- NULL até o passageiro fazer sua avaliação da corrida
	
	CONSTRAINT PK_Corrida PRIMARY KEY (passageiro, time_inicio),
	CONSTRAINT FK_Passageiro FOREIGN KEY (passageiro) REFERENCES Passageiro (cpf),
	CONSTRAINT FK_Motorista FOREIGN KEY (motorista) REFERENCES Motorista (cpf),
	CONSTRAINT FK_Categoria FOREIGN KEY (categoria) REFERENCES Categoria (id)
);


/* triggers */

CREATE OR REPLACE FUNCTION verif_passageiro() RETURNS trigger AS $$
BEGIN
    IF NEW.cpf NOT SIMILAR TO '[0-9]*' THEN
        RAISE EXCEPTION 'O número de CPF inserido parece inválido.';
    END IF;
    
	IF position('@' in NEW.email) = 0 OR position('.' in NEW.email) = 0 THEN
		RAISE EXCEPTION 'O email inserido parece inválido.';
	END IF;

RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER verif_passageiro
BEFORE INSERT ON Passageiro
FOR EACH ROW EXECUTE PROCEDURE verif_passageiro();


CREATE OR REPLACE FUNCTION verif_motorista() RETURNS trigger AS $$
BEGIN
	IF NEW.cpf NOT SIMILAR TO '[0-9]*' THEN
        RAISE EXCEPTION 'O número de CPF inserido parece inválido.';
    END IF;
    
	IF position('@' in NEW.email) = 0 OR position('.' in NEW.email) = 0 THEN
		RAISE EXCEPTION 'O email inserido parece inválido.';
	END IF;

RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER verif_motorista
BEFORE INSERT ON Motorista
FOR EACH ROW EXECUTE PROCEDURE verif_motorista();

/*****/

INSERT INTO Passageiro VALUES('12345678910', 'Joao', 'joao@email.com', 26696969);
INSERT INTO Passageiro VALUES('98765432100', 'Maria', 'maria@email.com', 26696969);
INSERT INTO Passageiro VALUES('69696969696', 'Rogerinho', 'djrpdfdtpe1395271@hotmail123.com', 964865952);

INSERT INTO Categoria VALUES(1, 'UberX');
INSERT INTO Categoria VALUES(2, 'UberBlack');
INSERT INTO Categoria VALUES(3, 'Select');

INSERT INTO Carro VALUES(1234, 'CAM2010', 'Chevrolet', 'Camaro', 2010, 1);
INSERT INTO Carro VALUES(5678, 'PSC2018', 'Porsche', '718', 2018, 2);

INSERT INTO Motorista VALUES('10293847560', 'Jorge', 'jorge@bol.com', 12443857, 1234);
INSERT INTO Motorista VALUES('12133454324', 'Marcos', 'marcos@uol.com', 84782478, 5678);
INSERT INTO Motorista VALUES('64578854645', 'Roger', 'roger@aol.com', 17654378, 5678);

INSERT INTO Corrida VALUES('12345678910', '10293847560', 1, now(), now(), 'Aqui', 'Ali');
INSERT INTO Corrida VALUES('98765432100', '12133454324', 2, now(), now(), 'Ali', 'Aqui');

SELECT * FROM Passageiro;
SELECT * FROM Categoria;
SELECT * FROM Carro;
SELECT * FROM Motorista;
SELECT * FROM Corrida;
SELECT * FROM Possui;
