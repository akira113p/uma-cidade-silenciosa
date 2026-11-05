#!/usr/bin/env bash
# As 4 checagens antes de o Studio ver qualquer coisa. Rodar da raiz do projeto: bash scripts/checar.sh
falhas=()
passo() {
	local nome="$1"
	shift
	echo "== $nome"
	"$@" || falhas+=("$nome")
}

testes() {
	for t in tests/*.spec.luau; do
		[ -e "$t" ] || continue
		lune run "$t" || return 1
	done
}

mkdir -p build
passo "rojo build" rojo build default.project.json -o build/place.rbxl
passo "testes" testes
passo "selene" selene src
passo "stylua" stylua --check src tests

if [ ${#falhas[@]} -gt 0 ]; then
	echo "Falharam: ${falhas[*]}"
	exit 1
fi
echo "Tudo verde."
