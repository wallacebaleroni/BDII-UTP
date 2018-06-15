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
	avaliacao REAL DEFAULT 0, -- avaliação média do passageiro, de 0 a 5
    total_corridas INT DEFAULT 0, -- total de corridas que o usuário já concluiu
	endereco_casa VARCHAR,
	endereco_trabalho VARCHAR,
	
	CONSTRAINT PK_Passageiro PRIMARY KEY (cpf)
);

/* categorias de serviço (UberX, UberBlack...) */
CREATE TABLE Categoria (
	id INT NOT NULL,
	nome VARCHAR NOT NULL,
	cobre INT,
	
	CONSTRAINT PK_Categoria PRIMARY KEY (id),
	CONSTRAINT FK_Categoria FOREIGN KEY (cobre) REFERENCES Categoria (id) -- auto relacionamento de hierarquia
);

/* carros cadastrados e sendo utilizados para prestar o serviço */
CREATE TABLE Carro (
	renavam INT NOT NULL,
	placa CHAR(7) NOT NULL, -- checar
	marca VARCHAR NOT NULL,
	modelo VARCHAR NOT NULL,
	ano INT NOT NULL,
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
	avaliacao REAL DEFAULT 0, -- avaliação média do motorista, de 0 a 5
    total_corridas INT DEFAULT 0, -- total de corridas que o motorista já concluiu
	
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
	time_fim TIMESTAMP, -- hora do fim da corrida (NULL se estiver em andamento)
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


/* TRIGGERS DE VALIDAÇÃO DE DADOS */

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


/*
VERIFICAR NOTAS DADAS PARA O MOTORISTA E O PASSAGEIRO
*/
CREATE OR REPLACE FUNCTION verif_avaliacoes() RETURNS trigger AS $$
BEGIN
    IF (NEW.avaliacao_motorista IS NOT NULL) THEN
        IF ((NEW.avaliacao_motorista < 0) OR (NEW.avaliacao_motorista > 5)) THEN
            RAISE EXCEPTION 'Avaliação deve estar entre 0 e 5.';
        END IF;
    END IF;
    
    IF (NEW.avaliacao_passageiro IS NOT NULL) THEN
        IF ((NEW.avaliacao_passageiro < 0) OR (NEW.avaliacao_passageiro > 5)) THEN
            RAISE EXCEPTION 'Avaliação deve estar entre 0 e 5.';
        END IF;
    END IF;
	
	RETURN NEW;
	
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER verif_avaliacoes
BEFORE INSERT ON Corrida
FOR EACH ROW EXECUTE PROCEDURE verif_avaliacoes();


/*
CORRIDAS SOBREPOSTAS
Impedir que corridas com o mesmo passageiro ou o mesmo motorista sejam inseridas em horários sobrepostos
*/

CREATE OR REPLACE FUNCTION corridas_sobrepostas() RETURNS trigger AS $$
DECLARE
	count_motorista INTEGER;
	count_passageiro INTEGER;

BEGIN
	SELECT COUNT(*)
    INTO count_motorista
	FROM Corrida
	WHERE motorista = NEW.motorista
    AND (time_fim IS NULL
     OR NEW.time_inicio BETWEEN time_inicio AND time_fim);
	
    SELECT COUNT(*)
    INTO count_passageiro
	FROM Corrida
	WHERE passageiro = NEW.passageiro
    AND (time_fim IS NULL
	OR NEW.time_inicio BETWEEN time_inicio AND time_fim);
	
    
	IF (count_motorista <> 0) THEN
		RAISE EXCEPTION 'Um motorista não pode fazer corridas sobrepostas.';
	END IF;
	
	IF (count_passageiro <> 0) THEN
		RAISE EXCEPTION 'Um passageiro não pode fazer corridas sobrepostas.';
	END IF;
	
	RETURN NEW;
	
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER corridas_sobrepostas
BEFORE INSERT ON Corrida
FOR EACH ROW EXECUTE PROCEDURE corridas_sobrepostas();


/*
ATUALIZAR NOTAS MÉDIAS DO MOTORISTA E DO PASSAGEIRO APÓS A CONCLUSÃO DE UMA CORRIDA
*/

CREATE OR REPLACE FUNCTION atualizar_medias() RETURNS trigger AS $$
DECLARE
    total_corridas_motorista INTEGER;
    media_antiga_motorista REAL;
	nova_media_motorista REAL;
    
    total_corridas_passageiro INTEGER;
    media_antiga_passageiro REAL;
    nova_media_passageiro REAL;
    
BEGIN
    IF (NEW.avaliacao_motorista IS NOT NULL) THEN
        SELECT total_corridas INTO total_corridas_motorista FROM Motorista WHERE cpf = NEW.motorista;
        SELECT avaliacao INTO media_antiga_motorista FROM Motorista WHERE cpf = NEW.motorista;

        nova_media_motorista := ((total_corridas_motorista * media_antiga_motorista) + NEW.avaliacao_motorista) / (total_corridas_motorista + 1);
        
        UPDATE Motorista
        SET avaliacao = nova_media_motorista, total_corridas = total_corridas + 1
        WHERE CPF = NEW.motorista;

    END IF;

    
    IF (NEW.avaliacao_passageiro IS NOT NULL) THEN
        SELECT total_corridas INTO total_corridas_passageiro FROM Passageiro WHERE cpf = NEW.passageiro;
        SELECT avaliacao INTO media_antiga_passageiro FROM Passageiro WHERE cpf = NEW.passageiro;

        nova_media_passageiro := ((total_corridas_passageiro * media_antiga_passageiro) + NEW.avaliacao_passageiro) / (total_corridas_passageiro + 1);

        UPDATE Passageiro
        SET avaliacao = nova_media_passageiro, total_corridas = total_corridas + 1
        WHERE CPF = NEW.passageiro;

    END IF;
	
	RETURN NEW;
	
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER atualizar_medias
AFTER INSERT OR UPDATE ON Corrida
FOR EACH ROW EXECUTE PROCEDURE atualizar_medias();


/* TESTES */
-- atualizar!

INSERT INTO Passageiro VALUES('12345678910', 'Joao', 'joao@email.com', 26696969);
INSERT INTO Passageiro VALUES('98765432100', 'Maria', 'maria@email.com', 26696969);
INSERT INTO Passageiro VALUES('69696969696', 'Rogerinho', 'djrpdfdtpe1395271@hotmail123.com', 964865952);

INSERT INTO Categoria VALUES(1, 'UberX', NULL);
INSERT INTO Categoria VALUES(2, 'UberSelect', 1);
INSERT INTO Categoria VALUES(3, 'UberBlack', 2);

INSERT INTO Carro VALUES(1234, 'CAM2010', 'Chevrolet', 'Camaro', 2010, 2);
INSERT INTO Carro VALUES(5678, 'PSC2018', 'Porsche', '718', 2018, 3);
INSERT INTO Carro VALUES(9101, 'LOL1996', 'Fusca', '96', 2018, 1);

INSERT INTO Motorista VALUES('10293847560', 'Jorge', 'jorge@bol.com', 12443857, 1234);
INSERT INTO Motorista VALUES('12133454324', 'Marcos', 'marcos@uol.com', 84782478, 5678);
INSERT INTO Motorista VALUES('64578854645', 'Roger', 'roger@aol.com', 17654378, 9101);

INSERT INTO Corrida VALUES('12345678910', '10293847560', 1, '2018-06-14 16:00:00', '2018-06-14 17:00:00', 'Niterói', 'Rio', 5, 5);
-- INSERT INTO Corrida VALUES('98765432100', '10293847560', 1, '2018-06-14 16:30:00', '2018-06-14 16:50:00', 'Niterói', 'Rio', 5, 5); -- sobreposta!
INSERT INTO Corrida VALUES('69696969696', '10293847560', 1, '2018-06-14 18:00:00', '2018-06-14 19:00:00', 'Niterói', 'Rio', 4, 5);
INSERT INTO Corrida VALUES('69696969696', '10293847560', 1, '2018-06-14 20:00:00', '2018-06-14 21:00:00', 'Niterói', 'Rio', 4, 4);

SELECT * FROM Passageiro;
SELECT * FROM Categoria;
SELECT * FROM Carro;
SELECT * FROM Motorista;
SELECT * FROM Corrida;
