-- Armas do PvP (docs/armas.md, docs/calculos.md §6). Regras puras: src/shared/Regras/Armas.luau. TUDO PROVISÓRIO até o playtest.
-- Vida do corpo (Config/Corpo): cabeça 30 (x2 de arma), torso 60, braço 35, perna 40. "T" = tiros no torso para matar.
-- tipo "corpo": raycast curto, resolve `atrasoImpacto` s depois do pedido. tipo "fogo": raycast longo (ou projétil) com espalhamento.
-- classe = classe de animação (docs/armas.md §9). ruidoDb vai direto para Ruido.emitir (não passa por Config/Som.acoes).
-- som* = nome lógico em Config/Sons. tipoDano = linha de Config/Materiais.matriz (dano à construção).
-- dano de arma de fogo é POR PROJÉTIL (escopeta: dano de 1 chumbinho).

return {
	toleranciaAlcance = 2, -- studs a mais aceitos na validação do servidor
	toleranciaOrigem = 6, -- distância máxima entre a origem enviada e a cabeça do atacante

	-- multiplicador do espalhamento por estado do atirador (servidor decide o estado)
	multEstado = { parado = 1, andando = 1.25, correndo = 1.9, agachado = 0.7 },

	-- Quem escuta o disparo visual (evento Disparo): jogadores a até esta distância, menos o atirador.
	alcanceVisual = 700,

	armas = {
		----------------------------------------------------------------------------------------------- corpo a corpo
		faca = {
			nome = "Faca",
			classe = "faca",
			tipo = "corpo",
			dano = 18, -- T3
			cadencia = 0.5,
			alcance = 5,
			atrasoImpacto = 0.12,
			ruidoDb = 40,
			duasMaos = false,
			som = "Faca",
			somAcerto = "AcertoCarne",
			tipoDano = "corte",
		},
		peDeCabra = {
			nome = "Pé de cabra",
			classe = "contundente",
			tipo = "corpo",
			dano = 28, -- T3
			cadencia = 0.9,
			alcance = 6,
			atrasoImpacto = 0.25,
			ruidoDb = 55,
			duasMaos = false,
			som = "Balanco",
			somAcerto = "AcertoMetal",
			tipoDano = "alavanca",
		},
		machado = {
			nome = "Machado",
			classe = "machado",
			tipo = "corpo",
			dano = 40, -- T2
			cadencia = 1.3,
			alcance = 6,
			atrasoImpacto = 0.35,
			ruidoDb = 55,
			duasMaos = true,
			som = "BalancoPesado",
			somAcerto = "AcertoCarne",
			tipoDano = "corte",
		},

		----------------------------------------------------------------------------------------------- pistolas
		pistola = { -- genérica 9mm (referência: Glock 17), robusta e comum
			nome = "Pistola",
			classe = "pistola",
			tipo = "fogo",
			modo = "semi",
			dano = 25, -- T3, cabeça 1 tiro
			cadencia = 0.35,
			alcance = 300,
			queda = { inicio = 80, minimo = 0.55 }, -- dano x1 até `inicio` studs, linear até x`minimo` em `alcance`
			ruidoDb = 110,
			duasMaos = false,
			municao = "municaoPistola",
			pente = 17,
			recarga = { tipo = "pente", tempo = 1.9 },
			espalhamento = 1.5, -- graus (cone)
			bloom = { porTiro = 0.5, maximo = 3, recuperacao = 4 }, -- graus; graus/s
			coice = { vertical = 1.6, horizontal = 0.5 }, -- graus de câmera por tiro (só visual)
			som = "TiroPistola",
			somAcerto = "AcertoCarne",
			somVazio = "CliqueVazio",
			somEquipar = "EquiparArma",
			somRecarga = { { t = 0.15, nome = "RecargaPenteSai" }, { t = 0.65, nome = "RecargaPenteEntra" } },
			tipoDano = "bala",
		},
		beretta = { -- 92FS: mais dano e mais precisa, menos pente
			nome = "Beretta 92FS",
			classe = "pistola",
			tipo = "fogo",
			modo = "semi",
			dano = 28, -- T3, cabeça 1 tiro
			cadencia = 0.4,
			alcance = 330,
			queda = { inicio = 100, minimo = 0.6 },
			ruidoDb = 110,
			duasMaos = false,
			municao = "municaoPistola",
			pente = 15,
			recarga = { tipo = "pente", tempo = 2.1 },
			espalhamento = 1.0,
			bloom = { porTiro = 0.45, maximo = 2.5, recuperacao = 4.5 },
			coice = { vertical = 1.8, horizontal = 0.4 },
			som = "TiroPistola",
			somAcerto = "AcertoCarne",
			somVazio = "CliqueVazio",
			somEquipar = "EquiparArma",
			somRecarga = { { t = 0.15, nome = "RecargaPenteSai" }, { t = 0.65, nome = "RecargaPenteEntra" } },
			tipoDano = "bala",
		},

		----------------------------------------------------------------------------------------------- fuzis
		ar15 = { -- semiautomático civil 5,56: preciso, 2 tiros no torso
			nome = "AR-15",
			classe = "fuzil",
			tipo = "fogo",
			modo = "semi",
			dano = 30, -- T2
			cadencia = 0.16,
			alcance = 550,
			queda = { inicio = 200, minimo = 0.6 },
			ruidoDb = 120,
			duasMaos = true,
			municao = "municao556",
			pente = 30,
			recarga = { tipo = "pente", tempo = 2.6 },
			espalhamento = 0.7,
			bloom = { porTiro = 0.4, maximo = 3, recuperacao = 5 },
			coice = { vertical = 1.3, horizontal = 0.4 },
			som = "TiroFuzil",
			somAcerto = "AcertoCarne",
			somVazio = "CliqueVazio",
			somEquipar = "EquiparArma",
			somRecarga = {
				{ t = 0.12, nome = "RecargaPenteSai" },
				{ t = 0.55, nome = "RecargaPenteEntra" },
				{ t = 0.85, nome = "RecargaFuzil" },
			},
			tipoDano = "bala",
		},
		carabinaM5 = { -- Colt M5 SCW 5,56, automática curta: cadência alta, dano baixo, abre o cone rápido
			nome = "Carabina M5",
			classe = "fuzil",
			tipo = "fogo",
			modo = "auto",
			dano = 22, -- T3
			cadencia = 0.085,
			alcance = 350,
			queda = { inicio = 90, minimo = 0.5 },
			ruidoDb = 118,
			duasMaos = true,
			municao = "municao556",
			pente = 30,
			recarga = { tipo = "pente", tempo = 2.4 },
			espalhamento = 1.2,
			bloom = { porTiro = 0.25, maximo = 4.5, recuperacao = 6 },
			coice = { vertical = 1.0, horizontal = 0.5 },
			som = "TiroFuzil",
			somAcerto = "AcertoCarne",
			somVazio = "CliqueVazio",
			somEquipar = "EquiparArma",
			somRecarga = {
				{ t = 0.12, nome = "RecargaPenteSai" },
				{ t = 0.55, nome = "RecargaPenteEntra" },
				{ t = 0.85, nome = "RecargaFuzil" },
			},
			tipoDano = "bala",
		},
		ak74 = { -- 5,45, automático pesado: mais dano e mais coice que a M5
			nome = "AK-74",
			classe = "fuzil",
			tipo = "fogo",
			modo = "auto",
			dano = 28, -- T3 (2 tiros = 56, falta 4)
			cadencia = 0.092,
			alcance = 500,
			queda = { inicio = 150, minimo = 0.55 },
			ruidoDb = 122,
			duasMaos = true,
			municao = "municao545",
			pente = 30,
			recarga = { tipo = "pente", tempo = 2.9 },
			espalhamento = 1.4,
			bloom = { porTiro = 0.35, maximo = 5, recuperacao = 5 },
			coice = { vertical = 1.6, horizontal = 0.7 },
			som = "TiroFuzil",
			somAcerto = "AcertoCarne",
			somVazio = "CliqueVazio",
			somEquipar = "EquiparArma",
			somRecarga = {
				{ t = 0.12, nome = "RecargaPenteSai" },
				{ t = 0.55, nome = "RecargaPenteEntra" },
				{ t = 0.85, nome = "RecargaFuzil" },
			},
			tipoDano = "bala",
		},

		----------------------------------------------------------------------------------------------- escopetas
		-- projeteis = chumbinhos por tiro; espalhamento = cone de cada chumbinho (bloom 0: o cone já é largo).
		escopeta = { -- pump 12: pesada, cone fechado, bom até ~40 studs
			nome = "Escopeta",
			classe = "escopeta",
			tipo = "fogo",
			modo = "semi",
			dano = 12, -- por chumbinho; 8 chumbinhos = 96 colado
			projeteis = 8,
			cadencia = 0.95, -- inclui bombear
			alcance = 120,
			queda = { inicio = 15, minimo = 0.15 },
			ruidoDb = 125,
			duasMaos = true,
			municao = "municaoCalibre12",
			pente = 5,
			recarga = { tipo = "cartucho", inicio = 0.5, porCartucho = 0.55, fim = 0.4 },
			espalhamento = 4.5,
			bloom = { porTiro = 0, maximo = 0, recuperacao = 1 },
			coice = { vertical = 3.2, horizontal = 0.8 },
			som = "TiroEscopeta",
			somAcerto = "AcertoCarne",
			somVazio = "CliqueVazio",
			somEquipar = "EquiparArma",
			somBombear = "Bombear",
			somCartucho = "InserirCartucho",
			tipoDano = "bala",
		},
		escopetaM1912 = { -- trench gun: mais chumbinhos, cone aberto, bombeia mais rápido, mais tubo
			nome = "Escopeta Trincheira M1912",
			classe = "escopeta",
			tipo = "fogo",
			modo = "semi",
			dano = 10, -- 9 chumbinhos = 90 colado
			projeteis = 9,
			cadencia = 0.7,
			alcance = 110,
			queda = { inicio = 12, minimo = 0.15 },
			ruidoDb = 125,
			duasMaos = true,
			municao = "municaoCalibre12",
			pente = 6,
			recarga = { tipo = "cartucho", inicio = 0.55, porCartucho = 0.6, fim = 0.4 },
			espalhamento = 6,
			bloom = { porTiro = 0, maximo = 0, recuperacao = 1 },
			coice = { vertical = 2.8, horizontal = 0.8 },
			som = "TiroEscopeta",
			somAcerto = "AcertoCarne",
			somVazio = "CliqueVazio",
			somEquipar = "EquiparArma",
			somBombear = "Bombear",
			somCartucho = "InserirCartucho",
			tipoDano = "bala",
		},

		----------------------------------------------------------------------------------------------- lançador
		lancaFoguetes = { -- 1 tiro, recarga longa; explosão em área que também quebra construção (Destruicao.explosao)
			nome = "Lança-foguetes",
			classe = "lancador",
			tipo = "fogo",
			modo = "semi",
			dano = 0, -- sem dano direto: tudo vem da explosão
			cadencia = 1,
			alcance = 600, -- studs que o foguete voa antes de se autodestruir (velocidade x vida)
			ruidoDb = 120, -- lançamento
			duasMaos = true,
			municao = "municaoFoguete",
			pente = 1,
			recarga = { tipo = "pente", tempo = 3.8 },
			espalhamento = 0.5,
			bloom = { porTiro = 0, maximo = 0, recuperacao = 1 },
			coice = { vertical = 4, horizontal = 0.5 },
			projetil = {
				velocidade = 150, -- studs/s
				vida = 4, -- s
				raioExplosao = 20, -- studs
				danoCentro = 140, -- no centro; cai linear até `fatorBorda` na borda do raio
				fatorBorda = 0.25,
				fatorParede = 0.35, -- multiplicador se há parede entre a explosão e o alvo
				raioConstrucao = 18, -- Destruicao.explosao(centro, raio, dano, fonte)
				danoConstrucao = 450,
				ruidoExplosaoDb = 135,
				dano = { carro = 220, monstro = 140 }, -- dano no centro contra carro (Veiculos.acerto) e monstro (Monstros.dano)
			},
			som = "TiroFoguete",
			somExplosao = "ExplosaoFoguete",
			somAcerto = "AcertoMetal",
			somVazio = "CliqueVazio",
			somEquipar = "EquiparArma",
			somRecarga = { { t = 0.2, nome = "RecargaFoguete" } },
			tipoDano = "explosao",
		},
	},
}
