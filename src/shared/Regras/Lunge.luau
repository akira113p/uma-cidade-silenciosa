--!strict
-- Regras puras do golpe por investida (lunge) do Wrapper (docs/wrapper.md §2, §4 Fase 1). Sem Instance, sem os.clock:
-- o tempo entra por parâmetro. `cfg` = preset (Config/PresetsMonstro.corpoAriete): usa cfg.golpe e cfg.sorteioParte (o grito saiu: o Wrapper usa o sonar, Habilidades/Wrapper).
-- Máquina: Aproximar -> Lunge -> Recuperar -> Aproximar. O impacto cai `atrasoImpacto` s depois do início; a recuperação
-- (parado, sem novo golpe) começa no impacto, acertando ou errando.

export type Cfg = any
export type Maquina = { fase: string, ate: number, impactoFeito: boolean }

local Lunge = {}

function Lunge.novo(): Maquina
	return { fase = "Aproximar", ate = 0, impactoFeito = false }
end

-- Perto o bastante para parar de andar e investir.
function Lunge.deveIniciarLunge(dist: number, cfg: Cfg): boolean
	return dist <= cfg.golpe.alcanceInicio
end

-- No quadro de impacto: o dano só cai se o alvo ainda estiver a <= alcanceImpacto (quem recuou no clipe escapa).
function Lunge.impactoAcerta(distAlvo: number, cfg: Cfg): boolean
	return distAlvo <= cfg.golpe.alcanceImpacto
end

-- Tabela { {parte, peso}, ... }; `rnd` devolve [0, 1). Mesma regra de Corpo.sortearParte, com a tabela do preset (sem braços).
function Lunge.sortearParte(tabela: { { parte: string, peso: number } }, rnd: () -> number): string
	assert(#tabela > 0, "Lunge.sortearParte: tabela vazia")
	local total = 0
	for _, e in tabela do
		total += e.peso
	end
	local alvo = rnd() * total
	local acumulado = 0
	for _, e in tabela do
		acumulado += e.peso
		if alvo < acumulado then
			return e.parte
		end
	end
	return tabela[#tabela].parte
end

-- Só se pode iniciar um golpe novo na fase Aproximar (a recuperação bloqueia).
function Lunge.podeGolpear(m: Maquina): boolean
	return m.fase == "Aproximar"
end

-- Um passo da máquina (muda `m`). Devolve o evento: "iniciar" (tocar Attack_Lunge, parar de andar), "impacto" (aplicar dano
-- se `acertou`), "fim" (voltou a aproximar) ou nil. `dist` = distância horizontal até o alvo agora.
function Lunge.passo(m: Maquina, agora: number, dist: number, cfg: Cfg): (string?, boolean?)
	if m.fase == "Aproximar" then
		if Lunge.deveIniciarLunge(dist, cfg) then
			m.fase = "Lunge"
			m.ate = agora + cfg.golpe.atrasoImpacto
			m.impactoFeito = false
			return "iniciar", nil
		end
	elseif m.fase == "Lunge" then
		if agora >= m.ate and not m.impactoFeito then
			m.impactoFeito = true
			m.fase = "Recuperar"
			m.ate = agora + cfg.golpe.recuperacao
			return "impacto", Lunge.impactoAcerta(dist, cfg)
		end
	elseif m.fase == "Recuperar" then
		if agora >= m.ate then
			m.fase = "Aproximar"
			return "fim", nil
		end
	end
	return nil, nil
end

return Lunge
