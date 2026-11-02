-- =====================================================================
-- Schema do banco do bot de agendamento da barbearia (PostgreSQL)
-- Execute este arquivo no seu banco ANTES de importar o workflow no n8n.
-- Os nomes de tabelas e colunas batem com as consultas do workflow.
--
-- ATENCAO (fuso horario): a consulta de horarios livres do workflow compara
-- timestamps e so exclui horarios ocupados corretamente se o fuso do seu banco
-- for America/Sao_Paulo. Descomente e ajuste o nome do banco abaixo:
-- ALTER DATABASE seu_banco SET timezone TO 'America/Sao_Paulo';
-- =====================================================================

-- ---------------------------------------------------------------------
-- servicos: catálogo de serviços e preços
-- Usada pela tool "ver_servicos" (só lista os que têm ativo = true).
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS servicos (
    id               SERIAL PRIMARY KEY,
    nome             TEXT          NOT NULL UNIQUE,
    descricao        TEXT,
    preco            NUMERIC(8, 2) NOT NULL CHECK (preco >= 0),
    duracao_minutos  INTEGER       NOT NULL CHECK (duracao_minutos > 0),
    ativo            BOOLEAN       NOT NULL DEFAULT TRUE
);

-- ---------------------------------------------------------------------
-- agendamentos: horários marcados pelos clientes
-- Usada pelas tools criar_agendamento, cancelar_agendamento,
-- ver_horarios_disponiveis e pelas consultas de confirmação.
-- data_hora é TIMESTAMPTZ: guarda o fuso (o bot grava em -03:00).
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS agendamentos (
    id            SERIAL PRIMARY KEY,
    telefone      TEXT        NOT NULL,
    nome_cliente  TEXT,
    servico       TEXT,
    data_hora     TIMESTAMPTZ NOT NULL,
    status        TEXT        NOT NULL DEFAULT 'confirmado'
                  CHECK (status IN ('confirmado', 'cancelado')),
    criado_em     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Índices nas colunas mais consultadas pelo workflow
CREATE INDEX IF NOT EXISTS idx_agendamentos_telefone_status
    ON agendamentos (telefone, status);
CREATE INDEX IF NOT EXISTS idx_agendamentos_data_hora
    ON agendamentos (data_hora);

-- Impede dois agendamentos CONFIRMADOS no mesmo horário exato
-- (cancelados não bloqueiam o horário).
CREATE UNIQUE INDEX IF NOT EXISTS uq_agendamentos_horario_confirmado
    ON agendamentos (data_hora)
    WHERE status = 'confirmado';

-- ---------------------------------------------------------------------
-- mensagens_buffer: agrupa mensagens que chegam em sequência
-- O workflow salva cada mensagem aqui, espera alguns segundos e junta
-- as não processadas do mesmo telefone antes de chamar o agente de IA.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS mensagens_buffer (
    id          SERIAL PRIMARY KEY,
    telefone    TEXT        NOT NULL,
    mensagem    TEXT        NOT NULL,
    processado  BOOLEAN     NOT NULL DEFAULT FALSE,
    criado_em   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_buffer_telefone_processado
    ON mensagens_buffer (telefone, processado, criado_em);

-- ---------------------------------------------------------------------
-- Memória de conversa do agente (tabela "n8n_chat_histories"):
-- criada automaticamente pelo n8n (node Postgres Chat Memory) na
-- primeira execução. Não precisa criar aqui.
-- ---------------------------------------------------------------------
