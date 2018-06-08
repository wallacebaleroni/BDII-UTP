DROP TABLE IF EXISTS Passageiro CASCADE;
CREATE TABLE Passageiro (
	cpf CHAR(11) NOT NULL, -- checar
	nome VARCHAR NOT NULL,
	email VARCHAR NOT NULL, -- checar
	telefone INT NOT NULL, -- checar
	nota INT DEFAULT 0, -- calcular
	endereco_casa VARCHAR,
	endereco_trabalho VARCHAR,
	
	CONSTRAINT PK_Passageiro PRIMARY KEY (cpf)
);

DROP TABLE IF EXISTS Motorista CASCADE;
CREATE TABLE Motorista (
	cpf VARCHAR NOT NULL, -- checar
	nome VARCHAR NOT NULL,
	email VARCHAR NOT NULL, -- checar
	telefone INT NOT NULL, -- checar
	carro INT NOT NULL, -- checar
	nota INT DEFAULT 0, -- calcular
	
	CONSTRAINT PK_Motorista PRIMARY KEY (cpf),
	CONSTRAINT FK_Carro FOREIGN KEY (carro) REFERENCES Carro (renavam)
);

DROP TABLE IF EXISTS Carro CASCADE;
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

DROP TABLE IF EXISTS Categoria CASCADE;
CREATE TABLE Categoria (
	id INT NOT NULL,
	nome VARCHAR NOT NULL,
	
	CONSTRAINT PK_Categoria PRIMARY KEY (id)
);

DROP TABLE IF EXISTS Corrida CASCADE;
CREATE TABLE Corrida (
	passageiro VARCHAR NOT NULL,
	motorista VARCHAR NOT NULL,
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

-- atualizar com campos que faltam
INSERT INTO Passageiro VALUES('123.456.789-10', 'Joao', 'joao@email.com', 26696969);
INSERT INTO Passageiro VALUES('987.654.321-00', 'Maria', 'maria@email.com', 26696969);
INSERT INTO Passageiro VALUES('696.969.696.96', 'Rogerinho', 'djrpdfdtpe1395271@hotmail123.com', 964865952);

INSERT INTO Categoria VALUES(1, 'UberX');
INSERT INTO Categoria VALUES(2, 'UberBlack');
INSERT INTO Categoria VALUES(3, 'Select');

INSERT INTO Carro VALUES(1234, 'CAM2010', 'Chevrolet', 'Camaro', 2010, 1);
INSERT INTO Carro VALUES(5678, 'PSC2018', 'Porsche', '718', 2018, 2);

INSERT INTO Motorista VALUES('10293847560', 'Jorge', 'jorge@bol.com', 12443857, 1234);
INSERT INTO Motorista VALUES('12133454324', 'Marcos', 'marcos@uol.com', 84782478, 5678);
INSERT INTO Motorista VALUES('64578854645', 'Roger', 'roger@aol.com', 17654378, 5678);

INSERT INTO Corrida VALUES('12345678910', '102.938.475-60', 1, now(), now(), 'Aqui', 'Ali');
INSERT INTO Corrida VALUES('98765432100', '121.334.543-24', 2, now(), now(), 'Ali', 'Aqui');

SELECT * FROM Passageiro;
SELECT * FROM Categoria;
SELECT * FROM Carro;
SELECT * FROM Motorista;
SELECT * FROM Corrida;
