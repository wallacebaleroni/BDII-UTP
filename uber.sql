DROP TABLE IF EXISTS Passageiro CASCADE;
DROP TABLE IF EXISTS Categoria CASCADE;
DROP TABLE IF EXISTS Carro CASCADE;
DROP TABLE IF EXISTS Motorista CASCADE;
DROP TABLE IF EXISTS Corrida CASCADE;
DROP TABLE IF EXISTS Pedido CASCADE;


/* usuários que atuam como passageiros */
CREATE TABLE Passageiro (
	cpf CHAR(11) NOT NULL,
	nome VARCHAR NOT NULL,
	email VARCHAR NOT NULL,
	telefone INT NOT NULL,
	avaliacao INT DEFAULT 0, -- nota média do usuário
	endereco_casa VARCHAR,
	endereco_trabalho VARCHAR,
	
	CONSTRAINT PK_Passageiro PRIMARY KEY (cpf)
);

/* categorias de serviço (UberX, UberBlack...) */
CREATE TABLE Categoria (
	id INT NOT NULL,
	nome VARCHAR NOT NULL,
	
	CONSTRAINT PK_Categoria PRIMARY KEY (id)
);

/* carros cadastrados e sendo utilizados para prestar o serviço */
CREATE TABLE Carro (
	renavam INT NOT NULL,
	placa CHAR(7) NOT NULL, -- checar
	marca VARCHAR NOT NULL,
	modelo VARCHAR NOT NULL,
	ano INT NOT NULL, -- <= 2018
	categoria INT NOT NULL,
	
	CONSTRAINT PK_Carro PRIMARY KEY (renavam),
	CONSTRAINT FK_Categoria FOREIGN KEY (categoria) REFERENCES Categoria (id) -- relação: carro atende categoria
);

-- usuários que atuam como motoristas
CREATE TABLE Motorista (
	cpf CHAR(11) NOT NULL,
	nome VARCHAR NOT NULL,
	email VARCHAR NOT NULL,
	telefone INT NOT NULL,
	carro INT NOT NULL, -- cada motorista só pode ter um carro cadastrado no Uber
	avaliacao REAL DEFAULT 0, -- avaliação média do motorista, de 1 a 5
	
	CONSTRAINT PK_Motorista PRIMARY KEY (cpf),
	CONSTRAINT FK_Carro FOREIGN KEY (carro) REFERENCES Carro (renavam) -- relação: motorista possui carro
);

CREATE TABLE Pedido (
	passageiro CHAR(11) NOT NULL,
	time_aberto TIMESTAMP NOT NULL, -- hora em que o pedido foi feito
	time_fechado TIMESTAMP, -- hora em que o pedido foi fechado (atendido ou cancelado)
	status VARCHAR NOT NULL, -- "em aberto" (buscando motorista), "atendido" (virou uma corrida), "cancelado"
	end_origem VARCHAR NOT NULL, -- endereço de origem
	end_destino VARCHAR NOT NULL, -- endereço de destino
	categoria INT NOT NULL,
	
	CONSTRAINT PK_Pedido PRIMARY KEY (passageiro, time_aberto),
	
	-- relação entre passageiro e categoria
	CONSTRAINT FK_Passageiro FOREIGN KEY (passageiro) REFERENCES Passageiro (cpf),
	CONSTRAINT FK_categoria FOREIGN KEY (categoria) REFERENCES Categoria (id)
);
	

CREATE TABLE Corrida (
	passageiro CHAR(11) NOT NULL,
	motorista CHAR(11) NOT NULL,
	categoria INT NOT NULL,
	time_inicio TIMESTAMP NOT NULL, -- hora do início da corrida
	time_fim TIMESTAMP NOT NULL, -- hora do fim da corrida
	end_inicio VARCHAR NOT NULL, -- local onde a corrida começou
	end_fim VARCHAR NOT NULL, -- local onde a corrida terminou (sujeito a mudanças durante a corrida)
	avaliacao_motorista REAL, -- avaliação de 1 a 5 que o passageiro deu para o motorista
	avaliacao_passageiro REAL, -- avaliação de 1 a 5 que o motorista deu para o passageiro
	
	CONSTRAINT PK_Corrida PRIMARY KEY (passageiro, time_inicio),
	-- primary key também podia ser (motorista, time_inicio)
	
	-- relação ternária entre passageiro, motorista e categoria:
	CONSTRAINT FK_Passageiro FOREIGN KEY (passageiro) REFERENCES Passageiro (cpf),
	CONSTRAINT FK_Motorista FOREIGN KEY (motorista) REFERENCES Motorista (cpf),
	CONSTRAINT FK_Categoria FOREIGN KEY (categoria) REFERENCES Categoria (id)
);

/* auto-relacionamento que define a hierarquia das categorias */
CREATE TABLE Cobre (
	cat_superior INT NOT NULL,
	cat_inferior INT NOT NULL,
	
	CONSTRAINT PK_Cobre PRIMARY KEY (cat_superior, cat_inferior),
	CONSTRAINT FK_Cobre_1 FOREIGN KEY (cat_superior) REFERENCES Categoria (id),
	CONSTRAINT FK_Cobre_2 FOREIGN KEY (cat_inferior) REFERENCES Categoria (id)
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
