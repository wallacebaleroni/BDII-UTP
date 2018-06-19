DROP TABLE IF EXISTS Passageiro CASCADE;
DROP TABLE IF EXISTS Categoria CASCADE;
DROP TABLE IF EXISTS Carro CASCADE;
DROP TABLE IF EXISTS Motorista CASCADE;
DROP TABLE IF EXISTS Corrida CASCADE;
DROP TABLE IF EXISTS Pedido CASCADE;


/* Usuários que atuam como passageiros */
CREATE TABLE Passageiro (
	cpf CHAR(11) NOT NULL,
	nome VARCHAR NOT NULL,
	email VARCHAR NOT NULL,
	telefone INT NOT NULL,
	avaliacao REAL DEFAULT 0, -- Avaliação média do passageiro, de 0 a 5
    total_corridas INT DEFAULT 0, -- Total de corridas que o usuário já concluiu
	endereco_casa VARCHAR,
	endereco_trabalho VARCHAR,
	
	CONSTRAINT PK_Passageiro PRIMARY KEY (cpf)
);

/* Categorias de serviço (UberX, UberBlack...) */
CREATE TABLE Categoria (
	id INT NOT NULL,
	titulo VARCHAR NOT NULL,
	cobre INT,
	
	CONSTRAINT PK_Categoria PRIMARY KEY (id),
	CONSTRAINT FK_Categoria FOREIGN KEY (cobre) REFERENCES Categoria (id) -- Auto-relacionamento de hierarquia
);

/* Carros cadastrados e sendo utilizados para prestar o serviço */
CREATE TABLE Carro (
	renavam INT NOT NULL,
	placa CHAR(7) NOT NULL,
	marca VARCHAR NOT NULL,
	modelo VARCHAR NOT NULL,
	ano INT NOT NULL,
	categoria INT NOT NULL,
	
	CONSTRAINT PK_Carro PRIMARY KEY (renavam),
	CONSTRAINT FK_Categoria FOREIGN KEY (categoria) REFERENCES Categoria (id) -- Relação: carro atende categoria
);

/* Usuários que atuam como motoristas */
CREATE TABLE Motorista (
	cpf CHAR(11) NOT NULL,
	nome VARCHAR NOT NULL,
	email VARCHAR NOT NULL,
	telefone INT NOT NULL,
	carro INT NOT NULL,
	avaliacao REAL DEFAULT 0, -- Avaliação média do motorista, de 0 a 5
    total_corridas INT DEFAULT 0, -- Total de corridas que o motorista já concluiu
	
	CONSTRAINT PK_Motorista PRIMARY KEY (cpf),
	CONSTRAINT FK_Carro FOREIGN KEY (carro) REFERENCES Carro (renavam) -- Relação: motorista possui carro
);

/* Pedidos de corridas (até o momento em que se tornam corridas) */
CREATE TABLE Pedido (
	id INT NOT NULL,
	passageiro CHAR(11) NOT NULL,
	categoria INT NOT NULL,
	end_origem VARCHAR NOT NULL, -- Endereço de origem
	end_destino VARCHAR NOT NULL, -- Endereço de destino
	time_aberto TIMESTAMP NOT NULL, -- Hora em que o pedido foi iniciado
	time_selecionado TIMESTAMP, -- Hora em que um motorista foi selecionado para atender ao pedido
	time_fechado TIMESTAMP, -- Hora em que o pedido foi fechado (atendido ou cancelado)
	status VARCHAR DEFAULT 'aberto', -- "aberto" (buscando motorista) / "esperando motorista" / "atendido" (virou uma corrida) / "cancelado pelo motorista" / "cancelado pelo passageiro"
    custo DECIMAL(10, 2) DEFAULT 0, -- Preço do pedido (apenas se houver multa por cancelamento)
	
	CONSTRAINT PK_Pedido PRIMARY KEY (id),
	
	-- Relações com passageiro e categoria
	CONSTRAINT FK_Passageiro FOREIGN KEY (passageiro) REFERENCES Passageiro (cpf),
	CONSTRAINT FK_Categoria FOREIGN KEY (categoria) REFERENCES Categoria (id)
);

/* Corridas */
CREATE TABLE Corrida (
	id INT NOT NULL,
	pedido INT NOT NULL,
	motorista CHAR(11) NOT NULL,
	time_inicio TIMESTAMP NOT NULL, -- Hora do início da corrida
	time_fim TIMESTAMP, -- Hora do fim da corrida (NULL se estiver em andamento)
	end_inicio VARCHAR NOT NULL, -- Local onde a corrida começou
	end_fim VARCHAR NOT NULL, -- Local onde a corrida terminou (sujeito a mudanças durante a corrida)
	avaliacao_motorista REAL, -- Avaliação de 1 a 5 que o passageiro deu para o motorista
	avaliacao_passageiro REAL, -- Avaliação de 1 a 5 que o motorista deu para o passageiro
    custo DECIMAL(15, 2), -- Preço a ser pago pelo passageiro
	
	CONSTRAINT PK_Corrida PRIMARY KEY (id),
	
	-- Relações com pedido e motorista
	CONSTRAINT FK_Pedido FOREIGN KEY (pedido) REFERENCES Pedido (id),
	CONSTRAINT FK_Motorista FOREIGN KEY (motorista) REFERENCES Motorista (cpf)
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



/* TRIGGER 1: Verificar notas dadas para o motorista e o passageiro em uma corrida */
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


/* TRIGGER 2: Atualizar informações de um pedido conforme mudanças de status */
CREATE OR REPLACE FUNCTION atualizar_pedido() RETURNS trigger AS $$
BEGIN

	-- Atualizar timestamp quando um motorista é selecionado
	IF OLD.status = 'aberto' AND NEW.status = 'esperando motorista' THEN
		IF (NEW.time_selecionado IS NULL) THEN
			NEW.time_selecionado := now();
		END IF;
	END IF;

	-- Atualizar timestamp quando o passageiro cancela o pedido e não havia motorista selecionado
	IF (OLD.status = 'aberto' AND NEW.status = 'cancelado pelo passageiro') THEN
		NEW.time_fechado := now();
    END IF;

	-- Atualizar timestamp e possível taxa de cancelamento quando o passageiro cancela o pedido
	-- que já tinha motorista selecionado
	IF (OLD.status = 'esperando motorista' AND NEW.status = 'cancelado pelo passageiro') THEN
		NEW.time_fechado := now();

		IF (NEW.time_fechado - NEW.time_selecionado > INTERVAL '5 min') THEN
			NEW.custo := NEW.custo + 7;
		END IF;
	END IF;

	-- Atualizar timestamp e status quando o motorista cancela o pedido
	IF (OLD.status = 'esperando motorista' AND NEW.status = 'cancelado pelo motorista') THEN
		NEW.time_selecionado := NULL;
		NEW.status := 'aberto';
	END IF;

	-- Atualizar timestamp quando o motorista chega e a corrida se inicia
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
TRIGGER 3.1: CORRIDAS SOBREPOSTAS
Impedir que corridas com o mesmo motorista sejam inseridas em horários sobrepostos.
*/
CREATE OR REPLACE FUNCTION corridas_sobrepostas() RETURNS trigger AS $$
DECLARE
	count_motorista INTEGER;

BEGIN
	SELECT COUNT(*)
    INTO count_motorista
	FROM Corrida
	WHERE motorista = NEW.motorista
    AND (time_fim IS NULL
     OR NEW.time_inicio BETWEEN time_inicio AND time_fim);
    
	IF (count_motorista <> 0) THEN
		RAISE EXCEPTION 'Um motorista não pode fazer corridas sobrepostas.';
	END IF;
	
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER corridas_sobrepostas
BEFORE INSERT ON Corrida
FOR EACH ROW EXECUTE PROCEDURE corridas_sobrepostas();

/*
TRIGGER 3.2: PEDIDOS SOBREPOSTOS
Impedir que pedidos sejam feitos pelo mesmo passageiro em horários sobrepostos.
*/
CREATE OR REPLACE FUNCTION pedidos_sobrepostos() RETURNS trigger AS $$
DECLARE
	count_passageiro INTEGER;
BEGIN
	SELECT COUNT(*)
   	INTO count_passageiro
	FROM Pedido
	WHERE passageiro = NEW.passageiro
    	AND (time_fechado IS NULL
     	OR NEW.time_aberto BETWEEN time_aberto AND time_fechado);
	
	IF (count_passageiro <> 0) THEN
		RAISE EXCEPTION 'Um passageiro não pode fazer pedidos sobrepostos.';
	END IF;
	
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER pedidos_sobrepostos
BEFORE INSERT ON Pedido
FOR EACH ROW EXECUTE PROCEDURE pedidos_sobrepostos();


/*
TRIGGER 4: NOTAS MÉDIAS
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
	
	cpf_passageiro VARCHAR;    
BEGIN
    IF (NEW.avaliacao_motorista IS NOT NULL) THEN
        SELECT total_corridas 
		INTO total_corridas_motorista 
		FROM Motorista 
		WHERE cpf = NEW.motorista;
        
		SELECT avaliacao 
		INTO media_antiga_motorista 
		FROM Motorista 
		WHERE cpf = NEW.motorista;

        nova_media_motorista := ((total_corridas_motorista * media_antiga_motorista) + NEW.avaliacao_motorista) / (total_corridas_motorista + 1);
        
        UPDATE Motorista
        SET avaliacao = nova_media_motorista, total_corridas = total_corridas + 1
        WHERE CPF = NEW.motorista;
    END IF;

    
    IF (NEW.avaliacao_passageiro IS NOT NULL) THEN
		SELECT passageiro
		INTO cpf_passageiro
		FROM Pedido
		WHERE NEW.pedido = id;
		
        SELECT total_corridas 
		INTO total_corridas_passageiro 
		FROM Passageiro 
		WHERE cpf = cpf_passageiro;
		
        SELECT avaliacao 
		INTO media_antiga_passageiro 
		FROM Passageiro 
		WHERE cpf = cpf_passageiro;

        nova_media_passageiro := ((total_corridas_passageiro * media_antiga_passageiro) + NEW.avaliacao_passageiro) / (total_corridas_passageiro + 1);

        UPDATE Passageiro
        SET avaliacao = nova_media_passageiro, total_corridas = total_corridas + 1
        WHERE CPF = cpf_passageiro;
    END IF;
	
	RETURN NEW;
	
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER atualizar_medias
AFTER INSERT OR UPDATE ON Corrida
FOR EACH ROW EXECUTE PROCEDURE atualizar_medias();


/*
TRIGGER 5: HIERARQUIA DAS CATEGORIAS
Checa se categoria do carro do motorista envolvido na corrida 
é de hieraquia igual ou superior a da indicada na corrida
*/
CREATE OR REPLACE FUNCTION check_categoria() RETURNS trigger AS $$
DECLARE
	categoria_corrida INT;
	categoria_motorista INT;
	id_pedido INT;
BEGIN
	IF OLD <> NULL THEN
		IF OLD.motorista = NEW.motorista THEN
			RETURN NEW;
		END IF;
	END IF;
	
	id_pedido = NEW.pedido;
	SELECT categoria 
	INTO categoria_corrida
	FROM pedido
	WHERE pedido.id = id_pedido;

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
			RAISE EXCEPTION 'Motorista de categoria inferior à da corrida';
		END IF;
	END LOOP;
	
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_categoria
BEFORE INSERT OR UPDATE ON Corrida
FOR EACH ROW EXECUTE PROCEDURE check_categoria();

/*
TRIGGER 6: UBER SELECT
Um motorista com avaliação média menor que 4.5 não pode fazer corridas da categoria "UberSelect",
pois essa categoria é exclusiva para motoristas com notas altas.
*/
CREATE OR REPLACE FUNCTION uber_select() RETURNS trigger AS $$
DECLARE
	avaliacao_motorista REAL;
	id_categoria INT;
	id_pedido INT;
	categoria_pedido INT;
BEGIN
	id_pedido = NEW.pedido;
	SELECT categoria
	INTO categoria_pedido
	FROM Pedido
	WHERE id = id_pedido;

	SELECT id
	INTO id_categoria
	FROM Categoria 
	WHERE id = categoria_pedido;
	
	IF id_categoria = 4 THEN
		SELECT avaliacao 
		INTO avaliacao_motorista 
		FROM Motorista 
		WHERE cpf = NEW.motorista;

		IF (avaliacao_motorista < 4.5) THEN
			RAISE EXCEPTION 'Motorista tem avaliação menor que 4.5 e não pode fazer corridas UberSelect.';
		END IF;
	END IF;

	RETURN NEW;
    
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER uber_select
BEFORE INSERT OR UPDATE ON Corrida
FOR EACH ROW EXECUTE PROCEDURE uber_select();



/*
Função auxiliar ao PROCEDURE 1
*/
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

/*
PROCEDURE 1: RANKING DE ÁREAS COM MAIS CANCELAMENTOS
Função imprime as áreas com mais cancelamentos
*/
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


/*
PROCEDURE 2: ALGUMAS ESTATÍSTICAS
Função que imprime algumas estatísticas sobre as corridas, como
Número de corridas em certos intervalos de tempo e
Média de nota dos motoristas por categoria
*/
DROP FUNCTION IF EXISTS estatisticas();
CREATE OR REPLACE FUNCTION estatisticas() RETURNS void AS $$
DECLARE
	qntd INT;
	media_nota CURSOR FOR 
		SELECT titulo, AVG(avaliacao) as nota
		FROM (motorista INNER JOIN carro ON motorista.carro = carro.renavam) INNER JOIN categoria on carro.categoria = categoria.id
		GROUP BY titulo;
BEGIN
	RAISE NOTICE 'Números de corridas por período:';

	SELECT COUNT(*) INTO qntd FROM Corrida WHERE time_inicio > now() - interval '1 day';
	RAISE NOTICE 'Número de corridas no último dia: %', qntd;
	
	SELECT COUNT(*) INTO qntd FROM Corrida WHERE time_inicio > now() - interval '1 month';
	RAISE NOTICE 'Número de corridas no último mes: %', qntd;
	
	SELECT COUNT(*) INTO qntd FROM Corrida WHERE time_inicio > now() - interval '1 year';
	RAISE NOTICE 'Número de corridas no último ano: %', qntd;
	
	RAISE NOTICE 'Média de nota dos motorista por categoria:';
	FOR categoria IN media_nota LOOP
		RAISE NOTICE 'Média de nota no %: %', categoria.titulo, categoria.nota;
	END LOOP;
	
END;
$$ language plpgsql;



/* Inserção de linhas nas tabelas */
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
INSERT INTO Carro VALUES(9102, 'FER2018', 'Ferrari', '488', 2018, 3);

INSERT INTO Motorista VALUES('10293847560', 'Jorge', 'jorge@bol.com', 12443857, 1234, 5);
INSERT INTO Motorista VALUES('12133454324', 'Marcos', 'marcos@uol.com', 84782478, 5678, 3);
INSERT INTO Motorista VALUES('64578854645', 'Roger', 'roger@aol.com', 17654378, 9101, 3);
INSERT INTO Motorista VALUES('68578220448', 'Fabio', 'fabio@dol.com', 42345618, 9102, 5);


INSERT INTO Pedido VALUES(1, '12345678910', 2, 'Niterói', 'Rio', '2018-06-20 07:00:00', NULL, NULL);
-- INSERT INTO Pedido VALUES(1, '12345678910', 2, 'Niterói', 'Rio', '2018-06-20 07:05:00', NULL, NULL); -- Exceção: pedido sobreposto!
UPDATE Pedido SET status = 'esperando motorista', time_selecionado = '2018-06-20 07:05:00' WHERE id = 1;
UPDATE Pedido SET status = 'cancelado pelo motorista' WHERE id = 1;
UPDATE Pedido SET status = 'esperando motorista', time_selecionado = '2018-06-20 07:10:00' WHERE id = 1;
UPDATE Pedido SET status = 'atendido' WHERE id = 1;

INSERT INTO Pedido VALUES(4, '98765432100', 3, 'Niterói', 'Rio', '2018-06-14 19:50:00', NULL, NULL);

INSERT INTO Corrida VALUES(1, 1, '10293847560', '2018-06-14 16:00:00', '2018-06-14 17:00:00', 'Niterói', 'Rio', 5, 5);
INSERT INTO Corrida VALUES(2, 1, '10293847560', '2018-06-14 18:00:00', '2018-06-14 19:00:00', 'Niterói', 'Rio', 4, 5);
-- INSERT INTO Corrida VALUES(3, 3, '10293847560', '2018-06-14 16:30:00', '2018-06-14 16:50:00', 'Niterói', 'Rio', 5, 5); -- Exceção: Corridas sobrepostas!
-- INSERT INTO Corrida VALUES(4, 4, '10293847560', '2018-06-14 20:00:00', '2018-06-14 21:00:00', 'Niterói', 'Rio', 4, 4); -- Exceção: Categoria errada!


SELECT * FROM Passageiro;
SELECT * FROM Categoria;
SELECT * FROM Carro;
SELECT * FROM Motorista;
SELECT * FROM Corrida;
SELECT * FROM Pedido;

SELECT areas_problematicas();
SELECT estatisticas();
