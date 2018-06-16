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

/* usuários que atuam como motoristas */
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

/* pedidos de corridas (até o momento em que se tornam corridas) */
CREATE TABLE Pedido (
	id INT NOT NULL,
	passageiro CHAR(11) NOT NULL,
	categoria INT NOT NULL,
	end_origem VARCHAR NOT NULL, -- endereço de origem
	end_destino VARCHAR NOT NULL, -- endereço de destino
	time_aberto TIMESTAMP NOT NULL, -- hora em que o pedido foi iniciado
	time_selecionado TIMESTAMP, -- hora em que um motorista foi selecionado para atender ao pedido
	time_fechado TIMESTAMP, -- hora em que o pedido foi fechado (atendido ou cancelado)
	status VARCHAR DEFAULT 'aberto', -- "aberto" (buscando motorista) / "esperando motorista" / "atendido" (virou uma corrida) / "cancelado pelo motorista" / "cancelado pelo passageiro"
    custo DECIMAL(10, 2) DEFAULT 0, -- preço do pedido (apenas se houver multa por cancelamento)
	
	CONSTRAINT PK_Pedido PRIMARY KEY (passageiro, time_aberto),
	
	-- relação entre passageiro e categoria
	CONSTRAINT FK_Passageiro FOREIGN KEY (passageiro) REFERENCES Passageiro (cpf),
	CONSTRAINT FK_categoria FOREIGN KEY (categoria) REFERENCES Categoria (id)
);

/* corridas */
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
    custo DECIMAL(15, 2), -- preço a ser pago pelo passageiro
	
	CONSTRAINT PK_Corrida PRIMARY KEY (passageiro, time_inicio),
	-- primary key também podia ser (motorista, time_inicio)
	
	-- relação ternária entre passageiro, motorista e categoria:
	CONSTRAINT FK_Passageiro FOREIGN KEY (passageiro) REFERENCES Passageiro (cpf),
	CONSTRAINT FK_Motorista FOREIGN KEY (motorista) REFERENCES Motorista (cpf),
	CONSTRAINT FK_Categoria FOREIGN KEY (categoria) REFERENCES Categoria (id)
);


/*
TRIGGERS DE VALIDAÇÃO DE DADOS
*/

/* Verificar informações do passageiro */
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


/* Verificar informações do motorista */
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



/* Verificar notas dadas para o motorista e o passageiro em uma corrida */
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


/* Atualizar informações de um pedido conforme mudanças de status */

CREATE OR REPLACE FUNCTION atualizar_pedido() RETURNS trigger AS $$
BEGIN

	-- atualizar timestamp quando um motorista é selecionado
	IF OLD.status = 'aberto' AND NEW.status = 'esperando motorista' THEN
		IF (NEW.time_selecionado IS NULL) THEN
			NEW.time_selecionado := now();
		END IF;
	END IF;

	-- atualizar timestamp quando o passageiro cancela o pedido e não havia motorista selecionado
	IF (OLD.status = 'aberto' AND NEW.status = 'cancelado pelo passageiro') THEN
		NEW.time_fechado := now();
    END IF;

	-- atualizar timestamp e possível taxa de cancelamento quando o passageiro cancela o pedido
	-- que já tinha motorista selecionado
	IF (OLD.status = 'esperando motorista' AND NEW.status = 'cancelado pelo passageiro') THEN
		NEW.time_fechado := now();

		IF (NEW.time_fechado - NEW.time_selecionado > INTERVAL '5 min') THEN
			NEW.custo := NEW.custo + 7;
		END IF;
	END IF;

	-- atualizar timestamp e status quando o motorista cancela o pedido
	IF (OLD.status = 'esperando motorista' AND NEW.status = 'cancelado pelo motorista') THEN
		NEW.time_selecionado := NULL;
		NEW.status := 'aberto';
	END IF;

	-- atualizar timestamp quando o motorista chega e a corrida se inicia
	IF (OLD.status = 'esperando motorista' AND NEW.status = 'atendido') THEN
		NEW.time_fechado := now();
	END IF;


	RETURN NEW;

END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER atualizar_pedido
BEFORE UPDATE ON Pedido
FOR EACH ROW EXECUTE PROCEDURE atualizar_pedido();


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
NOTAS MÉDIAS
Atualizar notas médias do motorista e do passageiro após a conclusão de uma corrida
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


CREATE OR REPLACE FUNCTION check_categoria() RETURNS trigger AS $$
DECLARE
	categoria_corrida INT;
	categoria_motorista INT;
BEGIN
	categoria_corrida = NEW.categoria;
	SELECT categoria 
	INTO categoria_motorista 
	FROM motorista INNER JOIN carro ON motorista.carro = carro.renavam
	WHERE motorista.cpf = NEW.motorista;
	
	WHILE categoria_corrida <> categoria_motorista LOOP
		SELECT cobre 
		INTO categoria_motorista
		FROM categoria
		WHERE categoria.id = categoria_motorista;
		
		IF categoria_motorista IS NULL THEN
			RAISE EXCEPTION 'Motorista de categoria inferior a da corrida';
		END IF;
	END LOOP;
	
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_categoria
BEFORE INSERT OR UPDATE ON Corrida
FOR EACH ROW EXECUTE PROCEDURE check_categoria();

DROP FUNCTION IF EXISTS get_areas_problematicas();
CREATE OR REPLACE FUNCTION get_areas_problematicas() 
RETURNS TABLE(
	area VARCHAR,
	quantidade_cancelamentos INT
) AS $$
DECLARE
	areas_canceladas CURSOR FOR 
		SELECT end_destino 
		FROM Pedido 
		WHERE status = 'cancelado pelo motorista' OR status = 'cancelado pelo passageiro' 
		GROUP BY end_destino;
	conta INT;
BEGIN
	FOR area IN areas_canceladas LOOP
		SELECT COUNT(id) 
		INTO conta 
		FROM Pedido 
		WHERE end_destino = area.end_destino;
		
		RETURN QUERY SELECT area.end_destino, conta;		
	END LOOP;
END;
$$ LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS areas_problematicas();
CREATE OR REPLACE FUNCTION areas_problematicas() RETURNS void AS $$
DECLARE
	areas CURSOR FOR SELECT * FROM get_areas_problematicas() ORDER BY quantidade_cancelamentos DESC;
	i INT;
BEGIN
	i = 1;
	RAISE NOTICE 'Áreas com maior quantidade de cancelamentos:';
	FOR area IN areas LOOP
		IF area.quantidade_cancelamentos = 1 THEN
			RAISE NOTICE '%ª. % com % cancelamento', i, area.area, area.quantidade_cancelamentos;
		ELSE 
			RAISE NOTICE '%ª. % com % cancelamentos', i, area.area, area.quantidade_cancelamentos;
		END IF;
		i = i + 1;
	END LOOP;
END;
$$ language plpgsql;

/* TESTES */

INSERT INTO Passageiro VALUES('12345678910', 'Joao', 'joao@email.com', 26696969);
INSERT INTO Passageiro VALUES('98765432100', 'Maria', 'maria@email.com', 26696969);
INSERT INTO Passageiro VALUES('69696969696', 'Rogerinho', 'djrpdfdtpe1395271@hotmail123.com', 964865952);

INSERT INTO Categoria VALUES(1, 'UberX', NULL);
INSERT INTO Categoria VALUES(2, 'UberBlack', 1);
INSERT INTO Categoria VALUES(3, 'UberVIP', 2);
INSERT INTO Categoria VALUES(4, 'UberSelect', NULL);

INSERT INTO Carro VALUES(1234, 'CAM2010', 'Chevrolet', 'Camaro', 2010, 2);
INSERT INTO Carro VALUES(5678, 'PSC2018', 'Porsche', '718', 2018, 3);
INSERT INTO Carro VALUES(9101, 'LOL1996', 'Fusca', '96', 2018, 1);

INSERT INTO Motorista VALUES('10293847560', 'Jorge', 'jorge@bol.com', 12443857, 1234);
INSERT INTO Motorista VALUES('12133454324', 'Marcos', 'marcos@uol.com', 84782478, 5678);
INSERT INTO Motorista VALUES('64578854645', 'Roger', 'roger@aol.com', 17654378, 9101);

INSERT INTO Corrida VALUES('12345678910', '10293847560', 2, '2018-06-14 16:00:00', '2018-06-14 17:00:00', 'Niterói', 'Rio', 5, 5);
-- INSERT INTO Corrida VALUES('98765432100', '10293847560', 2, '2018-06-14 16:30:00', '2018-06-14 16:50:00', 'Niterói', 'Rio', 5, 5); -- sobreposta!
INSERT INTO Corrida VALUES('69696969696', '10293847560', 2, '2018-06-14 18:00:00', '2018-06-14 19:00:00', 'Niterói', 'Rio', 4, 5);
-- INSERT INTO Corrida VALUES('69696969696', '10293847560', 3, '2018-06-14 20:00:00', '2018-06-14 21:00:00', 'Niterói', 'Rio', 4, 4); -- categoria errada!

INSERT INTO Pedido VALUES(1, '12345678910', 3, 'Icarai', 'Ipanema', '2018-06-16 20:00:00', NULL, NULL);
INSERT INTO Pedido VALUES(2, '12345678910', 3, 'Botafogo', 'Flamengo', '2018-06-16 20:00:01', NULL, NULL);
INSERT INTO Pedido VALUES(3, '12345678910', 3, 'Botafogo', 'Ipanema', '2018-06-16 20:00:02', NULL, NULL);
INSERT INTO Pedido VALUES(4, '12345678910', 3, 'Flamengo', 'Icarai', '2018-06-16 20:00:03', NULL, NULL);
INSERT INTO Pedido VALUES(5, '12345678910', 3, 'Flamengo', 'Botafogo', '2018-06-16 20:00:04', NULL, NULL);

UPDATE Pedido SET status = 'cancelado pelo motorista', time_selecionado = '2018-06-16 20:05:00' WHERE id = 1;
UPDATE Pedido SET status = 'atendido', time_selecionado = '2018-06-16 20:05:00' WHERE id = 2;
UPDATE Pedido SET status = 'cancelado pelo passageiro', time_selecionado = '2018-06-16 20:05:00' WHERE id = 3;
UPDATE Pedido SET status = 'atendido', time_selecionado = '2018-06-16 20:05:00' WHERE id = 4;
UPDATE Pedido SET status = 'cancelado pelo passageiro', time_selecionado = '2018-06-16 20:05:00' WHERE id = 5;
-- UPDATE Pedido SET status = 'cancelado pelo passageiro' WHERE passageiro = '12345678910';
-- UPDATE Pedido SET status = 'cancelado pelo motorista' WHERE passageiro = '12345678910';
-- UPDATE Pedido SET status = 'atendido' WHERE passageiro = '12345678910';

SELECT * FROM Passageiro;
SELECT * FROM Categoria;
SELECT * FROM Carro;
SELECT * FROM Motorista;
SELECT * FROM Corrida;
SELECT * FROM Pedido;

SELECT * FROM areas_problematicas();