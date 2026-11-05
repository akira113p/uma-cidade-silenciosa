local util = require("./util")
local R = require("../src/shared/Regras/FiltroAberracao")
local cfg = require("../src/shared/Config/Filtro/Aberracao")

-- fovs: intensidade 0 → iguais
local v0, c0 = R.fovs(70, 0, cfg)
util.perto(v0, 70, "vermelho com intensidade 0")
util.perto(c0, 70, "ciano com intensidade 0")

-- ordem e simetria
for _, i in { 0.2, 0.5, 1 } do
	local v, c = R.fovs(70, i, cfg)
	assert(v < 70 and 70 < c, "ordem vermelho < base < ciano com intensidade " .. i)
	util.perto(70 - v, c - 70, "simetria " .. i, 1e-9)
end
local _, c1 = R.fovs(70, 1, cfg)
util.perto(c1 - 70, cfg.fovDelta, "delta com intensidade 1")
local _, cm = R.fovs(70, 0.5, cfg)
assert(cm - 70 < c1 - 70 and cm - 70 > 0, "delta cresce com a intensidade")
local vl, cl = R.fovs(119.5, 1, cfg)
assert(cl <= 120 and vl >= 1, "fov dentro de 1..120")
local _, cx = R.fovs(70, 5, cfg)
util.perto(cx, c1, "intensidade > 1 limitada")
local vn = R.fovs(70, -1, cfg)
util.perto(vn, 70, "intensidade < 0 limitada")

-- transparencia: 0 → invisível; 1 → cheia; decresce
local tv0, tc0 = R.transparencias(0, cfg)
util.perto(tv0, 1, "vermelho com intensidade 0")
util.perto(tc0, 1, "ciano com intensidade 0")
for _, i in { 0.3, 0.6, 1 } do
	local tV, tC = R.transparencias(i, cfg)
	local w = cfg.pesoCor * i
	util.perto(1 - tC, w, "peso do ciano (em cima) " .. i, 1e-9)
	util.perto(tC * (1 - tV), w, "peso do vermelho (embaixo) " .. i, 1e-9)
	util.perto(tC * tV, 1 - 2 * w, "cena " .. i, 1e-9)
end
local tvA, tcA = R.transparencias(0.3, cfg)
local tvB, tcB = R.transparencias(0.8, cfg)
assert(tvA > tvB and tcA > tcB, "mais intensidade, menos transparência")

-- intensidade do quadro
util.perto(R.intensidade(cfg, 0, 0, 0), cfg.base, "intensidade parada")
util.perto(R.intensidade(cfg, 1, 1, 1), 1, "intensidade limitada a 1")
util.perto(R.intensidade(cfg, 0.2, 0, 0.5), cfg.base + 0.2 * cfg.extraDano + 0.5 * cfg.extraCaca, "soma dos pulsos")

-- células: sem duplicata, todas tocam o círculo, nenhuma que toque ficou de fora
local function conferir(px: number, pz: number, tam: number, raio: number)
	local lista = R.celulas({ X = px, Y = 10, Z = pz }, tam, raio)
	local vistas = {}
	for _, k in lista do
		assert(not vistas[k], "duplicata " .. k)
		vistas[k] = true
	end
	for ix = -10, 10 do
		for iz = -10, 10 do
			local dx = math.max(ix * tam - px, 0, px - (ix + 1) * tam)
			local dz = math.max(iz * tam - pz, 0, pz - (iz + 1) * tam)
			local toca = dx * dx + dz * dz <= raio * raio
			util.igual(vistas[ix .. "," .. iz] == true, toca, string.format("célula %d,%d (%g,%g)", ix, iz, px, pz))
		end
	end
end
conferir(0, 0, 32, 36)
conferir(16, 16, 32, 36)
conferir(-50.5, 70.25, 32, 36)
conferir(31.9, -0.1, 32, 20)

local so = R.celulas({ X = 16, Y = 0, Z = 16 }, 32, 10)
util.igual(#so, 1, "uma célula só")
util.igual(so[1], "0,0", "chave da célula")
local lista = R.celulas({ X = 5, Y = 0, Z = 5 }, 32, 36)
util.igual(lista[1], "0,0", "primeira é a de baixo da câmera")
util.igual(R.indice(-0.1, 32), -1, "índice negativo")

-- névoa
util.perto(R.fatorNevoa(0, 0, 100), 0, "névoa no início")
util.perto(R.fatorNevoa(50, 0, 100), 0.5, "névoa no meio")
util.perto(R.fatorNevoa(100, 0, 100), 1, "névoa no fim")
util.perto(R.fatorNevoa(500, 0, 100), 1, "névoa depois do fim")
util.perto(R.fatorNevoa(10, 20, 100), 0, "antes de FogStart")
util.perto(R.fatorNevoa(30, 20, 20), 1, "FogEnd <= FogStart, depois")
util.perto(R.fatorNevoa(10, 20, 20), 0, "FogEnd <= FogStart, antes")
util.perto(R.fatorNevoa(20, 20, 10), 1, "FogEnd < FogStart, em FogStart")

-- alcance dinâmico
util.perto(R.alcanceDinamico(60, 0, 140, cfg.fracaoNevoaDinamico), 60, "dia: limitado pelo raio")
util.perto(R.alcanceDinamico(60, 0, 75, 0.6), 45, "noite: limitado pela névoa")

-- planos
assert(R.ehPlano(51, 1, 51, 1.5, 16), "chão é plano")
assert(not R.ehPlano(51, 10, 51, 1.5, 16), "parede alta não é plana")
assert(not R.ehPlano(10, 1, 10, 1.5, 16), "placa pequena não é plana")
assert(not R.ehPlano(2, 2, 40, 1.5, 16), "viga comprida não é plana")
util.igual(cfg.raioEstatico, 50, "raio estático")

-- cor pela névoa
local r, g, b = R.corNevoa(0.2, 0.4, 0.6, 0.8, 0.8, 0.8, 0)
util.perto(r, 0.2, "sem névoa r")
util.perto(b, 0.6, "sem névoa b")
r, g, b = R.corNevoa(0.2, 0.4, 0.6, 0.8, 0.7, 0.1, 1)
util.perto(r, 0.8, "névoa total r")
util.perto(g, 0.7, "névoa total g")
util.perto(b, 0.1, "névoa total b")
r, g = R.corNevoa(0, 0.5, 0, 1, 1, 1, 0.5)
util.perto(r, 0.5, "meio r")
util.perto(g, 0.75, "meio g")
r = R.corNevoa(0, 0, 0, 1, 1, 1, 7)
util.perto(r, 1, "fator limitado")

-- franja por distância
util.perto(R.fatorFranja(0, 18, 48), 1, "franja colada")
util.perto(R.fatorFranja(18, 18, 48), 1, "franja no perto")
util.perto(R.fatorFranja(33, 18, 48), 0.5, "franja no meio")
util.perto(R.fatorFranja(48, 18, 48), 0, "franja no longe")
util.perto(R.fatorFranja(200, 18, 48), 0, "franja além")
assert(R.fatorFranja(25, 18, 48) > R.fatorFranja(40, 18, 48), "franja decresce")
util.perto(R.fatorFranja(10, 20, 20), 1, "franja degenerada perto")
util.perto(R.fatorFranja(30, 20, 20), 0, "franja degenerada longe")
util.igual(cfg.franjaPerto, 18, "franjaPerto")
util.igual(cfg.franjaLonge, 48, "franjaLonge")
util.igual(cfg.fovDelta, 4.5, "fovDelta")

-- distância à caixa
util.perto(R.distanciaCaixa(0, 0, 0, 0, 0, 0, 10, 10, 10), 0, "dentro")
util.perto(R.distanciaCaixa(0, 0, 0, 30, 0, 0, 10, 10, 10), 25, "de frente, face a 25")
util.perto(R.distanciaCaixa(0, 0, 0, 30, 30, 0, 10, 10, 10), math.sqrt(25 * 25 + 25 * 25), "diagonal")
util.perto(R.distanciaCaixa(5, 0, 0, 0, 0, 0, 10, 10, 10), 0, "na face")
util.perto(
	R.distanciaCaixa(0, 0, 0, 100, 0, 0, 120, 10, 10),
	40,
	"parede enorme: 40 até a ponta, não 100 até o centro"
)
util.perto(R.distanciaCaixa(50, 0, 0, 100, 0, 0, 120, 10, 10), 0, "encostada na parede enorme")

print("FiltroAberracao ok")
