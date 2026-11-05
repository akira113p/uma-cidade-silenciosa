-- Coerência dos clipes de arma (assets/animacoes/armas/*.json) com Config/Armas (docs/armas.md §9). Roda da raiz do projeto.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local ConfigArmas = require("../src/shared/Config/Armas")

local PASTA = "assets/animacoes/armas"
local JUNTAS = {
	Root = true,
	Waist = true,
	Neck = true,
	LeftShoulder = true,
	LeftElbow = true,
	LeftWrist = true,
	RightShoulder = true,
	RightElbow = true,
	RightWrist = true,
	LeftHip = true,
	LeftKnee = true,
	LeftAnkle = true,
	RightHip = true,
	RightKnee = true,
	RightAnkle = true,
}
local PRIORIDADES = { Idle = "Action", Equip = "Action2", Fire = "Action2" }

local classes = {}
for _, arq in fs.readDir(PASTA) do
	if arq ~= "mao.json" and string.match(arq, "%.json$") then
		local d = serde.decode("json", fs.readFile(PASTA .. "/" .. arq))
		classes[d.classe] = d
	end
end
local mao = serde.decode("json", fs.readFile(PASTA .. "/mao.json"))

-- cada classe de Config/Armas tem JSON e mão
local usadas: { [string]: any } = {}
for id, a in ConfigArmas.armas do
	assert(classes[a.classe], id .. ": sem assets/animacoes/armas/" .. a.classe .. ".json")
	assert(mao.porClasse[a.classe], a.classe .. ": sem pose de mão em mao.json")
	usadas[a.classe] = a
end

local function clipeExiste(c: any, nome: string)
	assert(c.clipes[nome], c.classe .. ": falta o clipe " .. nome)
end

for classe, d in classes do
	assert(usadas[classe], classe .. ": classe sem arma em Config/Armas")
	for nome, clipe in d.clipes do
		local rotulo = classe .. "_" .. nome
		local q = clipe.quadros
		assert(#q >= 2, rotulo .. ": 2+ quadros")
		assert(q[1].t == 0, rotulo .. ": primeiro quadro em t=0")
		assert(math.abs(q[#q].t - clipe.duracao) < 1e-4, rotulo .. ": último quadro = duracao")
		for i = 2, #q do
			assert(q[i].t > q[i - 1].t, rotulo .. ": tempos crescentes")
		end
		local prio = PRIORIDADES[nome]
			or (if string.find(nome, "Recarga") or nome == "Reload" then "Action3" else "Action2")
		assert(clipe.prioridade == prio, rotulo .. ": prioridade deve ser " .. prio)
		for _, quadro in q do
			if quadro.de then
				assert(d.poses[quadro.de], rotulo .. ": pose inexistente " .. quadro.de)
			end
			local juntas = {}
			for j, v in d.poses[quadro.de or ""] or {} do
				juntas[j] = v
			end
			for j, v in quadro.juntas or {} do
				juntas[j] = v
			end
			for j, v in juntas do
				assert(JUNTAS[j], rotulo .. ": junta desconhecida " .. j)
				assert(#v == 3 or #v == 6, rotulo .. ": junta " .. j .. " precisa de 3 ou 6 números")
			end
			assert(next(juntas), rotulo .. ": quadro sem juntas")
		end
		if clipe.loop then
			assert(nome == "Idle", rotulo .. ": só o Idle repete")
		end
	end
	clipeExiste(d, "Idle")
	clipeExiste(d, "Equip")
end

-- laço do Idle: primeiro e último quadro iguais (sem pulo)
for classe, d in classes do
	local q = d.clipes.Idle.quadros
	assert(d.clipes.Idle.loop, classe .. ": Idle em laço")
	assert(q[1].de == q[#q].de, classe .. ": Idle começa e termina na mesma pose")
end

-- clipes exigidos por tipo de arma
for id, a in ConfigArmas.armas do
	local d = classes[a.classe]
	if a.tipo == "fogo" then
		clipeExiste(d, "Fire")
		if a.recarga.tipo == "pente" then
			clipeExiste(d, "Reload")
			-- velocidade da recarga (duração do clipe / tempo de Config): faixa em que ainda parece natural
			local v = d.clipes.Reload.duracao / a.recarga.tempo
			assert(v > 0.6 and v < 1.6, id .. ": recarga do clipe muito diferente de Config/Armas (x" .. v .. ")")
		else
			clipeExiste(d, "RecargaInicio")
			clipeExiste(d, "RecargaCartucho")
			clipeExiste(d, "RecargaFim")
			local r = a.recarga
			for nome, t in { RecargaInicio = r.inicio, RecargaCartucho = r.porCartucho, RecargaFim = r.fim } do
				local v = d.clipes[nome].duracao / t
				assert(v > 0.6 and v < 1.6, id .. ": " .. nome .. " x" .. v)
			end
		end
		-- clipe de tiro tem de caber na cadência (senão o próximo tiro corta o anterior; o cliente acelera, mas só até certo ponto)
		assert(
			d.clipes.Fire.duracao / math.min(a.cadencia, d.clipes.Fire.duracao) < 2,
			id .. ": Fire longo demais para a cadência"
		)
	else
		-- golpe: marcador Impacto no tempo de atrasoImpacto e clipe cabe na cadência
		local golpes = if a.classe == "faca" then { "Golpe1", "Golpe2" } else { "Golpe" }
		for _, nome in golpes do
			clipeExiste(d, nome)
			local achou = false
			for _, quadro in d.clipes[nome].quadros do
				for _, m in quadro.marcadores or {} do
					if m == "Impacto" then
						achou = true
						assert(math.abs(quadro.t - a.atrasoImpacto) < 0.005, id .. ": Impacto fora de atrasoImpacto")
					end
				end
			end
			assert(achou, id .. ": " .. nome .. " sem marcador Impacto")
			assert(d.clipes[nome].duracao <= a.cadencia + 1e-4, id .. ": " .. nome .. " mais longo que a cadência")
		end
	end
end

print("ArmasAnimDados.spec ok")
