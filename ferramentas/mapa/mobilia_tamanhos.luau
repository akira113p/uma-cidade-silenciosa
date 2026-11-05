-- Contrato da mobília: nome → pegada {w (X), h (Y), d (Z)} em studs, frente = −Z local, origem = centro da pegada no
-- piso (para peças de parede/teto veja `fixo`). `var = true`: aceita op.w / op.d / op.h para mudar o tamanho (os
-- números abaixo são o padrão). `dono` diz qual módulo implementa (mobilia_casa ou mobilia_comercial).
-- Escala: ~3 studs por metro. Porta 4,5×7,5; pé-direito 12.
-- `fixo = "parede"`: a origem fica na face da parede, centro da largura, na altura `y` do piso (a peça sai para −Z).
-- `fixo = "teto"`: a origem fica no teto (Y local = pé-direito), a peça pendura para baixo.

local function t(w, h, d, dono, extra)
	local r = { w = w, h = h, d = d, dono = dono }
	if extra then
		for k, v in extra do
			r[k] = v
		end
	end
	return r
end
local V = { var = true }
local PAREDE = { fixo = "parede" }
local TETO = { fixo = "teto" }
local PV = { fixo = "parede", var = true }

local c, m = "casa", "comercial"

return {
	-- ---------------------------------------------------------------- mobilia_casa (doméstica) -------------------
	-- quarto
	cama_casal = t(5.5, 2.4, 7, c),
	cama_solteiro = t(3.2, 2.4, 6.5, c),
	beliche = t(3.2, 6.2, 6.5, c),
	berco = t(3, 3.2, 5, c),
	criado_mudo = t(1.8, 1.9, 1.6, c),
	guarda_roupa = t(5, 7.5, 2, c),
	comoda = t(4.5, 3.2, 1.8, c),
	penteadeira = t(4, 5.5, 1.8, c),
	-- sala
	sofa = t(6.5, 2.9, 2.8, c),
	sofa_pequeno = t(4.5, 2.9, 2.8, c),
	poltrona = t(2.8, 3, 2.8, c),
	mesa_centro = t(3.6, 1.4, 2, c),
	estante_livros = t(4.5, 7, 1.2, c, V),
	movel_tv = t(4.2, 3.6, 1.8, c),
	lareira = t(6, 7, 2.2, c),
	aparador = t(5, 3, 1.4, c),
	relogio_pe = t(1.8, 7, 1.4, c),
	piano = t(5, 4, 2.2, c),
	-- cozinha / jantar
	mesa_jantar = t(6, 2.7, 3.5, c, V),
	cadeira = t(1.8, 3.4, 1.8, c),
	geladeira = t(2.8, 6.2, 2.8, c),
	fogao = t(2.6, 3, 2.4, c),
	pia_cozinha = t(5, 3, 2.2, c),
	bancada_cozinha = t(5, 3, 2.2, c, V),
	armario_cozinha_alto = t(5, 2.6, 1.2, c, PV), -- na parede, y = 5,5 do piso
	mesa_cozinha = t(3.6, 2.7, 3.6, c),
	microondas = t(1.8, 1.2, 1.4, c),
	-- banheiro / serviço
	banheira = t(6, 2.2, 2.8, c),
	vaso_sanitario = t(1.6, 2.2, 2.4, c),
	lavatorio = t(2.4, 3.2, 1.8, c), -- pia de pedestal
	espelho_banheiro = t(2.6, 3, 0.3, c, PV),
	box_chuveiro = t(3, 7.5, 3, c),
	maquina_lavar = t(2.4, 2.9, 2.4, c),
	cesto_roupa = t(1.6, 2.4, 1.6, c),
	-- escritório doméstico
	escrivaninha = t(5, 2.7, 2.5, c),
	cadeira_escritorio = t(2, 3.8, 2, c),
	arquivo = t(2, 4.4, 2.4, c),
	-- decoração
	tapete = t(6, 0.1, 4, c, V),
	quadro = t(3, 2.4, 0.3, c, PV), -- w,h variáveis; y = 6,5 do piso
	espelho_parede = t(2.4, 4, 0.3, c, PV),
	luminaria_chao = t(1.2, 5.2, 1.2, c),
	luminaria_mesa = t(1, 1.6, 1, c),
	planta_vaso = t(1.6, 3.4, 1.6, c),
	cesto_lixo = t(1.2, 1.7, 1.2, c),
	caixa_papelao = t(2.2, 2, 2.2, c),
	bau = t(3, 2, 1.8, c),
	cabideiro = t(1.4, 5.5, 1.4, c),
	sapateira = t(3, 2.4, 1.2, c),
	relogio_parede = t(1.6, 1.6, 0.3, c, PAREDE), -- y = 8 do piso
	prateleira_parede = t(4, 0.3, 1, c, PV), -- y = 6 do piso
	cortina = t(4, 7, 0.4, c, PV), -- w variável; fica junto da janela
	ventilador_teto = t(5, 1.2, 5, c, TETO),
	lustre = t(3, 2, 3, c, TETO),
	-- garagem / oficina doméstica
	bancada_ferramentas = t(6, 3.2, 2.4, c),
	prateleira_garagem = t(5, 6.5, 1.6, c),
	bicicleta = t(1, 3.2, 5.4, c),
	pilha_pneus = t(2.6, 3.4, 2.6, c),
	caixa_ferramentas = t(1.6, 1.2, 0.8, c),
	galao = t(1, 1.6, 0.8, c),

	-- ------------------------------------------------ mobilia_comercial (comércio, serviço, industrial, culto) ------
	-- mercado
	prateleira_mercado = t(8, 6, 2.2, m, V),
	geladeira_expositora = t(6, 6.5, 2.8, m),
	freezer_horizontal = t(6, 2.8, 3, m),
	balcao_caixa = t(7, 3.2, 3, m), -- com caixa registradora e esteira
	carrinho_compras = t(2, 3.2, 3.4, m),
	cesta_compras = t(1.6, 1.2, 1.2, m),
	pilha_produtos = t(3, 3, 3, m), -- pilha de caixas/latas à venda
	balcao_acougue = t(8, 3.4, 3, m, V),
	-- lojas
	balcao_loja = t(7, 3.4, 2.4, m, V),
	vitrine = t(5, 3.4, 2, m, V),
	arara_roupas = t(5, 5.6, 1.6, m),
	manequim = t(1.6, 6, 1.6, m),
	prateleira_loja = t(6, 7, 1.6, m, V),
	-- restaurante / bar
	mesa_restaurante = t(4, 2.7, 4, m), -- com 2–4 cadeiras
	cabine_restaurante = t(7, 3.6, 3.2, m), -- booth: dois bancos e mesa
	balcao_bar = t(10, 3.6, 2.2, m, V),
	banqueta = t(1.5, 2.8, 1.5, m),
	maquina_venda = t(3, 6.5, 2.6, m),
	jukebox = t(3, 5.4, 2, m),
	mesa_sinuca = t(9, 2.8, 5, m),
	-- posto / oficina
	bomba_combustivel = t(2.4, 6.5, 1.8, m),
	tambor_oleo = t(1.8, 2.8, 1.8, m),
	expositor_pneus = t(4, 6, 2, m),
	elevador_oficina = t(10, 7, 5, m),
	compressor = t(2.6, 3.2, 1.8, m),
	-- escritório / recepção
	baia_escritorio = t(6.5, 5, 6, m), -- cubículo com mesa, divisórias e computador
	mesa_escritorio = t(6, 2.7, 3, m),
	mesa_reuniao = t(12, 2.7, 5, m, V),
	balcao_recepcao = t(10, 3.6, 2.6, m, V),
	sofa_recepcao = t(6.5, 2.9, 2.8, m),
	arquivo_alto = t(2.6, 6.2, 2.4, m),
	copiadora = t(3, 3.4, 2.4, m),
	bebedouro = t(1.6, 4.2, 1.6, m),
	quadro_branco = t(6, 4, 0.3, m, PV), -- y = 4,5 do piso
	computador = t(2.2, 2.2, 2, m), -- desktop CRT em cima de mesa (pegada pequena)
	-- hospital / delegacia / escola
	maca_hospital = t(3, 3.2, 7, m),
	cama_hospital = t(3.4, 3.4, 7.2, m),
	armario_medico = t(3.4, 6, 1.6, m),
	cortina_hospital = t(7, 6.5, 0.4, m, V),
	mesa_cirurgia = t(3.2, 3.2, 7, m),
	cadeira_rodas = t(2.4, 3.4, 3, m),
	cela_grade = t(8, 8, 8, m), -- cela completa com grades, beliche e vaso
	mesa_delegacia = t(6, 2.7, 3, m),
	armario_armas = t(4, 6.5, 1.6, m),
	carteira_escolar = t(2.6, 2.8, 2, m),
	mesa_professor = t(5, 2.9, 2.6, m),
	lousa = t(10, 4.5, 0.4, m, PV), -- y = 4 do piso
	armario_escola = t(4, 6.5, 1.6, m),
	estante_biblioteca = t(6, 8, 1.8, m, V),
	-- igreja / culto
	banco_igreja = t(10, 3.4, 2.4, m, V),
	altar = t(7, 3.6, 3, m),
	pulpito = t(3, 4.6, 2.6, m),
	pia_batismal = t(2.6, 3.4, 2.6, m),
	candelabro = t(1.6, 5, 1.6, m),
	cruz_parede = t(3, 4.6, 0.4, m, PAREDE), -- y = 9 do piso
	orgao = t(7, 8.5, 3, m),
	confessionario = t(4.6, 7.5, 3, m),
	caixao = t(2.6, 2.2, 7, m),
	-- industrial / rural
	estante_industrial = t(8, 7, 2.4, m, V),
	palete = t(5, 0.9, 5, m),
	pilha_caixotes = t(5, 5, 5, m, V),
	barril = t(2, 3, 2, m),
	bancada_trabalho = t(8, 3.2, 3, m, V),
	maquina_industrial = t(6, 6, 4, m), -- op.variante = 1 | 2 | 3 (prensa, torno, serra)
	esteira = t(20, 2.6, 3.2, m, V),
	tanque = t(6, 9, 6, m, V),
	quadro_eletrico = t(2.6, 5, 0.9, m, PAREDE), -- y = 3 do piso
	empilhadeira = t(4, 6.6, 8, m),
	caldeira = t(6, 10, 6, m),
	tubulacao = t(10, 1, 1, m, V),
	fardo_feno = t(4, 3, 2.6, m),
	-- acampamento
	barraca = t(9, 5.6, 10, m),
	cama_campanha = t(3, 2.2, 6.6, m),
	mesa_dobravel = t(5, 2.7, 2.6, m),
	fogueira = t(4, 1.8, 4, m),
	caixa_municao = t(2.4, 1.6, 1.4, m),
	estante_armas = t(5, 6, 1.4, m),
	mesa_mapas = t(6, 2.9, 4, m),
	gerador = t(3, 2.6, 2.2, m),
	lampiao = t(1, 2.2, 1, m),
	saco_areia = t(5, 2.2, 1.6, m, V), -- trecho de barricada de sacos
}
